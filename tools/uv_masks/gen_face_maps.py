"""Genera los mapas UV de cara y ojos del motor (P5) y sus vistas previas.

Las UV de la malla canónica son simétricas (error <= 0,001) y ningún
triángulo cruza la línea media: se guarda solo la mitad derecha de la imagen
(u <= 0,5; el ojo derecho del sujeto) y el vertex shader espeja por vértice
(u' = min(u, 1 - u)), lo que es exacto.

Salidas (versionadas: el build de Android no necesita Python):
  packages/makeup_engine/android/src/main/cpp/mesh/face_maps.h
      kFaceMapRgb: RGB8 sobre kFaceMapUvRect (media cara).
        R = piel (base): 1 dentro del óvalo, difuminado hacia el borde de la
            cara; 0 en la abertura de los ojos, las cejas y los labios.
        G = contorno (bajo el pómulo, mandíbula, sienes, costados de la nariz).
        B = iluminador (pómulo, puente de la nariz, arco de cupido, mentón,
            frente).
        G y B ya están multiplicados por R.
      kCheekPlacements: rubor analítico (gaussiana elíptica en UV) por
        placement: apple, high, low -> (u, v, sigmaU, sigmaV, ángulo rad).
      kFaceRegionTriangles: toda la malla sin los triángulos que cruzan la boca
        ni las aberturas de los ojos.
  packages/makeup_engine/android/src/main/cpp/mesh/eye_maps.h
      kEyeMapA (RGBA8): párpado, pliegue, V externa, lagrimal.
      kEyeMapB (RGBA8): hueso de la ceja; distancia a la línea de pestañas
        superior; distancia a la línea del wing; avance a lo largo del wing.
        Las distancias van normalizadas por kLinerMaxDistanceUv y por el
        afinamiento (más finas hacia el lagrimal y hacia la punta del wing):
        el shader compara contra el grosor de la receta sin regenerar nada.
      kEyeRegionTriangles: triángulos que tocan el rectángulo de cualquiera de
        los dos ojos, sin los que cruzan la abertura.
  docs/ar_engine/img/face_maps.png, docs/ar_engine/img/eye_maps.png: vistas previas.

Coordenadas del ojo (para párpado, pliegue, etc.): s va de 0 en el ángulo
externo a 1 en el lagrimal; t va de 0 en la línea de pestañas superior a 1 en
el borde inferior de la ceja (negativo debajo del párpado inferior). Todas las
distancias de face.json están en unidades UV canónicas.

Fuente de la geometría: third_party/mediapipe_face_geometry (Apache 2.0).

Uso:
  python tools/uv_masks/gen_face_maps.py            regenera
  python tools/uv_masks/gen_face_maps.py --check    falla si lo versionado no coincide
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools/mesh"))
sys.path.insert(0, str(Path(__file__).resolve().parent))
import gen_canonical_mesh as mesh  # noqa: E402
from gen_lips_maps import catmull_rom_closed, inside_polygon, png_bytes, segment_distance, smoothstep  # noqa: E402

PARAMS = Path(__file__).resolve().parent / "face.json"
CPP_MESH = ROOT / "packages/makeup_engine/android/src/main/cpp/mesh"
FACE_HEADER = CPP_MESH / "face_maps.h"
EYE_HEADER = CPP_MESH / "eye_maps.h"
FACE_PREVIEW = ROOT / "docs/ar_engine/img/face_maps.png"
EYE_PREVIEW = ROOT / "docs/ar_engine/img/eye_maps.png"
PREVIEW_SCALE = 2
PLACEMENTS = ("apple", "high", "low")


def connection_edges(name: str):
    text = (mesh.SOURCE / "face_mesh_connections.py").read_text(encoding="utf-8")
    match = re.search(name + r"\s*=\s*frozenset\(\[(.*?)\]\)", text, re.S)
    if match is None:
        sys.exit(f"no se encontró {name}")
    return [(int(a), int(b)) for a, b in re.findall(r"\((\d+),\s*(\d+)\)", match.group(1))]


def polyline_distance(points: np.ndarray, line: np.ndarray) -> np.ndarray:
    """Distancia de cada punto (N, 2) a la polilínea abierta (M, 2); M >= 1."""
    if len(line) == 1:
        return np.linalg.norm(points - line[0], axis=1)
    a, b = line[:-1], line[1:]
    ab = b - a
    ap = points[:, None, :] - a[None, :, :]
    t = np.clip((ap * ab).sum(-1) / (ab * ab).sum(-1), 0.0, 1.0)
    closest = a[None, :, :] + t[..., None] * ab[None, :, :]
    return np.linalg.norm(points[:, None, :] - closest, axis=-1).min(axis=1)


def catmull_rom_open(line: np.ndarray, steps: int) -> np.ndarray:
    """Polilínea abierta suavizada que pasa por los puntos (extremos reflejados)."""
    padded = np.vstack([2 * line[0] - line[1], line, 2 * line[-1] - line[-2]])
    closed = catmull_rom_closed(padded, steps)
    # catmull_rom_closed recorre todos los tramos del ciclo (steps puntos cada
    # uno): se quedan los que van de line[0] a line[-1], tramos 1 .. n-1 del
    # arreglo con relleno.
    return np.vstack([closed[steps: steps * len(line)], line[-1:]])


def signed_outside(points: np.ndarray, polygon: np.ndarray) -> np.ndarray:
    """Distancia con signo al borde: positiva fuera del polígono."""
    distance = segment_distance(points, polygon)
    return np.where(inside_polygon(points, polygon), -distance, distance)


def window(x: np.ndarray, start: float, end: float, feather: float) -> np.ndarray:
    half = 0.5 * feather
    return smoothstep(start - half, start + half, x) * (1.0 - smoothstep(end - half, end + half, x))


def strokes(points: np.ndarray, items) -> np.ndarray:
    out = np.zeros(len(points))
    for item in items:
        d = polyline_distance(points, np.array(item["points"], dtype=float))
        out = np.maximum(out, item["amount"] * np.exp(-0.5 * (d / item["sigma"]) ** 2))
    return out


def grid(u0: float, v0: float, u1: float, v1: float, width: int, height: int) -> np.ndarray:
    # Centros de texel; fila 0 = v mínima (t = 0 de la textura en GL).
    us = u0 + (np.arange(width) + 0.5) / width * (u1 - u0)
    vs = v0 + (np.arange(height) + 0.5) / height * (v1 - v0)
    grid_u, grid_v = np.meshgrid(us, vs)
    return np.stack([grid_u.ravel(), grid_v.ravel()], axis=1)


def quantize(values: np.ndarray) -> np.ndarray:
    return np.clip(np.rint(values * 255.0), 0, 255).astype(np.uint8)


class Geometry:
    def __init__(self, params: dict):
        _, uvs, self.triangles = mesh.parse_obj(mesh.SOURCE / "canonical_face_model.obj")
        self.uv = np.array(uvs)
        lm = params["landmarks"]
        self.eye_upper = self.uv[lm["eyeUpper"]]
        self.eye_lower = self.uv[lm["eyeLower"]]
        self.brow_lower = self.uv[lm["browLower"]]
        self.brow_upper = self.uv[lm["browUpper"]]
        # Abertura del ojo derecho: párpado superior + inferior al revés.
        self.eye_opening = np.vstack([self.eye_upper, self.eye_lower[-2:0:-1]])
        self.left_eye_opening = self.uv[mesh.ordered_loop(connection_edges("FACEMESH_LEFT_EYE"), 263)]
        self.oval = self.uv[mesh.ordered_loop(connection_edges("FACEMESH_FACE_OVAL"), 10)]
        lip_edges = mesh.parse_lip_edges(mesh.SOURCE / "face_mesh_connections.py")
        self.lips_outer = self.uv[mesh.ordered_loop(lip_edges, 61)]
        self.lips_inner = self.uv[mesh.ordered_loop(lip_edges, 78)]
        self.brow = np.vstack([self.brow_lower, self.brow_upper[::-1]])

    def opening_crossers(self):
        """Triángulos que cruzan la boca o una abertura de ojo (centro UV dentro)."""
        polygons = {"boca": self.lips_inner, "ojo derecho": self.eye_opening, "ojo izquierdo": self.left_eye_opening}
        counts = {name: 0 for name in polygons}
        crossing = set()
        for index, tri in enumerate(self.triangles):
            centroid = self.uv[list(tri)].mean(axis=0)
            for name, polygon in polygons.items():
                if mesh.point_in_polygon(centroid[0], centroid[1], [tuple(p) for p in polygon]):
                    counts[name] += 1
                    crossing.add(index)
        return crossing, counts


def build_face(params: dict, geo: Geometry):
    fm = params["faceMap"]
    width, height = fm["width"], fm["height"]
    rect = (0.0, fm["vMin"], 0.5, fm["vMax"] - fm["vMin"])
    points = grid(0.0, fm["vMin"], 0.5, fm["vMax"], width, height)
    steps = fm["contourSubdivision"]
    sk = fm["skin"]

    oval = catmull_rom_closed(geo.oval, steps)
    skin = smoothstep(0.0, sk["ovalFeather"], -signed_outside(points, oval))
    eye = catmull_rom_closed(geo.eye_opening, steps)
    skin *= smoothstep(sk["eyeExpand"], sk["eyeExpand"] + sk["eyeFeather"], signed_outside(points, eye))
    brow = catmull_rom_closed(geo.brow, steps)
    skin *= smoothstep(sk["browExpand"], sk["browExpand"] + sk["browFeather"], signed_outside(points, brow))
    lips = catmull_rom_closed(geo.lips_outer, steps)
    skin *= smoothstep(sk["lipsExpand"], sk["lipsExpand"] + sk["lipsFeather"], signed_outside(points, lips))

    contour = strokes(points, fm["contour"]) * skin
    highlight = strokes(points, fm["highlight"]) * skin
    rgb = quantize(np.stack([skin, contour, highlight], axis=1)).reshape(height, width, 3)

    cheeks = []
    for name in PLACEMENTS:
        c = params["cheeks"][name]
        cheeks.append((c["u"], c["v"], c["sigmaU"], c["sigmaV"], float(np.radians(c["angleDeg"]))))
    return rgb, rect, cheeks


def eye_coordinates(points: np.ndarray, geo: Geometry):
    """(s, t) de cada punto: ver el docstring del módulo."""
    u, v = points[:, 0], points[:, 1]
    outer, inner = geo.eye_upper[0], geo.eye_upper[-1]
    s = (u - outer[0]) / (inner[0] - outer[0])
    lash = np.interp(u, geo.eye_upper[:, 0], geo.eye_upper[:, 1])
    lower = np.interp(u, geo.eye_lower[:, 0], geo.eye_lower[:, 1])
    brow = np.interp(u, geo.brow_lower[:, 0], geo.brow_lower[:, 1])
    gap = np.maximum(brow - lash, 1e-3)
    t = np.where(v >= lash, (v - lash) / gap, np.where(v <= lower, -(lower - v) / gap, 0.0))
    return s, t


def build_eyes(params: dict, geo: Geometry):
    em = params["eyeMap"]
    width, height = em["width"], em["height"]
    rect = (em["uMin"], em["vMin"], em["uMax"] - em["uMin"], em["vMax"] - em["vMin"])
    points = grid(em["uMin"], em["vMin"], em["uMax"], em["vMax"], width, height)
    steps = em["contourSubdivision"]
    s, t = eye_coordinates(points, geo)
    opening = catmull_rom_closed(geo.eye_opening, steps)
    outside = smoothstep(0.0, em["openingFeather"], signed_outside(points, opening))

    p = em["lid"]
    lid = window(s, p["sStart"], p["sEnd"], p["sFeather"]) * (t > 0.0)
    lid = lid * (1.0 - smoothstep(p["tEnd"] - 0.5 * p["tFeather"], p["tEnd"] + 0.5 * p["tFeather"], t))
    p = em["crease"]
    crease = window(s, p["sStart"], p["sEnd"], p["sFeather"]) * np.exp(-0.5 * ((t - p["t"]) / p["sigmaT"]) ** 2)
    crease *= 1.0 + (p["innerAmount"] - 1.0) * np.clip(s, 0.0, 1.0)
    p = em["outerV"]
    outer_v = np.exp(-0.5 * (((s - p["s"]) / p["sigmaS"]) ** 2 + ((t - p["t"]) / p["sigmaT"]) ** 2))
    outer_v *= 1.0 - smoothstep(p["sMax"] - 0.1, p["sMax"] + 0.1, s)
    p = em["innerCorner"]
    corner = geo.eye_upper[-1] + np.array([p["du"], p["dv"]])
    inner_corner = np.exp(-0.5 * (np.linalg.norm(points - corner, axis=1) / p["sigma"]) ** 2)
    p = em["browBone"]
    brow_bone = window(s, p["sStart"], p["sEnd"], p["sFeather"]) * window(t, p["tStart"], p["tEnd"], p["tFeather"])

    p = em["liner"]
    max_distance = p["maxDistance"]
    lash = catmull_rom_open(geo.eye_upper, steps)
    taper = 1.0 + (p["innerTaper"] - 1.0) * smoothstep(p["taperStart"], 1.0, s)
    liner = np.clip(polyline_distance(points, lash) / (max_distance * taper), 0.0, 1.0)

    p = em["wing"]
    angle = np.radians(p["angleDeg"])
    direction = np.array([-np.cos(angle), np.sin(angle)])  # hacia afuera y arriba (ojo derecho)
    rel = points - geo.eye_upper[0]
    along = rel @ direction / p["length"]
    perpendicular = np.abs(rel[:, 0] * direction[1] - rel[:, 1] * direction[0])
    wing_taper = 1.0 - p["tipTaper"] * np.clip(along, 0.0, 1.0)
    wing_distance = np.where((along >= 0.0) & (along <= 1.0),
                             np.clip(perpendicular / (max_distance * wing_taper), 0.0, 1.0), 1.0)

    masks_a = np.stack([lid, crease, outer_v, inner_corner], axis=1) * outside[:, None]
    masks_b = np.stack([brow_bone * outside, liner, wing_distance, np.clip(along, 0.0, 1.0)], axis=1)
    a8 = quantize(masks_a).reshape(height, width, 4)
    b8 = quantize(masks_b).reshape(height, width, 4)
    return a8, b8, rect, max_distance, p["length"]


def region_triangles(geo: Geometry, crossing: set, eye_rect):
    face, eyes = [], []
    u0, v0, w, h = eye_rect
    uv = geo.uv
    mirrored = np.minimum(uv[:, 0], 1.0 - uv[:, 0])
    in_eye = (mirrored >= u0) & (mirrored <= u0 + w) & (uv[:, 1] >= v0) & (uv[:, 1] <= v0 + h)
    for index, tri in enumerate(geo.triangles):
        if index in crossing:
            continue
        face.append(tri)
        if any(in_eye[i] for i in tri):
            eyes.append(tri)
    return face, eyes


def fmt(value: float) -> str:
    return f"{value:.6f}f"


def face_header(params, rgb, rect, cheeks, face, counts) -> str:
    height, width, _ = rgb.shape
    return "\n".join([
        "// Generado por tools/uv_masks/gen_face_maps.py desde tools/uv_masks/face.json.",
        "// No editar a mano: cambiar los parámetros y regenerar.",
        "//",
        "// Mapa UV de cara (media cara: u <= 0,5; el shader espeja u' = min(u, 1 - u)",
        "// por vértice). RGB8 sobre kFaceMapUvRect (u0, v0, ancho, alto; v hacia",
        "// arriba; fila 0 = v0). R = piel (base), G = contorno, B = iluminador (G y B",
        "// ya multiplicados por R).",
        "#pragma once",
        "",
        "#include <cstdint>",
        "",
        "namespace makeup::mesh {",
        "",
        f"inline constexpr int kFaceMapsVersion = {params['version']};",
        f"inline constexpr int kFaceMapWidth = {width};",
        f"inline constexpr int kFaceMapHeight = {height};",
        f"inline constexpr float kFaceMapUvRect[4] = {{{', '.join(fmt(v) for v in rect)}}};",
        "",
        "// Rubor por placement (apple, high, low): centro UV (u, v) del lado u <= 0,5,",
        "// sigmas en UV a lo largo de los ejes de la elipse y ángulo del eje mayor",
        "// (rad, antihorario en UV).",
        f"inline constexpr int kCheekPlacementCount = {len(cheeks)};",
        f"inline constexpr float kCheekPlacements[{len(cheeks)}][5] = {{",
        *[f"    {{{', '.join(fmt(v) for v in c)}}},  // {name}" for name, c in zip(PLACEMENTS, cheeks)],
        "};",
        "",
        f"// Toda la malla menos los que cruzan la boca ({counts['boca']}) y las aberturas de",
        f"// los ojos ({counts['ojo derecho']} + {counts['ojo izquierdo']}).",
        f"inline constexpr int kFaceRegionTriangleCount = {len(face)};",
        "",
        mesh.c_array("kFaceRegionTriangles", "uint16_t", [i for t in face for i in t], 15, str),
        mesh.c_array("kFaceMapRgb", "uint8_t", rgb.ravel().tolist(), 32, str),
        "}  // namespace makeup::mesh",
        "",
    ])


def eye_header(params, a8, b8, rect, max_distance, wing_length, eyes) -> str:
    height, width, _ = a8.shape
    return "\n".join([
        "// Generado por tools/uv_masks/gen_face_maps.py desde tools/uv_masks/face.json.",
        "// No editar a mano: cambiar los parámetros y regenerar.",
        "//",
        "// Mapas UV del ojo derecho (el izquierdo se espeja: u' = min(u, 1 - u) por",
        "// vértice) sobre kEyeMapUvRect (u0, v0, ancho, alto; fila 0 = v0).",
        "//   kEyeMapA (RGBA8): párpado, pliegue, V externa, lagrimal.",
        "//   kEyeMapB (RGBA8): hueso de la ceja; distancia a la línea de pestañas",
        "//     superior y distancia al wing (normalizadas por kLinerMaxDistanceUv y",
        "//     por el afinamiento); avance a lo largo del wing [0, 1].",
        "#pragma once",
        "",
        "#include <cstdint>",
        "",
        "namespace makeup::mesh {",
        "",
        f"inline constexpr int kEyeMapsVersion = {params['version']};",
        f"inline constexpr int kEyeMapWidth = {width};",
        f"inline constexpr int kEyeMapHeight = {height};",
        f"inline constexpr float kEyeMapUvRect[4] = {{{', '.join(fmt(v) for v in rect)}}};",
        f"// Distancia UV que corresponde a 1,0 en los canales de distancia (sin afinar).",
        f"inline constexpr float kLinerMaxDistanceUv = {fmt(max_distance)};",
        f"// Largo UV del wing con wing = 1 en la receta.",
        f"inline constexpr float kWingLengthUv = {fmt(wing_length)};",
        "",
        "// Triángulos que tocan el rectángulo de cualquiera de los dos ojos, sin los",
        "// que cruzan la abertura.",
        f"inline constexpr int kEyeRegionTriangleCount = {len(eyes)};",
        "",
        mesh.c_array("kEyeRegionTriangles", "uint16_t", [i for t in eyes for i in t], 15, str),
        mesh.c_array("kEyeMapA", "uint8_t", a8.ravel().tolist(), 32, str),
        mesh.c_array("kEyeMapB", "uint8_t", b8.ravel().tolist(), 32, str),
        "}  // namespace makeup::mesh",
        "",
    ])


def upscale(rgb: np.ndarray) -> np.ndarray:
    # PNG con la fila 0 arriba: se invierte para que v crezca hacia arriba.
    return rgb[::-1].repeat(PREVIEW_SCALE, axis=0).repeat(PREVIEW_SCALE, axis=1)


def face_preview(rgb: np.ndarray) -> bytes:
    return png_bytes(np.ascontiguousarray(upscale(rgb)))


def eye_preview(a8: np.ndarray, b8: np.ndarray) -> bytes:
    """Tres paneles: párpado/pliegue/V externa en RGB; lagrimal (rojo) y hueso
    de la ceja (verde); delineado simulado con grosor 0,5 y wing 0,6."""
    height, width, _ = a8.shape
    panel1 = a8[..., :3]
    panel2 = np.stack([a8[..., 3], b8[..., 0], np.zeros_like(a8[..., 0])], axis=-1)
    b = b8.astype(float) / 255.0
    threshold, feather = 0.35, 0.06
    liner = 1.0 - smoothstep(threshold, threshold + feather, b[..., 1])
    wing = (1.0 - smoothstep(threshold, threshold + feather, b[..., 2])) * (1.0 - smoothstep(0.55, 0.6, b[..., 3]))
    ink = np.maximum(liner, wing)
    shade = (a8[..., 0].astype(float) / 255.0) * 60.0
    panel3 = np.clip(255.0 - shade[..., None] - ink[..., None] * 230.0, 0, 255).astype(np.uint8).repeat(3, axis=-1)
    gap = np.full((height, 2, 3), 255, dtype=np.uint8)
    return png_bytes(np.ascontiguousarray(upscale(np.concatenate([panel1, gap, panel2, gap, panel3], axis=1))))


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true", help="comparar con lo versionado sin escribir")
    args = parser.parse_args()
    sys.stdout.reconfigure(encoding="utf-8")

    params = json.loads(PARAMS.read_text(encoding="utf-8"))
    geo = Geometry(params)
    rgb, face_rect, cheeks = build_face(params, geo)
    a8, b8, eye_rect, max_distance, wing_length = build_eyes(params, geo)
    crossing, counts = geo.opening_crossers()
    face, eyes = region_triangles(geo, crossing, eye_rect)
    outputs = {
        FACE_HEADER: face_header(params, rgb, face_rect, cheeks, face, counts).encode("utf-8"),
        EYE_HEADER: eye_header(params, a8, b8, eye_rect, max_distance, wing_length, eyes).encode("utf-8"),
        FACE_PREVIEW: face_preview(rgb),
        EYE_PREVIEW: eye_preview(a8, b8),
    }
    if args.check:
        # Los headers pueden tener CRLF según core.autocrlf del checkout.
        def same(path: Path, data: bytes) -> bool:
            current = path.read_bytes()
            if path.suffix == ".h":
                current = current.replace(b"\r\n", b"\n")
            return current == data

        stale = [p for p, data in outputs.items() if not p.exists() or not same(p, data)]
        for p in stale:
            print(f"desactualizado: {p.relative_to(ROOT)}")
        if stale:
            print("corré: python tools/uv_masks/gen_face_maps.py")
            return 1
        print("mapas de cara y ojos al día")
        return 0
    for path, data in outputs.items():
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
    print(f"{FACE_HEADER.relative_to(ROOT)}: mapa {rgb.shape[1]}×{rgb.shape[0]}, {len(face)} triángulos "
          f"(excluidos: {counts})")
    print(f"{EYE_HEADER.relative_to(ROOT)}: mapas {a8.shape[1]}×{a8.shape[0]}, rect "
          f"{tuple(round(v, 4) for v in eye_rect)}, {len(eyes)} triángulos")
    print(f"vistas previas: {FACE_PREVIEW.relative_to(ROOT)}, {EYE_PREVIEW.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

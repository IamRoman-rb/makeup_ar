"""Genera el mapa UV de labios del motor (P4) y su vista previa.

Salidas (versionadas: el build de Android no necesita Python):
  packages/makeup_engine/android/src/main/cpp/mesh/lips_maps.h
      kLipsMapRgba: textura RGBA8 que cubre solo el rectángulo UV de los labios.
        R = máscara de labial (1 dentro, 0 en la boca y fuera; borde difuminado).
        G = mapa de brillo (gaussianas sobre el labio inferior y el arco superior).
        B = distancia al borde del labial (el contorno externo corrido
            outerExpand), a ambos lados, normalizada por liner.maxDistance:
            el delineado de labios es 1 - smoothstep sobre este canal.
        A = sin uso (RGBA8: Mali maneja mal los texels de 3 bytes).
      kLipsMapUvRect: rectángulo UV canónico que cubre el mapa.
      kLipsRegionTriangles: triángulos de la malla a dibujar para la capa de
        labios (tocan el rectángulo; sin los que cruzan la boca).
  docs/ar_engine/img/lips_maps.png: vista previa (R en rojo, G en verde,
      contornos en blanco), ampliada ×3.

Parámetros en tools/uv_masks/lips.json (todas las distancias en unidades UV
canónicas; el labio mide ~0,236 de ancho):
  map.width/height   tamaño de la textura en texels.
  map.margin         margen alrededor del contorno externo de los labios.
  mask.outerExpand   cuánto se corre el borde hacia afuera del contorno (efecto
                     delineado; 0 = justo en los landmarks).
  mask.outerFeather  ancho del difuminado del borde externo (centrado en el borde).
  mask.innerFeather  ancho del difuminado desde el contorno interno hacia el labio.
  mask.contourSubdivision  puntos por tramo del suavizado de los contornos
                     (Catmull-Rom por los landmarks); 1 = polígono crudo.
  gloss[]            gaussianas: centro (u, v), sigmaU/sigmaV y amount [0, 1].
  liner.maxDistance  distancia UV que corresponde a 1,0 en el canal B.

Fuente de la geometría: third_party/mediapipe_face_geometry (Apache 2.0), vía
las funciones de tools/mesh/gen_canonical_mesh.py.

Uso:
  python tools/uv_masks/gen_lips_maps.py            regenera
  python tools/uv_masks/gen_lips_maps.py --check    falla si lo versionado no coincide
"""

from __future__ import annotations

import argparse
import json
import struct
import sys
import zlib
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools/mesh"))
import gen_canonical_mesh as mesh  # noqa: E402

PARAMS = Path(__file__).resolve().parent / "lips.json"
HEADER = ROOT / "packages/makeup_engine/android/src/main/cpp/mesh/lips_maps.h"
PREVIEW = ROOT / "docs/ar_engine/img/lips_maps.png"
PREVIEW_SCALE = 3


def segment_distance(points: np.ndarray, polygon: np.ndarray) -> np.ndarray:
    """Distancia de cada punto (N, 2) al borde del polígono cerrado (M, 2)."""
    a = polygon
    b = np.roll(polygon, -1, axis=0)
    ab = b - a
    ap = points[:, None, :] - a[None, :, :]
    t = np.clip((ap * ab).sum(-1) / (ab * ab).sum(-1), 0.0, 1.0)
    closest = a[None, :, :] + t[..., None] * ab[None, :, :]
    return np.linalg.norm(points[:, None, :] - closest, axis=-1).min(axis=1)


def inside_polygon(points: np.ndarray, polygon: np.ndarray) -> np.ndarray:
    """Regla par-impar, vectorizada (misma que mesh.point_in_polygon)."""
    x, y = points[:, 0:1], points[:, 1:2]
    x1, y1 = polygon[:, 0], polygon[:, 1]
    x2, y2 = np.roll(x1, -1), np.roll(y1, -1)
    crosses = (y1 > y) != (y2 > y)
    with np.errstate(divide="ignore", invalid="ignore"):
        x_at = x1 + (y - y1) * (x2 - x1) / (y2 - y1)
    return (crosses & (x < x_at)).sum(axis=1) % 2 == 1


def catmull_rom_closed(polygon: np.ndarray, steps: int) -> np.ndarray:
    """Contorno cerrado suavizado (Catmull-Rom centrípeta): pasa por los
    landmarks y redondea los tramos rectos entre ellos."""
    result = []
    count = len(polygon)
    for i in range(count):
        p0, p1, p2, p3 = (polygon[(i + k) % count] for k in (-1, 0, 1, 2))
        t0 = 0.0
        t1 = t0 + np.linalg.norm(p1 - p0) ** 0.5
        t2 = t1 + np.linalg.norm(p2 - p1) ** 0.5
        t3 = t2 + np.linalg.norm(p3 - p2) ** 0.5
        for t in np.linspace(t1, t2, steps, endpoint=False):
            a1 = (t1 - t) / (t1 - t0) * p0 + (t - t0) / (t1 - t0) * p1
            a2 = (t2 - t) / (t2 - t1) * p1 + (t - t1) / (t2 - t1) * p2
            a3 = (t3 - t) / (t3 - t2) * p2 + (t - t2) / (t3 - t2) * p3
            b1 = (t2 - t) / (t2 - t0) * a1 + (t - t0) / (t2 - t0) * a2
            b2 = (t3 - t) / (t3 - t1) * a2 + (t - t1) / (t3 - t1) * a3
            result.append((t2 - t) / (t2 - t1) * b1 + (t - t1) / (t2 - t1) * b2)
    return np.array(result)


def smoothstep(edge0: float, edge1: float, x: np.ndarray) -> np.ndarray:
    t = np.clip((x - edge0) / (edge1 - edge0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def build(params: dict):
    _, uvs, triangles = mesh.parse_obj(mesh.SOURCE / "canonical_face_model.obj")
    edges = mesh.parse_lip_edges(mesh.SOURCE / "face_mesh_connections.py")
    outer_ids = mesh.ordered_loop(edges, 61)
    inner_ids = mesh.ordered_loop(edges, 78)
    uv = np.array(uvs)
    outer = uv[outer_ids]
    inner = uv[inner_ids]

    width, height = params["map"]["width"], params["map"]["height"]
    margin = params["map"]["margin"]
    u0, v0 = outer.min(axis=0) - margin
    u1, v1 = outer.max(axis=0) + margin
    rect = (float(u0), float(v0), float(u1 - u0), float(v1 - v0))

    # Centros de texel; fila 0 = v mínima (t = 0 de la textura en GL).
    us = u0 + (np.arange(width) + 0.5) / width * rect[2]
    vs = v0 + (np.arange(height) + 0.5) / height * rect[3]
    grid_u, grid_v = np.meshgrid(us, vs)
    points = np.stack([grid_u.ravel(), grid_v.ravel()], axis=1)

    m = params["mask"]
    # La máscara usa los contornos suavizados; la exclusión de la boca, los
    # originales (es por triángulos de la malla).
    steps = m["contourSubdivision"]
    outer_smooth = catmull_rom_closed(outer, steps)
    inner_smooth = catmull_rom_closed(inner, steps)
    signed_outer = np.where(inside_polygon(points, outer_smooth), 1.0, -1.0) * segment_distance(points, outer_smooth)
    outside_inner = np.where(inside_polygon(points, inner_smooth), -1.0, 1.0) * segment_distance(points, inner_smooth)
    edge = -m["outerExpand"]
    half = 0.5 * m["outerFeather"]
    mask = smoothstep(edge - half, edge + half, signed_outer) * smoothstep(0.0, m["innerFeather"], outside_inner)

    gloss = np.zeros(len(points))
    for g in params["gloss"]:
        du = (points[:, 0] - g["u"]) / g["sigmaU"]
        dv = (points[:, 1] - g["v"]) / g["sigmaV"]
        gloss = np.maximum(gloss, g["amount"] * np.exp(-0.5 * (du * du + dv * dv)))
    liner = np.clip(np.abs(signed_outer - edge) / params["liner"]["maxDistance"], 0.0, 1.0)
    rg = np.stack([mask, gloss, liner, np.zeros_like(mask)], axis=1).reshape(height, width, 4)
    rg8 = np.clip(np.rint(rg * 255.0), 0, 255).astype(np.uint8)
    # El brillo solo existe donde hay labio (el shader igual multiplica por la
    # máscara); se compara ya cuantizado para que no quede brillo con máscara 0.
    rg8[..., 1][rg8[..., 0] == 0] = 0

    # Triángulos a dibujar: alguno de sus vértices cae en el rectángulo, sin los
    # que cubren la boca (centro UV dentro del contorno interno): al abrirla se
    # estiran sobre los dientes.
    in_rect = (uv[:, 0] >= u0) & (uv[:, 0] <= u1) & (uv[:, 1] >= v0) & (uv[:, 1] <= v1)
    region, mouth = [], 0
    for tri in triangles:
        if not any(in_rect[i] for i in tri):
            continue
        centroid = uv[list(tri)].mean(axis=0)
        if mesh.point_in_polygon(centroid[0], centroid[1], [tuple(p) for p in inner]):
            mouth += 1
            continue
        region.append(tri)
    return rg8, rect, region, mouth, outer_smooth, inner_smooth


def header_text(params: dict, rg8: np.ndarray, rect, region) -> str:
    height, width, _ = rg8.shape
    fmt = lambda value: f"{value:.6f}f"  # noqa: E731
    return "\n".join([
        "// Generado por tools/uv_masks/gen_lips_maps.py desde tools/uv_masks/lips.json.",
        "// No editar a mano: cambiar los parámetros y regenerar.",
        "//",
        "// Mapa UV de labios: textura RGBA8 que cubre kLipsMapUvRect del UV canónico",
        "// (u0, v0, ancho, alto; v hacia arriba). Fila 0 = v0. R = máscara de labial",
        "// con el borde difuminado; G = mapa de brillo; B = distancia al borde del",
        "// labial / kLipLinerMaxDistanceUv (delineado de labios); A = sin uso.",
        "#pragma once",
        "",
        "#include <cstdint>",
        "",
        "namespace makeup::mesh {",
        "",
        f"inline constexpr int kLipsMapVersion = {params['version']};",
        f"inline constexpr int kLipsMapWidth = {width};",
        f"inline constexpr int kLipsMapHeight = {height};",
        f"inline constexpr float kLipsMapUvRect[4] = {{{', '.join(fmt(v) for v in rect)}}};",
        f"inline constexpr int kLipsRegionTriangleCount = {len(region)};",
        "",
        mesh.c_array("kLipsRegionTriangles", "uint16_t", [i for t in region for i in t], 15, str),
        f"inline constexpr float kLipLinerMaxDistanceUv = {fmt(params['liner']['maxDistance'])};",
        "",
        mesh.c_array("kLipsMapRgba", "uint8_t", rg8.ravel().tolist(), 32, str),
        "}  // namespace makeup::mesh",
        "",
    ])


def png_bytes(rgb: np.ndarray) -> bytes:
    """PNG RGB8 mínimo con zlib (sin Pillow)."""
    height, width, _ = rgb.shape
    raw = b"".join(b"\x00" + rgb[y].tobytes() for y in range(height))

    def chunk(kind: bytes, data: bytes) -> bytes:
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))

    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))


def preview(rg8: np.ndarray, rect, outer: np.ndarray, inner: np.ndarray) -> bytes:
    height, width, _ = rg8.shape
    rgb = np.zeros((height, width, 3), dtype=np.uint8)
    rgb[..., 0] = rg8[..., 0]
    rgb[..., 1] = rg8[..., 1]
    rgb = rgb.repeat(PREVIEW_SCALE, axis=0).repeat(PREVIEW_SCALE, axis=1)
    for polygon in (outer, inner):
        for a, b in zip(polygon, np.roll(polygon, -1, axis=0)):
            for t in np.linspace(0.0, 1.0, 200):
                u, v = a + (b - a) * t
                x = int((u - rect[0]) / rect[2] * width * PREVIEW_SCALE)
                y = int((v - rect[1]) / rect[3] * height * PREVIEW_SCALE)
                if 0 <= x < rgb.shape[1] and 0 <= y < rgb.shape[0]:
                    rgb[y, x] = 255
    # PNG con la fila 0 arriba: se invierte para que v crezca hacia arriba.
    return png_bytes(rgb[::-1].copy())


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true", help="comparar con lo versionado sin escribir")
    args = parser.parse_args()
    sys.stdout.reconfigure(encoding="utf-8")

    params = json.loads(PARAMS.read_text(encoding="utf-8"))
    rg8, rect, region, mouth, outer, inner = build(params)
    outputs = {HEADER: header_text(params, rg8, rect, region).encode("utf-8"),
               PREVIEW: preview(rg8, rect, outer, inner)}
    if args.check:
        # El header puede tener CRLF según core.autocrlf del checkout.
        def same(path: Path, data: bytes) -> bool:
            current = path.read_bytes()
            if path.suffix == ".h":
                current = current.replace(b"\r\n", b"\n")
            return current == data

        stale = [p for p, data in outputs.items() if not p.exists() or not same(p, data)]
        for p in stale:
            print(f"desactualizado: {p.relative_to(ROOT)}")
        if stale:
            print("corré: python tools/uv_masks/gen_lips_maps.py")
            return 1
        print("mapas de labios al día")
        return 0
    for path, data in outputs.items():
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
    covered = float((rg8[..., 0] > 0).mean())
    print(f"{HEADER.relative_to(ROOT)}: mapa {rg8.shape[1]}×{rg8.shape[0]}, rect {tuple(round(v, 4) for v in rect)}, "
          f"{len(region)} triángulos ({mouth} de boca excluidos), máscara > 0 en {covered:.0%} del mapa")
    print(f"{PREVIEW.relative_to(ROOT)}: vista previa ×{PREVIEW_SCALE}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

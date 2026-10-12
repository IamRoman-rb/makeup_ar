"""Genera packages/makeup_engine/android/src/main/cpp/mesh/canonical_mesh.h.

Fuente: packages/makeup_engine/third_party/mediapipe_face_geometry/ (MediaPipe,
Apache 2.0). Los archivos se leen como datos: el .py de MediaPipe se parsea
con expresiones regulares, nunca se ejecuta ni se importa.

Uso:  python tools/mesh/gen_canonical_mesh.py
El header generado se versiona: el build de Android no necesita Python.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "packages/makeup_engine/third_party/mediapipe_face_geometry"
OUTPUT = ROOT / "packages/makeup_engine/android/src/main/cpp/mesh/canonical_mesh.h"

VERTEX_COUNT = 468
# Ojos externos (FaceMesh): 33 queda a la izquierda de la imagen con la cara
# derecha y sin espejar; 263 a la derecha. Definen el ángulo del ROI.
EYE_LEFT_IN_IMAGE = 33
EYE_RIGHT_IN_IMAGE = 263


def parse_obj(path: Path):
    positions, uvs, faces = [], [], []
    for line in path.read_text(encoding="utf-8").splitlines():
        parts = line.split()
        if not parts:
            continue
        if parts[0] == "v":
            positions.append(tuple(float(p) for p in parts[1:4]))
        elif parts[0] == "vt":
            uvs.append(tuple(float(p) for p in parts[1:3]))
        elif parts[0] == "f":
            faces.append(tuple(tuple(int(i) - 1 for i in corner.split("/")[:2]) for corner in parts[1:4]))
    if len(positions) != VERTEX_COUNT:
        sys.exit(f"se esperaban {VERTEX_COUNT} vértices, hay {len(positions)}")

    # En el .obj cada esquina trae su índice de UV: se pasa a una UV por vértice
    # y se verifica que no haya vértices con dos UV distintas.
    vertex_uv: list[tuple[float, float] | None] = [None] * VERTEX_COUNT
    for face in faces:
        for vertex, uv_index in face:
            uv = uvs[uv_index]
            previous = vertex_uv[vertex]
            if previous is not None and previous != uv:
                sys.exit(f"el vértice {vertex} tiene dos UV: {previous} y {uv}")
            vertex_uv[vertex] = uv
    missing = [i for i, uv in enumerate(vertex_uv) if uv is None]
    if missing:
        sys.exit(f"vértices sin UV: {missing[:10]}")
    triangles = [tuple(vertex for vertex, _ in face) for face in faces]
    return positions, vertex_uv, triangles


def parse_procrustes(path: Path):
    pattern = re.compile(r"procrustes_landmark_basis\s*\{\s*landmark_id:\s*(\d+)\s+weight:\s*([0-9.eE+-]+)\s*\}")
    basis = [(int(i), float(w)) for i, w in pattern.findall(path.read_text(encoding="utf-8"))]
    if not basis:
        sys.exit("no se encontró procrustes_landmark_basis")
    return basis


def parse_lip_edges(path: Path):
    text = path.read_text(encoding="utf-8")
    match = re.search(r"FACEMESH_LIPS\s*=\s*frozenset\(\[(.*?)\]\)", text, re.S)
    if match is None:
        sys.exit("no se encontró FACEMESH_LIPS")
    return [(int(a), int(b)) for a, b in re.findall(r"\((\d+),\s*(\d+)\)", match.group(1))]


def ordered_loop(edges, start: int):
    """Recorre el ciclo que contiene [start] (cada vértice tiene grado 2)."""
    neighbors: dict[int, list[int]] = {}
    for a, b in edges:
        neighbors.setdefault(a, []).append(b)
        neighbors.setdefault(b, []).append(a)
    if any(len(n) != 2 for n in neighbors.values()):
        sys.exit("los contornos de labios no son ciclos simples")
    loop, previous, current = [start], None, start
    while True:
        a, b = neighbors[current]
        following = b if a == previous else a
        if following == start:
            return loop
        loop.append(following)
        previous, current = current, following


def point_in_polygon(x: float, y: float, polygon) -> bool:
    inside = False
    for i in range(len(polygon)):
        x1, y1 = polygon[i]
        x2, y2 = polygon[(i + 1) % len(polygon)]
        if (y1 > y) != (y2 > y) and x < x1 + (y - y1) * (x2 - x1) / (y2 - y1):
            inside = not inside
    return inside


def lip_triangles(positions, triangles, outer, inner):
    # Proyección frontal (x, y) de la malla canónica: un triángulo es de labio
    # si su baricentro cae dentro del contorno externo y fuera del interno.
    outer_xy = [positions[i][:2] for i in outer]
    inner_xy = [positions[i][:2] for i in inner]
    result = []
    for tri in triangles:
        cx = sum(positions[i][0] for i in tri) / 3
        cy = sum(positions[i][1] for i in tri) / 3
        if point_in_polygon(cx, cy, outer_xy) and not point_in_polygon(cx, cy, inner_xy):
            result.append(tri)
    return result


def c_array(name: str, ctype: str, values, per_line: int, fmt) -> str:
    items = [fmt(v) for v in values]
    lines = [", ".join(items[i : i + per_line]) for i in range(0, len(items), per_line)]
    body = ",\n    ".join(lines)
    return f"inline constexpr {ctype} {name}[] = {{\n    {body},\n}};\n"


def main() -> None:
    positions, uvs, triangles = parse_obj(SOURCE / "canonical_face_model.obj")
    basis = parse_procrustes(SOURCE / "geometry_pipeline_metadata_landmarks.pbtxt")
    lip_edges = parse_lip_edges(SOURCE / "face_mesh_connections.py")
    outer = ordered_loop(lip_edges, 61)
    inner = ordered_loop(lip_edges, 78)
    if set(outer) & set(inner) or len(outer) + len(inner) != len({v for e in lip_edges for v in e}):
        sys.exit("se esperaban dos contornos de labios disjuntos")
    lips = lip_triangles(positions, triangles, outer, inner)

    def fmt_float(value: float) -> str:
        return f"{value:.6f}f"

    out = [
        "// Generado por tools/mesh/gen_canonical_mesh.py. No editar a mano.",
        "// Fuente: third_party/mediapipe_face_geometry (MediaPipe, Apache 2.0).",
        "//",
        "// Malla canónica de FaceMesh: 468 vértices en cm (x a la derecha de la",
        "// imagen, y hacia arriba, z hacia la cámara), UV por vértice (v hacia",
        "// arriba, convención OBJ) y triángulos. Los índices coinciden con los",
        "// primeros 468 landmarks de FaceMesh-V2 (los 10 restantes son iris).",
        "#pragma once",
        "",
        "#include <cstdint>",
        "",
        "namespace makeup::mesh {",
        "",
        f"inline constexpr int kVertexCount = {VERTEX_COUNT};",
        f"inline constexpr int kTriangleCount = {len(triangles)};",
        f"inline constexpr int kLipTriangleCount = {len(lips)};",
        f"inline constexpr int kProcrustesCount = {len(basis)};",
        f"inline constexpr int kEyeLeftInImage = {EYE_LEFT_IN_IMAGE};",
        f"inline constexpr int kEyeRightInImage = {EYE_RIGHT_IN_IMAGE};",
        "",
        c_array("kPositions", "float", [c for p in positions for c in p], 6, fmt_float),
        c_array("kUvs", "float", [c for uv in uvs for c in uv], 8, fmt_float),
        c_array("kTriangles", "uint16_t", [i for t in triangles for i in t], 15, str),
        "// Triángulos de los labios (subconjunto de kTriangles): entre el contorno",
        "// externo y el interno de FACEMESH_LIPS.",
        c_array("kLipTriangles", "uint16_t", [i for t in lips for i in t], 15, str),
        "// Contornos de labios ordenados (externo desde la comisura 61, interno desde 78).",
        f"inline constexpr int kLipsOuterCount = {len(outer)};",
        c_array("kLipsOuter", "uint16_t", outer, 20, str),
        f"inline constexpr int kLipsInnerCount = {len(inner)};",
        c_array("kLipsInner", "uint16_t", inner, 20, str),
        "// Base de Procrustes de MediaPipe: puntos estables (frente, nariz, pómulos)",
        "// y su peso para resolver la pose.",
        c_array("kProcrustesIndices", "int", [i for i, _ in basis], 16, str),
        c_array("kProcrustesWeights", "float", [w for _, w in basis], 6, fmt_float),
        "}  // namespace makeup::mesh",
        "",
    ]
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text("\n".join(out), encoding="utf-8", newline="\n")
    print(
        f"{OUTPUT.relative_to(ROOT)}: {VERTEX_COUNT} vértices, {len(triangles)} triángulos, "
        f"{len(lips)} de labios, contornos {len(outer)}/{len(inner)}, Procrustes {len(basis)}"
    )


if __name__ == "__main__":
    main()

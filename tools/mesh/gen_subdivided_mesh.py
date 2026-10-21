"""Genera packages/makeup_engine/android/src/main/cpp/mesh/subdivided_mesh.h.

Malla suave (docs/ar_engine/TRACKER.md §9): cada triángulo de la malla
canónica se parte en 4 con un punto nuevo por arista. Los landmarks quedan
donde están (esquema interpolante: el labial sigue llegando a las comisuras)
y cada punto nuevo es una combinación fija de landmarks vecinos (stencil):

- Arista interior: butterfly (Dyn, Gregory y Levin, 1990, w = 1/16):
  1/2 los extremos, 1/8 los dos opuestos y -1/16 los cuatro lejanos. Si un
  lejano no existe (arista del triángulo vecino en el borde), se usa su
  reflejo en paralelogramo, que mantiene la suma 1.
- Arista del borde: esquema de 4 puntos, 9/16 los extremos y -1/16 los
  vecinos sobre el borde.
- Pliegues: el contorno interno de los labios y el de cada ojo. Con la boca o
  los ojos cerrados, la malla de MediaPipe los cruza con triángulos finitos;
  si el stencil los atravesara, la comisura se correría hacia el otro labio
  (hasta un 64 % del largo de la arista). Una arista del pliegue usa los 4
  puntos a lo largo del contorno, ningún stencil cruza el pliegue (el lejano
  del otro lado se refleja) y las cuerdas que unen dos puntos del contorno sin
  ser parte de él (la ranura de la boca o del ojo) quedan en el punto medio.

La UV del punto nuevo es el punto medio de las UV de la arista: así los mapas
del motor (labios, cara, ojos) siguen la superficie suave en pantalla en lugar
de quebrarse en cada triángulo. Con el modo suave apagado, el render usa el
punto medio lineal (misma topología, misma imagen que la malla de 468).

Uso:  python tools/mesh/gen_subdivided_mesh.py [--check]
El header generado se versiona; --check verifica que esté al día.
"""

from __future__ import annotations

import re
import sys
from collections import defaultdict
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import gen_canonical_mesh as canonical  # noqa: E402

ROOT = canonical.ROOT
OUTPUT = ROOT / "packages/makeup_engine/android/src/main/cpp/mesh/subdivided_mesh.h"

EDGE_WEIGHT = 0.5
WING_WEIGHT = 0.125
FAR_WEIGHT = -0.0625
BOUNDARY_NEAR = 9.0 / 16.0
BOUNDARY_FAR = -1.0 / 16.0
WEIGHT_EPSILON = 1e-9


def edge_key(a: int, b: int) -> tuple[int, int]:
    return (a, b) if a < b else (b, a)


def build_topology(triangles):
    """Aristas ordenadas y, por arista, los vértices opuestos de sus triángulos."""
    opposite: dict[tuple[int, int], list[int]] = defaultdict(list)
    for a, b, c in triangles:
        opposite[edge_key(a, b)].append(c)
        opposite[edge_key(b, c)].append(a)
        opposite[edge_key(c, a)].append(b)
    for edge, others in opposite.items():
        if len(others) > 2:
            raise ValueError(f"arista no manifold {edge}: {len(others)} triángulos")
    return sorted(opposite), opposite


def boundary_neighbors(opposite):
    """Por vértice del borde, sus dos vecinos sobre el borde."""
    neighbors: dict[int, list[int]] = defaultdict(list)
    for (a, b), others in opposite.items():
        if len(others) == 1:
            neighbors[a].append(b)
            neighbors[b].append(a)
    for vertex, around in neighbors.items():
        if len(around) != 2:
            raise ValueError(f"vértice {vertex} con {len(around)} aristas de borde")
    return neighbors


def parse_loop(name: str):
    """Aristas de un contorno cerrado de face_mesh_connections.py (FACEMESH_*)."""
    text = (canonical.SOURCE / "face_mesh_connections.py").read_text(encoding="utf-8")
    match = re.search(name + r"\s*=\s*frozenset\(\[(.*?)\]\)", text, re.S)
    if match is None:
        sys.exit(f"no se encontró {name}")
    return [edge_key(int(a), int(b)) for a, b in re.findall(r"\((\d+),\s*(\d+)\)", match.group(1))]


def crease_edges():
    """Contorno interno de los labios (desde la comisura 78) y de cada ojo."""
    lips = canonical.parse_lip_edges(canonical.SOURCE / "face_mesh_connections.py")
    inner = canonical.ordered_loop(lips, 78)
    edges = {edge_key(inner[i], inner[(i + 1) % len(inner)]) for i in range(len(inner))}
    edges |= set(parse_loop("FACEMESH_LEFT_EYE"))
    edges |= set(parse_loop("FACEMESH_RIGHT_EYE"))
    return edges


def curve_neighbors(edges):
    """Por vértice, sus dos vecinos sobre la curva (borde o pliegue)."""
    neighbors: dict[int, list[int]] = defaultdict(list)
    for a, b in edges:
        neighbors[a].append(b)
        neighbors[b].append(a)
    for vertex, around in neighbors.items():
        if len(around) != 2:
            raise ValueError(f"vértice {vertex} con {len(around)} aristas en la curva")
    return neighbors


def far_vertex(opposite, creases, a: int, c: int, b: int):
    """Vértice opuesto a [b] cruzando la arista (a, c); None si es borde o pliegue."""
    if edge_key(a, c) in creases:
        return None
    others = [v for v in opposite[edge_key(a, c)] if v != b]
    return others[0] if others else None


def stencil(edge, opposite, boundary, creases=frozenset(), crease_curve=None) -> dict[int, float]:
    a, b = edge
    weights: dict[int, float] = defaultdict(float)
    others = opposite[edge]
    crease_curve = crease_curve or {}
    if edge not in creases and a in crease_curve and b in crease_curve:
        # Cuerda de la ranura (boca u ojo): punto medio.
        return {a: EDGE_WEIGHT, b: EDGE_WEIGHT}
    if edge in creases or len(others) == 1:
        curve = crease_curve if edge in creases else boundary
        p = next(v for v in curve[a] if v != b)
        q = next(v for v in curve[b] if v != a)
        weights[a] += BOUNDARY_NEAR
        weights[b] += BOUNDARY_NEAR
        weights[p] += BOUNDARY_FAR
        weights[q] += BOUNDARY_FAR
    else:
        weights[a] += EDGE_WEIGHT
        weights[b] += EDGE_WEIGHT
        for wing in others:
            weights[wing] += WING_WEIGHT
            # Lejanos: cruzando (a, wing) y (b, wing), opuestos a b y a.
            for near, across in ((a, b), (b, a)):
                far = far_vertex(opposite, creases, near, wing, across)
                if far is None:
                    # Reflejo en paralelogramo: near + wing - across.
                    weights[near] += FAR_WEIGHT
                    weights[wing] += FAR_WEIGHT
                    weights[across] -= FAR_WEIGHT
                else:
                    weights[far] += FAR_WEIGHT
    return {v: w for v, w in sorted(weights.items()) if abs(w) > WEIGHT_EPSILON}


def subdivide(triangles, uvs, creases=frozenset()):
    edges, opposite = build_topology(triangles)
    boundary = boundary_neighbors(opposite)
    missing = [e for e in creases if e not in opposite]
    if missing:
        raise ValueError(f"aristas de pliegue que no están en la malla: {missing[:5]}")
    crease_curve = curve_neighbors(creases) if creases else {}
    stencils = [stencil(edge, opposite, boundary, creases, crease_curve) for edge in edges]
    edge_uvs = [((uvs[a][0] + uvs[b][0]) / 2, (uvs[a][1] + uvs[b][1]) / 2) for a, b in edges]
    return edges, stencils, edge_uvs


def render(edges, stencils, edge_uvs) -> str:
    starts = [0]
    indices: list[int] = []
    weights: list[float] = []
    for entry in stencils:
        for vertex, weight in entry.items():
            indices.append(vertex)
            weights.append(weight)
        starts.append(len(indices))
    if len(indices) > 0xFFFF:
        raise ValueError("demasiados pesos para uint16_t")

    def fmt_float(value: float) -> str:
        return f"{value:.6f}f"

    out = [
        "// Generado por tools/mesh/gen_subdivided_mesh.py. No editar a mano.",
        "//",
        "// Malla suave (docs/ar_engine/TRACKER.md §9): un punto nuevo por arista de",
        "// kTriangles. El punto e es kVertexCount + e; sus coordenadas en pantalla",
        "// son la suma de kSubStencilWeight[i] · landmark kSubStencilIndex[i] con i",
        "// en [kSubStencilStart[e], kSubStencilStart[e + 1]) (butterfly en el",
        "// interior, 4 puntos en el borde y a lo largo de los pliegues: contorno",
        "// interno de los labios y de los ojos) y su UV es kSubEdgeUvs[e].",
        "#pragma once",
        "",
        "#include <cstdint>",
        "",
        '#include "mesh/canonical_mesh.h"',
        "",
        "namespace makeup::mesh {",
        "",
        f"inline constexpr int kSubEdgeCount = {len(edges)};",
        "inline constexpr int kSubVertexCount = kVertexCount + kSubEdgeCount;",
        f"inline constexpr int kSubStencilEntries = {len(indices)};",
        "",
        "// Aristas (a < b), ordenadas por (a, b): búsqueda binaria.",
        canonical.c_array("kSubEdges", "uint16_t", [v for e in edges for v in e], 16, str),
        canonical.c_array("kSubEdgeUvs", "float", [c for uv in edge_uvs for c in uv], 8, fmt_float),
        canonical.c_array("kSubStencilStart", "uint16_t", starts, 16, str),
        canonical.c_array("kSubStencilIndex", "uint16_t", indices, 16, str),
        canonical.c_array("kSubStencilWeight", "float", weights, 8, fmt_float),
        "}  // namespace makeup::mesh",
        "",
    ]
    return "\n".join(out)


def main() -> None:
    _, uvs, triangles = canonical.parse_obj(canonical.SOURCE / "canonical_face_model.obj")
    edges, stencils, edge_uvs = subdivide(triangles, uvs, crease_edges())
    for edge, entry in zip(edges, stencils):
        total = sum(entry.values())
        if abs(total - 1.0) > 1e-6:
            sys.exit(f"el stencil de {edge} suma {total}")
    text = render(edges, stencils, edge_uvs)
    if "--check" in sys.argv[1:]:
        current = OUTPUT.read_text(encoding="utf-8") if OUTPUT.exists() else ""
        if current != text:
            sys.exit(f"{OUTPUT.relative_to(ROOT)} no está al día: correr tools/mesh/gen_subdivided_mesh.py")
        print(f"{OUTPUT.relative_to(ROOT)} al día")
        return
    OUTPUT.write_text(text, encoding="utf-8", newline="\n")
    boundary = sum(1 for e in stencils if len(e) <= 4)
    print(f"{OUTPUT.relative_to(ROOT)}: {len(edges)} puntos nuevos ({boundary} en el borde), "
          f"{sum(len(e) for e in stencils)} pesos")


if __name__ == "__main__":
    main()

"""Tests del generador de la malla suave (tools/mesh/gen_subdivided_mesh.py).

python -m unittest discover -s tools/mesh
"""

from __future__ import annotations

import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import gen_canonical_mesh as canonical  # noqa: E402
import gen_subdivided_mesh as sub  # noqa: E402


def grid(n: int):
    """Grilla regular de n×n vértices (triángulos con la misma diagonal)."""
    points = [(float(x), float(y)) for y in range(n) for x in range(n)]
    triangles = []
    for y in range(n - 1):
        for x in range(n - 1):
            a = y * n + x
            b, c, d = a + 1, a + n, a + n + 1
            triangles += [(a, b, d), (a, d, c)]
    return points, triangles


def collinear(pts) -> bool:
    (x0, y0), (x1, y1) = pts[0], pts[1]
    return all(abs((x1 - x0) * (y - y0) - (y1 - y0) * (x - x0)) < 1e-9 for x, y in pts[2:])


def apply(entry, values):
    return sum(w * values[v] for v, w in entry.items())


class SubdividedMeshTest(unittest.TestCase):
    def test_stencils_suman_uno(self):
        points, triangles = grid(6)
        edges, stencils, _ = sub.subdivide(triangles, points)
        self.assertEqual(len(edges), len(stencils))
        for entry in stencils:
            self.assertAlmostEqual(sum(entry.values()), 1.0, places=9)

    def test_grilla_regular_reproduce_lo_lineal(self):
        # Butterfly reproduce polinomios lineales en una grilla regular, también
        # cerca del borde (reflejo en paralelogramo y 4 puntos en el borde recto).
        points, triangles = grid(7)
        edges, stencils, _ = sub.subdivide(triangles, points)
        _, opposite = sub.build_topology(triangles)
        f = [2.0 * x - 3.0 * y + 1.0 for x, y in points]
        checked = 0
        for (a, b), entry in zip(edges, stencils):
            # En las esquinas de la grilla el borde dobla 90° y los 4 puntos no
            # están alineados: ahí no hay reproducción lineal (la malla de la
            # cara no tiene esquinas así: su borde es el óvalo).
            if len(opposite[(a, b)]) == 1 and not collinear([points[v] for v in entry]):
                continue
            checked += 1
            expected = (f[a] + f[b]) / 2
            self.assertAlmostEqual(apply(entry, f), expected, places=9, msg=f"arista {(a, b)}")
        self.assertGreater(checked, len(edges) - 10)

    def test_borde_usa_cuatro_puntos(self):
        points, triangles = grid(5)
        edges, stencils, _ = sub.subdivide(triangles, points)
        _, opposite = sub.build_topology(triangles)
        for edge, entry in zip(edges, stencils):
            if len(opposite[edge]) == 1:
                weights = sorted(entry.values())
                self.assertEqual(len(weights), 4, msg=str(edge))
                self.assertAlmostEqual(weights[0], -1 / 16)
                self.assertAlmostEqual(weights[-1], 9 / 16)

    def test_uv_es_el_punto_medio(self):
        points, triangles = grid(4)
        edges, _, uvs = sub.subdivide(triangles, points)
        for (a, b), uv in zip(edges, uvs):
            self.assertAlmostEqual(uv[0], (points[a][0] + points[b][0]) / 2)
            self.assertAlmostEqual(uv[1], (points[a][1] + points[b][1]) / 2)

    def test_malla_canonica(self):
        _, uvs, triangles = canonical.parse_obj(canonical.SOURCE / "canonical_face_model.obj")
        edges, stencils, _ = sub.subdivide(triangles, uvs, sub.crease_edges())
        self.assertEqual(len(edges), 1365)
        for (a, b), entry in zip(edges, stencils):
            self.assertAlmostEqual(sum(entry.values()), 1.0, places=9)
            # 1/2 menos, a lo sumo, dos reflejos de -1/16.
            self.assertGreaterEqual(entry[a], 0.375 - 1e-9)
            self.assertGreaterEqual(entry[b], 0.375 - 1e-9)

    def test_pliegues_usan_cuatro_puntos_sobre_el_contorno(self):
        # Una arista del contorno interno de los labios o de un ojo no mira el
        # otro lado de la ranura: solo puntos del mismo contorno.
        _, uvs, triangles = canonical.parse_obj(canonical.SOURCE / "canonical_face_model.obj")
        creases = sub.crease_edges()
        edges, stencils, _ = sub.subdivide(triangles, uvs, creases)
        curve = {v for e in creases for v in e}
        for edge, entry in zip(edges, stencils):
            if edge in creases:
                self.assertEqual(len(entry), 4, msg=str(edge))
                self.assertTrue(set(entry) <= curve, msg=str(edge))

    def test_cuerda_de_la_ranura_es_punto_medio(self):
        _, uvs, triangles = canonical.parse_obj(canonical.SOURCE / "canonical_face_model.obj")
        creases = sub.crease_edges()
        edges, stencils, _ = sub.subdivide(triangles, uvs, creases)
        curve = {v for e in creases for v in e}
        chords = [(e, s) for e, s in zip(edges, stencils) if e not in creases and e[0] in curve and e[1] in curve]
        self.assertTrue(chords)
        for (a, b), entry in chords:
            self.assertEqual(entry, {a: 0.5, b: 0.5})

    def test_header_al_dia(self):
        _, uvs, triangles = canonical.parse_obj(canonical.SOURCE / "canonical_face_model.obj")
        text = sub.render(*sub.subdivide(triangles, uvs, sub.crease_edges()))
        self.assertEqual(sub.OUTPUT.read_text(encoding="utf-8"), text, "correr tools/mesh/gen_subdivided_mesh.py")


if __name__ == "__main__":
    unittest.main()

"""Tests del modelo más denso y del espejo (tools/model/dense.py).

Uso:  python -m unittest discover -s tools/model
"""

from __future__ import annotations

import sys
import unittest
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "mesh"))
import gen_canonical_mesh as canonical  # noqa: E402
from dense import (DENSE_POINTS, DENSE_SPEC, IRIS_CENTERS, _point_to_polyline, contour_nme,  # noqa: E402
                   dense_targets, flip_points, loop, mirror_map, resample_closed)
from geometry import LANDMARK_COUNT, MESH_VERTEX_COUNT  # noqa: E402


def canonical_points() -> np.ndarray:
    """Los 478 puntos: la malla canónica en px (x a la derecha, y hacia abajo) e
    iris sintéticos (centro + derecha, arriba, izquierda, abajo en la imagen)."""
    positions, _, _ = canonical.parse_obj(canonical.SOURCE / "canonical_face_model.obj")
    pos = np.asarray(positions)
    points = np.zeros((LANDMARK_COUNT, 3))
    points[:MESH_VERTEX_COUNT, 0] = 300 + 20 * pos[:, 0]
    points[:MESH_VERTEX_COUNT, 1] = 300 - 20 * pos[:, 1]
    points[:MESH_VERTEX_COUNT, 2] = 20 * pos[:, 2]
    for center, eye in zip(IRIS_CENTERS, (33, 263)):
        c = points[eye, :2] + np.array([20.0 if eye == 33 else -20.0, 0.0])
        ring = c + np.array([[4, 0], [0, -4], [-4, 0], [0, 4]], dtype=float)
        points[center, :2] = c
        points[center + 1:center + 5, :2] = ring
    return points


class DenseTest(unittest.TestCase):
    def test_lazos_de_labios_y_ojos(self):
        for _, name, start, _ in DENSE_SPEC:
            ids = loop(name, start)
            self.assertEqual(ids[0], start)
            self.assertGreaterEqual(len(ids), 16)
        self.assertEqual(DENSE_POINTS, 64 + 48 + 32 + 32)

    def test_remuestreo_equiespaciado_sobre_un_circulo(self):
        angles = np.linspace(0, 2 * np.pi, 12, endpoint=False)
        circle = np.stack([np.cos(angles), np.sin(angles)], axis=1) * 10
        out = resample_closed(circle, 40)
        self.assertEqual(out.shape, (40, 2))
        np.testing.assert_allclose(out[0], circle[0])
        steps = np.linalg.norm(np.diff(np.vstack([out, out[:1]]), axis=0), axis=1)
        self.assertLess(steps.std() / steps.mean(), 0.05)

    def test_pseudo_etiquetas_pasan_cerca_de_los_landmarks(self):
        points = canonical_points()
        dense = dense_targets(points)
        self.assertEqual(dense.shape, (DENSE_POINTS, 2))
        # La curva densa pasa por los landmarks del contorno externo de los labios
        # (distancia punto-a-polilínea, con ~4 px entre puntos densos).
        ids = list(loop("FACEMESH_LIPS", 61))
        lips = dense[:64]
        distances = _point_to_polyline(points[ids, :2], lips)
        self.assertLess(float(distances.max()), 0.6)

    def test_metrica_de_contorno(self):
        points = canonical_points()
        dense = dense_targets(points)
        truth = {"labios_externo": points[list(loop("FACEMESH_LIPS", 61)), :2]}
        exact = contour_nme(dense, truth, interocular=100.0)
        self.assertLess(exact["labios_externo"], 0.004)
        shifted = dense.copy()
        shifted[:64, 1] += 3.0
        worse = contour_nme(shifted, truth, interocular=100.0)
        self.assertGreater(worse["labios_externo"], exact["labios_externo"] + 0.01)
        self.assertNotIn("ojo_izquierdo_imagen", worse)  # sin etiqueta, no opina

    def test_mapa_espejo_es_una_involucion_simetrica(self):
        mapping = mirror_map()
        self.assertEqual(mapping.shape, (LANDMARK_COUNT,))
        np.testing.assert_array_equal(mapping[mapping], np.arange(LANDMARK_COUNT))
        self.assertEqual(int(mapping[33]), 263)
        self.assertEqual(int(mapping[61]), 291)
        self.assertEqual(int(mapping[1]), 1)  # punta de la nariz, en el medio

    def test_espejar_dos_veces_vuelve_y_la_cara_espejada_es_la_misma(self):
        points = canonical_points()
        width = 600.0
        twice = flip_points(flip_points(points, width), width)
        np.testing.assert_allclose(twice, points, atol=1e-9)
        # La cara canónica es simétrica respecto de x = 300: espejada queda igual.
        flipped = flip_points(points, width)
        np.testing.assert_allclose(flipped[:MESH_VERTEX_COUNT, :2], points[:MESH_VERTEX_COUNT, :2], atol=0.5)
        # El iris conserva el patrón angular de su índice (derecha, arriba, izquierda, abajo).
        for center in IRIS_CENTERS:
            ring = flipped[center + 1:center + 5, :2] - flipped[center, :2]
            np.testing.assert_allclose(np.sign(ring), np.sign(points[center + 1:center + 5, :2] - points[center, :2]))


class DenseStudentTest(unittest.TestCase):
    def test_cabezal_denso_y_perdida(self):
        import torch

        from student import INPUT_SIZE, LandmarkStudent
        from train import distill_loss, train_step

        torch.manual_seed(0)
        model = LandmarkStudent(width=0.5, dense_points=DENSE_POINTS)
        images = torch.rand(2, 3, INPUT_SIZE, INPUT_SIZE)
        points, presence, dense = model(images)
        self.assertEqual(tuple(dense.shape), (2, DENSE_POINTS, 2))
        targets = torch.rand(2, LANDMARK_COUNT, 3)
        target_dense = torch.rand(2, DENSE_POINTS, 2)
        _, parts = distill_loss(points, presence, targets, torch.ones(2), dense, target_dense)
        self.assertIn("denso", parts)
        optimizer = torch.optim.AdamW(model.parameters(), lr=1e-3)
        batch = (images, targets, torch.ones(2), target_dense)
        first = train_step(model, optimizer, batch)["denso"]
        for _ in range(15):
            last = train_step(model, optimizer, batch)["denso"]
        self.assertLess(last, first)

    def test_muestra_espejada_con_contornos(self):
        from train import make_sample

        rng = np.random.default_rng(3)
        image = rng.integers(0, 255, (600, 600, 3), dtype=np.uint8)
        points = canonical_points()
        pixels, target, dense = make_sample(image, points, None, 1.5, flip=True, dense=True)
        self.assertEqual(dense.shape, (DENSE_POINTS, 2))
        self.assertTrue(np.all((dense > 0) & (dense < 1)))
        self.assertEqual(target.shape, (LANDMARK_COUNT, 3))
        self.assertEqual(pixels.shape[0], 3)


if __name__ == "__main__":
    unittest.main()

"""Tests de la infraestructura del modelo propio (sin datos ni modelos reales).

Uso:  python -m unittest discover -s tools/model
"""

from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
from dataset import ManifestError, coverage, load_manifest, parse_record, split_of, split_records  # noqa: E402
from geometry import (EYE_LEFT_IN_IMAGE, EYE_RIGHT_IN_IMAGE, LANDMARK_COUNT, Roi, blazeface_anchors,  # noqa: E402
                      decode_blazeface, image_to_roi, regions, roi_from_points, roi_to_image)
from metrics import exit_criterion, jitter_px, nme_by_region  # noqa: E402

GOOD = {"video": "s001/a.mp4", "subject": "s001", "consent_id": "C-1", "fitzpatrick": 4, "light": "warm"}


def fake_face(rng: np.random.Generator, n: int = 1, size: float = 200.0) -> np.ndarray:
    """(n, 478, 3) puntos en una caja, con los ojos horizontales a 100 px."""
    points = rng.uniform(0, size, (n, LANDMARK_COUNT, 3)) + 100.0
    points[:, EYE_LEFT_IN_IMAGE, :2] = (150.0, 180.0)
    points[:, EYE_RIGHT_IN_IMAGE, :2] = (250.0, 180.0)
    return points


class GeometryTest(unittest.TestCase):
    def test_roi_ida_y_vuelta(self):
        roi = Roi(320.0, 240.0, 180.0, 0.4)
        uv = np.random.default_rng(1).uniform(0, 1, (50, 2))
        np.testing.assert_allclose(image_to_roi(roi, roi_to_image(roi, uv)), uv, atol=1e-9)

    def test_roi_desde_puntos_sigue_la_linea_de_los_ojos(self):
        points = fake_face(np.random.default_rng(2))[0]
        roi = roi_from_points(points[:468], 1.5)
        self.assertAlmostEqual(roi.rotation, 0.0, places=9)
        inside = image_to_roi(roi, points[:468, :2])
        self.assertTrue(np.all((inside > 0) & (inside < 1)))

    def test_anclas_de_blazeface(self):
        anchors = blazeface_anchors(128)
        self.assertEqual(len(anchors), 896)  # BlazeFaceDecoder::kAnchorCount
        np.testing.assert_allclose(anchors[0], (0.5 / 16, 0.5 / 16))

    def test_decodificacion_con_una_cara(self):
        anchors = blazeface_anchors(128)
        regressors = np.zeros((896, 16))
        logits = np.full(896, -10.0)
        best = 300
        logits[best] = 5.0
        regressors[best, 2:4] = 40.0  # 40 px de lado
        regressors[best, 4:6] = (-10.0, -5.0)  # ojo A
        det = decode_blazeface(regressors, logits, 0.5, 0.3)
        self.assertIsNotNone(det)
        self.assertAlmostEqual(det.box[2], 40 / 128)
        np.testing.assert_allclose(det.keypoints[0], anchors[best] + (-10 / 128, -5 / 128))
        self.assertIsNone(decode_blazeface(regressors, np.full(896, -10.0), 0.5, 0.3))

    def test_regiones(self):
        r = regions()
        self.assertEqual(len(r["iris"]), 10)
        self.assertIn(13, r["labios"])  # centro del labio superior interno
        self.assertIn(EYE_LEFT_IN_IMAGE, r["ojos"])


class MetricsTest(unittest.TestCase):
    def test_nme_cero_y_proporcional(self):
        truth = fake_face(np.random.default_rng(3), 4)
        self.assertEqual(nme_by_region(truth, truth)["labios"], 0.0)
        shifted = truth.copy()
        shifted[..., 0] += 5.0  # 5 px con ojos a 100 px -> 0,05
        nme = nme_by_region(shifted, truth)
        self.assertAlmostEqual(nme["malla"], 0.05, places=9)

    def test_nme_con_mascara(self):
        truth = fake_face(np.random.default_rng(4), 2)
        pred = truth.copy()
        pred[:, 468:, :2] += 50.0  # iris muy mal
        mask = np.zeros((2, LANDMARK_COUNT), dtype=bool)
        mask[:, :468] = True  # el iris no se marcó a mano
        nme = nme_by_region(pred, truth, mask)
        self.assertNotIn("iris", nme)
        self.assertEqual(nme["malla"], 0.0)

    def test_jitter_descuenta_la_deriva(self):
        rng = np.random.default_rng(5)
        base = fake_face(rng)[0]
        t = np.arange(60)[:, None, None]
        drift = base[None] + t * np.array([0.5, 0.2, 0.0])  # se mueve lento, sin ruido
        self.assertLess(jitter_px(drift), 1e-9)
        noisy = drift + rng.normal(0, 0.4, drift.shape) * np.array([1, 1, 0])
        self.assertAlmostEqual(jitter_px(noisy), 0.4 * np.sqrt(2), delta=0.05)

    def test_criterio_de_salida(self):
        self.assertEqual(exit_criterion({"labios": 0.03, "ojos": 0.05}, {"labios": 0.035, "ojos": 0.04}),
                         {"labios": True, "ojos": False})


class DatasetTest(unittest.TestCase):
    def test_registro_valido(self):
        record = parse_record(GOOD)
        self.assertEqual(record.fitzpatrick, 4)
        self.assertFalse(record.static)

    def test_rechaza_sin_consentimiento_o_mal_formado(self):
        bad = [
            {**GOOD, "consent_id": ""},
            {k: v for k, v in GOOD.items() if k != "consent_id"},
            {**GOOD, "fitzpatrick": 7},
            {**GOOD, "light": "disco"},
            {**GOOD, "video": "../fuera.mp4"},
            {**GOOD, "video": "/abs.mp4"},
            {**GOOD, "nombre": "Ana"},
        ]
        for raw in bad:
            with self.assertRaises(ManifestError):
                parse_record(raw)

    def test_revocados_quedan_afuera(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "manifest.jsonl"
            lines = [GOOD, {**GOOD, "subject": "s002", "consent_id": "C-2", "video": "s002/a.mp4"}]
            path.write_text("\n".join(json.dumps(x) for x in lines) + "\n", encoding="utf-8")
            self.assertEqual([r.subject for r in load_manifest(path, {"C-1"})], ["s002"])

    def test_split_por_persona_sin_fugas(self):
        records = [parse_record({**GOOD, "subject": f"s{i:03d}", "video": f"s{i:03d}/{j}.mp4"})
                   for i in range(200) for j in range(3)]
        splits = split_records(records)
        subjects = {name: {r.subject for r in recs} for name, recs in splits.items()}
        self.assertFalse(subjects["train"] & subjects["val"])
        self.assertFalse(subjects["train"] & subjects["test"])
        self.assertFalse(subjects["val"] & subjects["test"])
        self.assertTrue(all(subjects.values()))
        self.assertEqual(split_of("s001"), split_of("s001"))

    def test_cobertura_por_tono(self):
        records = [parse_record({**GOOD, "subject": "a", "fitzpatrick": 1}),
                   parse_record({**GOOD, "subject": "b", "fitzpatrick": 6}),
                   parse_record({**GOOD, "subject": "b", "fitzpatrick": 6, "video": "b/2.mp4"})]
        self.assertEqual(coverage(records)["personas_por_tono"], {1: 1, 6: 1})


class StudentTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        import torch

        cls.torch = torch
        torch.manual_seed(0)

    def test_forma_de_la_salida_y_arranque_centrado(self):
        from student import INPUT_SIZE, LandmarkStudent, parameter_count

        model = LandmarkStudent().eval()
        points, presence = model(self.torch.rand(2, 3, INPUT_SIZE, INPUT_SIZE))
        self.assertEqual(tuple(points.shape), (2, LANDMARK_COUNT, 3))
        self.assertEqual(tuple(presence.shape), (2,))
        self.assertTrue(self.torch.allclose(points[..., :2], self.torch.full_like(points[..., :2], 0.5)))
        # Del orden de MobileNetV3-Small con el cabezal de 478×3 (~3 M).
        self.assertLess(parameter_count(model), 4_000_000)

    def test_un_paso_de_entrenamiento_baja_la_perdida(self):
        from student import INPUT_SIZE, LandmarkStudent
        from train import distill_loss, train_step

        torch = self.torch
        model = LandmarkStudent(width=0.5)
        optimizer = torch.optim.AdamW(model.parameters(), lr=3e-3)
        images = torch.rand(4, 3, INPUT_SIZE, INPUT_SIZE)
        targets = torch.rand(4, LANDMARK_COUNT, 3) * 0.6 + 0.2
        has_face = torch.tensor([1.0, 1.0, 1.0, 0.0])
        first = train_step(model, optimizer, (images, targets, has_face))["total"]
        for _ in range(15):
            last = train_step(model, optimizer, (images, targets, has_face))["total"]
        self.assertLess(last, first)
        # Sin caras: solo la presencia.
        model.eval()
        pred, logit = model(images)
        _, parts = distill_loss(pred, logit, targets, torch.zeros(4))
        self.assertEqual(parts["wing"], 0.0)

    def test_qat_corre_forward_y_backward(self):
        from student import INPUT_SIZE, LandmarkStudent
        from train import prepare_qat

        torch = self.torch
        qat = prepare_qat(LandmarkStudent(width=0.5))
        points, presence = qat(torch.rand(2, 3, INPUT_SIZE, INPUT_SIZE))
        (points.sum() + presence.sum()).backward()
        self.assertEqual(tuple(points.shape), (2, LANDMARK_COUNT, 3))

    def test_muestra_de_entrenamiento_en_coordenadas_del_recorte(self):
        from student import INPUT_SIZE
        from train import make_sample

        rng = np.random.default_rng(7)
        image = rng.integers(0, 255, (480, 640, 3), dtype=np.uint8)
        points = fake_face(rng)[0]
        pixels, target = make_sample(image, points, None, 1.5)
        self.assertEqual(pixels.shape, (3, INPUT_SIZE, INPUT_SIZE))
        self.assertTrue(np.all((target[:468, :2] > 0) & (target[:468, :2] < 1)))
        jittered, _ = make_sample(image, points, np.random.default_rng(8), 1.5)
        self.assertTrue(0.0 <= jittered.min() and jittered.max() <= 1.0)


if __name__ == "__main__":
    unittest.main()

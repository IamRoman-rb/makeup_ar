"""Tests de la referencia de la capa de iris.

Uso:  python -m unittest discover -s tools/makeup
"""

from __future__ import annotations

import re
import sys
import unittest
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "lips"))
from face_shading import hex_to_srgb, srgb_to_oklab  # noqa: E402
from iris_shading import ENGINE_NAMES, iris_mask, iris_r, iris_shading, shade_iris  # noqa: E402
from lip_shading import srgb_to_lin, to_ok  # noqa: E402

ENGINE_CONFIG = Path(__file__).resolve().parents[2] / "packages/makeup_engine/android/src/main/cpp/engine_config.h"
BLUE = srgb_to_oklab(hex_to_srgb("#3A7BD5"))
# Iris castaño medio y esclera.
BROWN_IRIS = np.array([0.36, 0.24, 0.16])


def lab_of(srgb):
    return to_ok(srgb_to_lin(np.asarray(srgb, dtype=float)))


class IrisTest(unittest.TestCase):
    def test_constantes_iguales_a_engine_config(self):
        text = ENGINE_CONFIG.read_text(encoding="utf-8")
        for name, value in ENGINE_NAMES.items():
            match = re.search(rf"constexpr float {name} = ([0-9.]+)f;", text)
            self.assertIsNotNone(match, name)
            self.assertAlmostEqual(float(match.group(1)), value, places=6, msg=name)

    def test_mascara_sin_pupila_ni_fuera_del_iris(self):
        self.assertAlmostEqual(float(iris_mask(0.0)), 0.0)
        self.assertAlmostEqual(float(iris_mask(0.2)), 0.0)
        self.assertAlmostEqual(float(iris_mask(1.2)), 0.0)
        self.assertGreater(float(iris_mask(0.7)), 0.99)

    def test_tine_el_iris_hacia_el_color(self):
        out, a = shade_iris(BROWN_IRIS, np.array(0.7), BLUE, 0.8)
        self.assertAlmostEqual(float(a), 0.8, places=6)
        before = lab_of(BROWN_IRIS)
        after = lab_of(out)
        hue_target = np.arctan2(BLUE[2], BLUE[1])
        hue_after = np.arctan2(after[2], after[1])
        hue_before = np.arctan2(before[2], before[1])
        self.assertLess(abs(hue_after - hue_target), abs(hue_before - hue_target))

    def test_conserva_la_textura(self):
        # Una fibra más oscura queda más oscura después de teñir.
        dark, _ = shade_iris(BROWN_IRIS * 0.6, np.array(0.6), BLUE, 0.9)
        light, _ = shade_iris(BROWN_IRIS, np.array(0.6), BLUE, 0.9)
        self.assertLess(lab_of(dark)[0], lab_of(light)[0])

    def test_conserva_el_reflejo(self):
        catchlight = np.array([0.97, 0.97, 0.97])
        out, a = shade_iris(catchlight, np.array(0.6), BLUE, 1.0)
        self.assertAlmostEqual(float(a), 0.0, places=6)
        np.testing.assert_allclose(out, catchlight, atol=1e-6)

    def test_anillo_limbal_mas_oscuro(self):
        middle, _ = shade_iris(BROWN_IRIS, np.array(0.6), BLUE, 1.0)
        rim, _ = shade_iris(BROWN_IRIS, np.array(0.97), BLUE, 1.0)
        mask_rim = float(iris_mask(0.97))
        self.assertGreater(mask_rim, 0.4)
        # Con la cobertura del borde descontada, el color del borde es más oscuro.
        self.assertLess(lab_of(rim)[0], lab_of(middle)[0])

    def test_pupila_oscura_casi_sin_cambio(self):
        pupil = np.array([0.03, 0.03, 0.035])  # L ~0,05
        out, a = shade_iris(pupil, np.array(0.4), BLUE, 1.0)
        self.assertLess(float(a), 0.01)
        self.assertLess(np.abs(lab_of(out) - lab_of(pupil)).max(), 0.01)

    def test_castano_oscuro_conserva_fibras(self):
        # Iris castaño oscuro a la sombra del párpado (L ~0,15-0,2): se tiñe y
        # una fibra más oscura (0,6×) queda más oscura (antes el piso duro la aplanaba).
        dark_iris = BROWN_IRIS * 0.45
        self.assertGreater(lab_of(dark_iris)[0], 0.14)
        fiber, a = shade_iris(dark_iris * 0.6, np.array(0.6), BLUE, 0.9)
        base, _ = shade_iris(dark_iris, np.array(0.6), BLUE, 0.9)
        self.assertGreater(float(a), 0.5)
        self.assertLess(lab_of(fiber)[0], lab_of(base)[0] - 0.01)
        s = iris_shading(np.array([0.05, 0.1, 0.2, 0.4]))
        self.assertTrue(np.all(np.diff(s) > 0))

    def test_elipse_de_ojo_girado_no_tine_la_esclera(self):
        # Ojo girado ~45°: el iris mide 10 px de alto y 7 de ancho.
        center = np.array([100.0, 50.0])
        ring = center + np.array([[7.0, 0.0], [0.0, -10.0], [-7.0, 0.0], [0.0, 10.0]])
        np.testing.assert_allclose(iris_r(ring, center, ring), 1.0, atol=1e-12)
        # A 9 px del centro en horizontal (esclera): r ~1,29 > 1,1, sin color.
        sclera = iris_r(np.array([109.0, 50.0]), center, ring)
        self.assertGreater(float(sclera), 1.2)
        self.assertEqual(float(iris_mask(sclera)), 0.0)
        # Con un círculo de radio medio (8,5 px) habría quedado dentro.
        self.assertLess(9.0 / 8.5, 1.1)

    def test_borde_minimo_ensancha_la_transicion(self):
        sharp = iris_mask(np.array(1.05))
        soft = iris_mask(np.array(1.05), min_feather=0.3)
        self.assertGreater(float(soft), float(sharp))

    def test_sin_opacidad_no_cambia(self):
        out, a = shade_iris(BROWN_IRIS, np.array(0.6), BLUE, 0.0)
        self.assertEqual(float(a), 0.0)
        np.testing.assert_allclose(out, BROWN_IRIS, atol=1e-12)


if __name__ == "__main__":
    unittest.main()

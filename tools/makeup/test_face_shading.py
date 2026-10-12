"""Tests de la referencia del compositor de capas.

Uso:  python -m unittest discover -s tools/makeup
"""

from __future__ import annotations

import sys
import unittest
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "lips"))
from face_shading import Layer, blend, compose, hex_to_srgb, layer_over, srgb_to_oklab  # noqa: E402
from lip_shading import LipParams, shade, to_ok  # noqa: E402


def lab_of(srgb: np.ndarray) -> np.ndarray:
    return to_ok(np.power(srgb, 2.2))


class LayerOverTest(unittest.TestCase):
    def test_sobre_la_camara_da_el_resultado(self):
        rng = np.random.default_rng(1)
        camera = rng.uniform(0.05, 0.95, size=(500, 3))
        coverage = rng.uniform(0.0, 1.0, 500)
        # Un resultado que se aleja de la cámara en la medida de la cobertura.
        result = camera + (rng.uniform(0, 1, size=(500, 3)) - camera) * coverage[:, None]
        out = blend(camera, *layer_over(result, camera, coverage))
        np.testing.assert_allclose(out, result, atol=1e-12)

    def test_oscurecer_mucho_es_exacto_y_no_negativo(self):
        # Delineado negro con cobertura 0,3: la mezcla en OKLab oscurece más que
        # la mezcla lineal en sRGB; antes el recorte aclaraba el borde.
        camera = np.array([[0.70, 0.55, 0.50]])
        black = np.array([[0.02, 0.02, 0.02]])
        result = camera + (black - camera) * 0.6  # más oscuro que (1 - 0,3)·cámara
        rgb, alpha = layer_over(result, camera, np.array([0.3]))
        self.assertTrue(np.all(rgb >= 0.0))
        np.testing.assert_allclose(blend(camera, rgb, alpha), result, atol=1e-12)

    def test_sin_cobertura_no_cambia_nada(self):
        dst = np.array([[0.3, 0.6, 0.2]])
        camera = np.array([[0.5, 0.4, 0.4]])
        out = blend(dst, *layer_over(camera, camera, np.zeros(1)))
        np.testing.assert_allclose(out, dst)

    def test_labial_encima_de_la_base(self):
        # La base cambia el píxel; el labial con cobertura 1 lo reemplaza y con
        # cobertura parcial deja ver la base, no la cámara.
        camera = np.array([[0.70, 0.50, 0.45]])
        base = np.array([[0.80, 0.62, 0.52]])
        p = LipParams(target_lab=srgb_to_oklab(hex_to_srgb("#B3122D")), opacity=1.0, luma_follow=1.0,
                      lip_lightness=float(lab_of(camera[0])[0]), gloss=0.0, sharpness=2.0, light=1.0)
        full = shade(camera, np.ones(1), np.zeros(1), p)
        np.testing.assert_allclose(blend(base, *layer_over(full, camera, np.ones(1))), full, atol=1e-12)
        half = shade(camera, np.full(1, 0.5), np.zeros(1), p)
        over_base = blend(base, *layer_over(half, camera, np.full(1, 0.5)))
        over_camera = blend(camera, *layer_over(half, camera, np.full(1, 0.5)))
        self.assertGreater(float(over_base.mean()), float(over_camera.mean()))


class ComposeTest(unittest.TestCase):
    camera = np.array([[0.78, 0.60, 0.52], [0.55, 0.40, 0.35]])

    def skin_l(self) -> float:
        return float(lab_of(self.camera).mean(axis=0)[0])

    def test_sin_capas_devuelve_la_camara(self):
        result, coverage = compose(self.camera, [], self.skin_l())
        np.testing.assert_allclose(result, self.camera)
        np.testing.assert_allclose(coverage, 0.0)

    def test_cobertura_combinada(self):
        target = srgb_to_oklab(hex_to_srgb("#E8837A"))
        layers = [Layer(target, 0.5), Layer(target, 0.4)]
        _, coverage = compose(self.camera, layers, self.skin_l())
        np.testing.assert_allclose(coverage, 1 - 0.5 * 0.6)

    def test_capa_plena_es_el_color_bajo_la_luz_del_pixel(self):
        target = srgb_to_oklab(hex_to_srgb("#C98E76"))
        result, _ = compose(self.camera, [Layer(target, 1.0)], self.skin_l())
        out = lab_of(result)
        in_l = lab_of(self.camera)[:, 0]
        # Conserva el sombreado relativo y la media va al color.
        self.assertAlmostEqual(out[0, 0] / out[1, 0], in_l[0] / in_l[1], delta=0.03)
        self.assertAlmostEqual(float(out[:, 0].mean()), target[0], delta=0.03)

    def test_el_orden_importa(self):
        # Lo último aplicado domina.
        red = srgb_to_oklab(hex_to_srgb("#C0392B"))
        blue = srgb_to_oklab(hex_to_srgb("#2E5FA8"))
        red_last, _ = compose(self.camera, [Layer(blue, 0.8), Layer(red, 0.8)], self.skin_l())
        blue_last, _ = compose(self.camera, [Layer(red, 0.8), Layer(blue, 0.8)], self.skin_l())
        self.assertGreater(red_last[0, 0], blue_last[0, 0])
        self.assertGreater(blue_last[0, 2], red_last[0, 2])

    def test_brillo_solo_con_luz(self):
        target = srgb_to_oklab(hex_to_srgb("#F6E3C2"))
        lit_px = np.array([[0.85, 0.70, 0.62]])
        dark_px = np.array([[0.45, 0.36, 0.32]])  # ~0,6 de la L de referencia
        ref = float(lab_of(lit_px)[0, 0])
        for camera, expect_shine in ((lit_px, True), (dark_px, False)):
            with_shine, _ = compose(camera, [Layer(target, 0.6, shine=0.3)], ref)
            without, _ = compose(camera, [Layer(target, 0.6)], ref)
            gain = float((with_shine - without).mean())
            if expect_shine:
                self.assertGreater(gain, 0.02)
            else:
                self.assertAlmostEqual(gain, 0.0, places=9)

    def test_salida_en_rango(self):
        rng = np.random.default_rng(4)
        camera = rng.uniform(0, 1, size=(1000, 3))
        layers = [Layer(srgb_to_oklab(rng.uniform(0, 1, 3)), rng.uniform(0, 1, 1000), shine=0.4) for _ in range(4)]
        result, coverage = compose(camera, layers, 0.6)
        self.assertTrue(np.all(result >= 0) and np.all(result <= 1))
        self.assertTrue(np.all(coverage >= 0) and np.all(coverage <= 1))


if __name__ == "__main__":
    unittest.main()

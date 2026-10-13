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
from face_shading import (Layer, blend, compose, freckle_alpha, freckle_lab, glitter_sparkle, hash12,  # noqa: E402
                          hex_to_srgb, lash_alpha, layer_over, srgb_to_oklab)
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


class LashTest(unittest.TestCase):
    params = (30.0, 0.8, 0.25, 0.08)

    def strip(self, height: float, lower: bool = False) -> np.ndarray:
        """Una fila a lo largo de la línea (s de 0 a 1) a una altura fija."""
        s = np.linspace(0.0, 1.0, 3000)
        none = np.ones_like(s)
        if lower:
            return np.stack([none * 0, none, s, np.full_like(s, height)], axis=-1)
        return np.stack([s, np.full_like(s, height), none * 0, none], axis=-1)

    def test_hash_en_rango_y_determinista(self):
        p = np.random.default_rng(0).uniform(-500, 500, size=(1000, 2))
        values = hash12(p)
        self.assertTrue(np.all((values >= 0) & (values < 1)))
        np.testing.assert_array_equal(values, hash12(p))

    def test_hebras_separadas_a_media_altura(self):
        row = lash_alpha(self.strip(0.3), 1.0, 0.5, self.params, 0.0, aa=(np.full(3000, 0.02), np.full(3000, 0.02)))
        inked = row > 0.5
        starts = np.count_nonzero(inked[1:] & ~inked[:-1])
        self.assertGreater(starts, 15)       # la mayoría de las ~30 hebras
        self.assertLess(inked.mean(), 0.6)   # con espacio entre hebras

    def test_sin_pestanas_en_altura_1_ni_sobre_el_largo(self):
        aa = (np.full(3000, 0.02), np.full(3000, 0.02))
        self.assertEqual(float(lash_alpha(self.strip(1.0), 1.0, 0.5, self.params, 0.7, aa=aa).max()), 0.0)
        short = (30.0, 0.3, 0.25, 0.08)
        self.assertEqual(float(lash_alpha(self.strip(0.5), 1.0, 0.0, short, 0.0, aa=aa).max()), 0.0)

    def test_raiz_oscura_con_volumen(self):
        aa = (np.full(3000, 0.02), np.full(3000, 0.02))
        root = lash_alpha(self.strip(0.0), 1.0, 0.0, self.params, 0.7, aa=aa)
        self.assertGreater(float(np.median(root[300:2700])), 0.65)

    def test_inferiores_mas_tenues(self):
        aa = (np.full(3000, 0.02), np.full(3000, 0.02))
        upper = lash_alpha(self.strip(0.2), 1.0, 0.45, self.params, 0.0, aa=aa)
        lower = lash_alpha(self.strip(0.2, lower=True), 1.0, 0.45, self.params, 0.0, aa=aa)
        self.assertLessEqual(float(lower.max()), 0.45 + 1e-9)
        self.assertGreater(float(upper.max()), 0.9)


class EffectsTest(unittest.TestCase):
    def grid(self, n: int = 400) -> np.ndarray:
        u, v = np.meshgrid(np.linspace(0.0, 0.5, n), np.linspace(0.3, 0.7, n))
        return np.stack([u, v], axis=-1)

    def test_densidad_de_pecas(self):
        uv = self.grid()
        sparse = freckle_alpha(uv, 0.12, aa=0.05)
        dense = freckle_alpha(uv, 0.42, aa=0.05)
        self.assertGreater(float((dense > 0.5).mean()), 2.0 * float((sparse > 0.5).mean()))
        self.assertLess(float((dense > 0.5).mean()), 0.2)  # puntos, no manchas
        self.assertEqual(float(freckle_alpha(uv, 0.0, aa=0.05).max()), 0.0)

    def test_color_de_pecas_mas_oscuro_y_calido(self):
        skin = srgb_to_oklab(np.array([0.85, 0.66, 0.55]))
        freckle = freckle_lab(skin)
        self.assertLess(freckle[0], skin[0])
        self.assertGreater(freckle[2], skin[2])

    def test_glitter_por_densidad_y_cambia_con_el_tiempo(self):
        uv = self.grid()
        a = glitter_sparkle(uv, 0.1, tick=0)
        b = glitter_sparkle(uv, 0.1, tick=1)
        self.assertAlmostEqual(float(a.mean()), 0.1, delta=0.03)
        self.assertGreater(float(np.abs(a - b).mean()), 0.05)


class SceneLightTest(unittest.TestCase):
    """Misma matemática que scene_light.cpp (tests de host: scene_light_test.cpp)."""

    def test_gris_neutro_y_calido_calienta(self):
        from face_shading import adapt_oklab, scene_gain
        gray = np.full((16, 16, 3), 128 / 255)
        np.testing.assert_allclose(scene_gain(gray, 0.5, 0.85, 1.18), 1.0, atol=1e-6)
        warm = np.broadcast_to(np.array([200, 160, 120]) / 255, (16, 16, 3))
        gain = scene_gain(warm, 0.5, 0.85, 1.18)
        self.assertGreater(gain[0], 1.0)
        self.assertLess(gain[2], 1.0)
        self.assertAlmostEqual(float(gain @ np.array([0.2126, 0.7152, 0.0722])), 1.0, places=6)
        red = srgb_to_oklab(np.array([0.70, 0.07, 0.18]))
        self.assertGreater(adapt_oklab(red, gain)[2], red[2] + 0.01)

    def test_sin_la_cara_y_sin_escena_suficiente(self):
        from face_shading import scene_gain
        scene = np.full((16, 16, 3), 128 / 255)
        scene[4:12, 4:12] = np.array([220, 160, 130]) / 255
        face = np.zeros((16, 16), dtype=bool)
        face[4:12, 4:12] = True
        self.assertGreater(scene_gain(scene, 0.5, 0.85, 1.18)[0], 1.02)
        np.testing.assert_allclose(scene_gain(scene, 0.5, 0.85, 1.18, include=~face), 1.0, atol=1e-3)
        # La cara tapa todo menos una fila: no alcanza para medir.
        one_row = np.zeros((16, 16), dtype=bool)
        one_row[15] = True
        self.assertIsNone(scene_gain(scene, 0.5, 0.85, 1.18, include=one_row))


if __name__ == "__main__":
    unittest.main()

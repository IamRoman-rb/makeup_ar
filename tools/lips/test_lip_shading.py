"""Tests de la referencia del sombreado de labios.

Uso:  python -m unittest discover -s tools/lips
"""

from __future__ import annotations

import sys
import unittest
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
from lip_shading import LipParams, from_ok, hex_to_srgb, oklab_to_linear_in_gamut, shade, srgb_to_oklab, to_ok  # noqa: E402


def hue(lab: np.ndarray) -> float:
    return float(np.arctan2(lab[2], lab[1]))


class InGamutTest(unittest.TestCase):
    def test_en_gamut_no_cambia(self):
        rgb = np.array([0.3, 0.2, 0.1])
        np.testing.assert_allclose(oklab_to_linear_in_gamut(to_ok(rgb)), rgb, atol=1e-6)

    def test_fuera_de_gamut_entra_con_l_y_tono_fijos(self):
        rng = np.random.default_rng(7)
        for _ in range(500):
            lightness = rng.uniform(0.05, 0.98)
            chroma = rng.uniform(0.2, 0.4)
            angle = rng.uniform(-np.pi, np.pi)
            lab = np.array([lightness, chroma * np.cos(angle), chroma * np.sin(angle)])
            out = oklab_to_linear_in_gamut(lab)
            self.assertTrue(np.all(out >= 0) and np.all(out <= 1), out)
            out_lab = to_ok(out)
            self.assertLess(abs(out_lab[0] - lightness), 0.01)
            if np.hypot(out_lab[1], out_lab[2]) > 0.02:
                delta = np.angle(np.exp(1j * (hue(out_lab) - angle)))
                self.assertLess(abs(delta), 0.05)

    def test_croma_cerca_del_maximo(self):
        # La búsqueda deja la croma a menos de 1/2^6 del borde del gamut.
        lab = np.array([0.5, 0.3, 0.0])
        out_chroma = np.hypot(*to_ok(oklab_to_linear_in_gamut(lab))[1:])
        more = np.array([0.5, out_chroma * 1.04, 0.0])
        self.assertFalse(np.all((from_ok(more) >= 0) & (from_ok(more) <= 1)))

    def test_mejor_tono_que_el_clamp_por_canal(self):
        # Rojo intenso en una sombra profunda: el clamp por canal lo desvía.
        target = srgb_to_oklab(hex_to_srgb("#B3122D"))
        lab = np.array([0.18, target[1], target[2]])
        clipped = to_ok(oklab_to_linear_in_gamut(lab))
        clamped = to_ok(np.clip(from_ok(lab), 0, 1))
        target_hue = hue(target)
        self.assertLess(abs(hue(clipped) - target_hue), 0.02)
        self.assertGreater(abs(hue(clamped) - target_hue), 0.05)


class ShadeTest(unittest.TestCase):
    def params(self, **overrides) -> LipParams:
        values = dict(target_lab=srgb_to_oklab(hex_to_srgb("#B3122D")), opacity=1.0, luma_follow=0.0,
                      lip_lightness=0.55, gloss=0.0, sharpness=2.0, light=1.0)
        values.update(overrides)
        return LipParams(**values)

    def test_fuera_de_la_mascara_devuelve_la_camara(self):
        camera = np.array([[0.7, 0.5, 0.45]])
        out = shade(camera, np.array([0.0]), np.array([1.0]), self.params(gloss=1.0))
        np.testing.assert_allclose(out, camera)

    def test_croma_del_color_y_textura_del_labio(self):
        # Dos píxeles del mismo labio con distinta L: la diferencia de L se
        # conserva (textura) y la croma pasa a ser la del color.
        camera = np.array([[0.75, 0.50, 0.48], [0.60, 0.38, 0.36]])
        p = self.params()
        out_lab = to_ok(np.power(shade(camera, np.ones(2), np.zeros(2), p), 2.2))
        in_lab = srgb_to_oklab(camera)
        np.testing.assert_allclose(out_lab[0, 0] - out_lab[1, 0], in_lab[0, 0] - in_lab[1, 0], atol=0.02)
        for row in out_lab:
            self.assertLess(abs(hue(row) - hue(p.target_lab)), 0.15)

    def test_luma_follow_corre_la_media_hacia_el_color(self):
        camera = np.array([[0.75, 0.50, 0.48]])
        lip_l = float(srgb_to_oklab(camera[0])[0])
        dark = srgb_to_oklab(hex_to_srgb("#3B0A1E"))
        out = shade(camera, np.ones(1), np.zeros(1), self.params(target_lab=dark, luma_follow=1.0,
                                                                lip_lightness=lip_l))
        self.assertAlmostEqual(float(to_ok(np.power(out[0], 2.2))[0]), dark[0], delta=0.03)

    def test_brillo_solo_donde_hay_mapa_y_mascara(self):
        camera = np.array([[0.6, 0.4, 0.4], [0.6, 0.4, 0.4]])
        p = self.params(gloss=0.8)
        out = shade(camera, np.ones(2), np.array([1.0, 0.0]), p)
        self.assertGreater(out[0].mean(), out[1].mean() + 0.05)
        matte = shade(camera, np.ones(2), np.array([1.0, 0.0]), self.params(gloss=0.0))
        np.testing.assert_allclose(matte[0], matte[1])

    def test_salida_siempre_en_rango(self):
        rng = np.random.default_rng(3)
        camera = rng.uniform(0, 1, size=(2000, 3))
        out = shade(camera, rng.uniform(0, 1, 2000), rng.uniform(0, 1, 2000),
                    self.params(gloss=1.0, luma_follow=1.0), sparkle=rng.uniform(0, 1, 2000))
        self.assertTrue(np.all(out >= 0) and np.all(out <= 1))


if __name__ == "__main__":
    unittest.main()

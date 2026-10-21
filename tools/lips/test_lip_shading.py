"""Tests de la referencia del sombreado de labios.

Uso:  python -m unittest discover -s tools/lips
"""

from __future__ import annotations

import sys
import unittest
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
from lip_shading import LipEdge, LipLiner, LipOcclusion, edge_strength, refined_mask, LipParams, from_ok, liner_alpha, hex_to_srgb, oklab_to_linear_in_gamut, occlusion_visibility, shade, srgb_to_oklab, to_ok  # noqa: E402
from sample_region_reference import srgb_to_lin  # noqa: E402


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

    def test_sombreado_del_labio_escala_l_y_croma(self):
        # Con lumaFollow 1, el labial bajo la luz de cada píxel es el color de
        # la receta escalado por L_píxel / L_labio: la sombra queda más oscura
        # y menos saturada, con el mismo tono (no un color plano).
        camera = np.array([[0.75, 0.50, 0.48], [0.45, 0.28, 0.27]])
        in_l = srgb_to_oklab(camera)[:, 0]
        lip_l = float(in_l.mean())
        # Color poco saturado: así ningún píxel sale de gamut (ahí baja la croma).
        p = self.params(luma_follow=1.0, lip_lightness=lip_l, target_lab=srgb_to_oklab(hex_to_srgb("#B9786E")))
        out_lab = to_ok(np.power(shade(camera, np.ones(2), np.zeros(2), p), 2.2))
        chroma = np.hypot(out_lab[:, 1], out_lab[:, 2])
        self.assertAlmostEqual(out_lab[0, 0] / out_lab[1, 0], in_l[0] / in_l[1], delta=0.05)
        self.assertAlmostEqual(chroma[0] / chroma[1], in_l[0] / in_l[1], delta=0.1)
        self.assertAlmostEqual(float(out_lab[:, 0].mean()), p.target_lab[0], delta=0.03)
        for row in out_lab:
            self.assertLess(abs(hue(row) - hue(p.target_lab)), 0.1)

    def test_brillo_no_aparece_en_las_sombras(self):
        lit = np.array([[0.70, 0.45, 0.43]])
        lip_l = float(srgb_to_oklab(lit[0])[0])
        dark = np.array([[0.35, 0.22, 0.21]])  # pliegue: ~0,6 de la L del labio
        on = self.params(gloss=0.8, lip_lightness=lip_l)
        off = self.params(gloss=0.0, lip_lightness=lip_l)
        gain_lit = shade(lit, np.ones(1), np.ones(1), on) - shade(lit, np.ones(1), np.ones(1), off)
        gain_dark = shade(dark, np.ones(1), np.ones(1), on) - shade(dark, np.ones(1), np.ones(1), off)
        self.assertGreater(float(gain_lit.mean()), 0.05)
        np.testing.assert_allclose(gain_dark, 0.0, atol=1e-9)

    def test_delineado_sobre_el_borde_y_mate(self):
        liner = LipLiner(target_lab=srgb_to_oklab(hex_to_srgb("#5A0A16")), amount=0.8)
        distance = np.array([0.0, 0.25, 0.6, 1.0])
        alpha = liner_alpha(distance, liner, aa=0.05)
        self.assertAlmostEqual(float(alpha[0]), 0.8)
        self.assertAlmostEqual(float(alpha[3]), 0.0)
        self.assertTrue(np.all(np.diff(alpha) <= 0))
        self.assertTrue(np.all(liner_alpha(distance, LipLiner(liner.target_lab, 0.0), 0.05) == 0))
        # Afuera del labial (máscara 0) el delineado igual pinta; adentro tapa el brillo.
        camera = np.array([[0.75, 0.55, 0.5], [0.7, 0.45, 0.43]])
        p = self.params(gloss=0.8, lip_lightness=0.6)
        out = shade(camera, np.array([0.0, 1.0]), np.ones(2), p, liner=np.array([0.8, 0.8]), liner_lab=liner.target_lab)
        self.assertLess(float(out[0].mean()), float(camera[0].mean()) - 0.1)
        bright = shade(camera, np.ones(2), np.ones(2), p)
        lined = shade(camera, np.ones(2), np.ones(2), p, liner=np.full(2, 0.8), liner_lab=liner.target_lab)
        self.assertLess(float(lined[1].mean()), float(bright[1].mean()))

    def test_oclusion_saca_el_labial_de_la_mano(self):
        skin_rgb = np.array([0.82, 0.64, 0.56])
        lip_rgb = np.array([0.72, 0.42, 0.42])

        def chroma(rgb):
            lab = srgb_to_oklab(rgb)
            return lab[1:] / lab[0]

        skin, lip = chroma(skin_rgb), chroma(lip_rgb)
        axis = (lip - skin) / np.sum((lip - skin) ** 2)
        camera = np.stack([skin_rgb, lip_rgb, skin_rgb * 0.6])  # mano, labio, mano en sombra
        on = LipOcclusion(gate=1.0, skin=skin, axis=axis)
        visible = occlusion_visibility(camera, on)
        np.testing.assert_allclose(visible, [0.0, 1.0, 0.0], atol=1e-6)
        # Con la compuerta a medias, la mano queda con medio labial.
        half = occlusion_visibility(camera, LipOcclusion(gate=0.5, skin=skin, axis=axis))
        self.assertAlmostEqual(float(half[0]), 0.5)
        # Sin compuerta, nada cambia.
        np.testing.assert_array_equal(occlusion_visibility(camera, LipOcclusion(0.0, skin, axis)), 1.0)
        p = self.params(gloss=0.8)
        liner_lab = srgb_to_oklab(hex_to_srgb("#5A0A16"))
        out = shade(camera, np.ones(3), np.ones(3), p, liner=np.full(3, 0.8), liner_lab=liner_lab, occlusion=on)
        np.testing.assert_allclose(out[0], camera[0], atol=1e-9)  # la mano queda como está
        np.testing.assert_allclose(out[2], camera[2], atol=1e-9)
        free = shade(camera, np.ones(3), np.ones(3), p, liner=np.full(3, 0.8), liner_lab=liner_lab)
        np.testing.assert_allclose(out[1], free[1], atol=1e-9)  # el labio, igual que sin mano

    def _edge(self):
        skin_rgb = np.array([0.82, 0.64, 0.56])
        lip_rgb = np.array([0.72, 0.42, 0.42])
        skin_c = to_ok(srgb_to_lin(skin_rgb))
        lip_c = to_ok(srgb_to_lin(lip_rgb))
        skin = skin_c[1:] / skin_c[0]
        d = lip_c[1:] / lip_c[0] - skin
        return skin_rgb, lip_rgb, LipEdge(strength=1.0, skin=skin, axis=d / np.dot(d, d))

    def test_borde_retira_el_labial_de_la_piel_y_lo_extiende_al_labio(self):
        skin_rgb, lip_rgb, edge = self._edge()
        lip_l = float(to_ok(srgb_to_lin(lip_rgb))[0])
        camera = np.stack([skin_rgb, lip_rgb])
        # Sobre el contorno: la malla se pasó sobre la piel (máscara 0,7) y no
        # llegó a un borde de labio (máscara 0).
        refined = refined_mask(camera, np.array([0.7, 0.0]), np.array([0.05, 0.05]), edge, lip_l)
        self.assertLess(float(refined[0]), 0.1)
        self.assertGreater(float(refined[1]), 0.85)
        # Lejos del contorno (distancia >= EDGE_BAND) la máscara no cambia.
        far = refined_mask(camera, np.array([0.7, 0.0]), np.array([0.8, 0.8]), edge, lip_l)
        np.testing.assert_allclose(far, [0.7, 0.0])

    def test_borde_no_crece_en_lo_oscuro_ni_sin_contraste(self):
        skin_rgb, lip_rgb, edge = self._edge()
        lip_l = float(to_ok(srgb_to_lin(lip_rgb))[0])
        # La boca abierta junto a la comisura: oscura y rojiza.
        mouth = np.array([[0.25, 0.08, 0.08]])
        self.assertAlmostEqual(float(refined_mask(mouth, np.array([0.0]), np.array([0.05]), edge, lip_l)[0]), 0.0)
        # Sin borde (strength 0) es exactamente la máscara.
        off = LipEdge(strength=0.0, skin=edge.skin, axis=edge.axis)
        camera = np.stack([skin_rgb, lip_rgb])
        np.testing.assert_array_equal(refined_mask(camera, np.array([0.7, 0.0]), np.array([0.05, 0.05]), off, lip_l),
                                      [0.7, 0.0])

    def test_borde_respeta_los_reflejos_y_el_eje_cero(self):
        skin_rgb, lip_rgb, edge = self._edge()
        lip_l = float(to_ok(srgb_to_lin(lip_rgb))[0])
        # Reflejo en el borde: croma lavada (parece piel), no pierde el labial.
        burned = np.array([[1.0, 0.97, 0.95]])
        self.assertAlmostEqual(float(refined_mask(burned, np.array([0.8]), np.array([0.05]), edge, lip_l)[0]), 0.8)
        # Sin eje la máscara queda (la CPU manda 0).
        zero = LipEdge(strength=1.0, skin=edge.skin, axis=np.zeros(2))
        camera = np.stack([skin_rgb, lip_rgb])
        np.testing.assert_array_equal(refined_mask(camera, np.array([0.7, 0.0]), np.array([0.05, 0.05]), zero, lip_l),
                                      [0.7, 0.0])

    def test_fuerza_del_borde_sube_con_el_contraste(self):
        self.assertEqual(edge_strength(np.zeros(2)), 0.0)
        self.assertEqual(edge_strength(np.array([10.0, 0.0]), enabled=False), 0.0)
        # |labio − piel| = 1 / |eje|: 0,02 (poco) no actúa, 0,045 a medias, 0,1 pleno.
        self.assertEqual(edge_strength(np.array([50.0, 0.0])), 0.0)
        self.assertAlmostEqual(edge_strength(np.array([1 / 0.045, 0.0])), 0.5, places=6)
        self.assertEqual(edge_strength(np.array([10.0, 0.0])), 1.0)

    def test_borde_en_shade_pinta_el_labio_fuera_de_la_malla(self):
        skin_rgb, lip_rgb, edge = self._edge()
        p = self.params()
        camera = np.stack([skin_rgb, lip_rgb])
        plain = shade(camera, np.array([0.7, 0.0]), np.zeros(2), p, distance=np.array([0.05, 0.05]))
        refined = shade(camera, np.array([0.7, 0.0]), np.zeros(2), p, edge=edge, distance=np.array([0.05, 0.05]))
        # La piel vuelve a ser la cámara; el labio fuera de la malla se pinta.
        self.assertGreater(float(np.abs(plain[0] - camera[0]).max()), 0.05)
        np.testing.assert_allclose(refined[0], camera[0], atol=0.03)
        np.testing.assert_allclose(plain[1], camera[1], atol=1e-9)
        self.assertGreater(float(np.abs(refined[1] - camera[1]).max()), 0.05)

    def test_oclusion_ignora_la_luz_quemada(self):
        # Labio quemado por una ventana: rojo saturado y verde/azul altos, la
        # croma lavada se parece a la de la piel.
        skin_c = to_ok(srgb_to_lin(np.array([0.85, 0.66, 0.56])))
        lip_c = to_ok(srgb_to_lin(np.array([0.70, 0.35, 0.38])))
        skin = skin_c[1:] / skin_c[0]
        d = lip_c[1:] / lip_c[0] - skin
        on = LipOcclusion(gate=1.0, skin=skin, axis=d / np.dot(d, d))
        burned = np.array([[1.0, 0.82, 0.80]])
        hand = np.array([[0.85, 0.66, 0.56]])
        self.assertAlmostEqual(float(occlusion_visibility(burned, on)[0]), 1.0)
        self.assertAlmostEqual(float(occlusion_visibility(hand, on)[0]), 0.0)

    def test_salida_siempre_en_rango(self):
        rng = np.random.default_rng(3)
        camera = rng.uniform(0, 1, size=(2000, 3))
        out = shade(camera, rng.uniform(0, 1, 2000), rng.uniform(0, 1, 2000),
                    self.params(gloss=1.0, luma_follow=1.0), sparkle=rng.uniform(0, 1, 2000))
        self.assertTrue(np.all(out >= 0) and np.all(out <= 1))


if __name__ == "__main__":
    unittest.main()

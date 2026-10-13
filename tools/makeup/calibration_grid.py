"""Grilla de calibración del maquillaje completo (P5): 5 tonos de piel × presets.

Pinta una cara sintética frontal directamente en el espacio UV de la malla
canónica (las UV son casi una proyección frontal) y le aplica cada preset de
lib/features/ar/domain/recipe_presets.dart con la misma matemática y los mismos
mapas que el motor:
  - pasada de cara (base, contorno, rubor, iluminador): face_shading.compose
    con los mapas de tools/uv_masks/gen_face_maps.py;
  - pasada de ojos (sombras y delineado): ídem con los mapas de ojos;
  - labios: tools/lips/lip_shading.shade con el mapa de gen_lips_maps.py;
compuestas en ese orden con layer_over / blend, como el blending del motor.
Sirve para ver que cada región cae en su lugar y para ajustar opacidades y
valores por defecto en los 5 tonos. Los destellos del shimmer no se simulan.

Salida: docs/ar_engine/img/face_calibration.png
  fila 0      muestra del color de labios de cada preset (columna 0: sin maquillaje)
  filas 1..5  piel muy clara -> profunda

Uso:  python tools/makeup/calibration_grid.py
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
for sub in ("tools/makeup", "tools/lips", "tools/uv_masks"):
    sys.path.insert(0, str(ROOT / sub))
import gen_face_maps as fm  # noqa: E402
import gen_lips_maps as lm  # noqa: E402
from face_shading import (Layer, blend, compose, freckle_alpha, freckle_lab, glitter_sparkle,  # noqa: E402
                          lash_alpha, layer_over, sheen_gain)
from lip_shading import (LipLiner, LipParams, from_ok, hex_to_srgb, lin_to_srgb, liner_alpha, shade,  # noqa: E402
                         srgb_to_oklab, to_ok)

PRESETS_DART = ROOT / "lib/features/ar/domain/recipe_presets.dart"
ENGINE_CONFIG = ROOT / "packages/makeup_engine/android/src/main/cpp/engine_config.h"
OUTPUT = ROOT / "docs/ar_engine/img/face_calibration.png"

CELL_W, CELL_H = 200, 220
U_RANGE = (0.04, 0.96)
V_RANGE = (0.08, 0.90)
SWATCH_H = 30
GAP = 4

# Mismos tonos que tools/lips/calibration_grid.py: (L, croma, tono°) OKLab.
SKIN_TONES = [(0.86, 0.045, 65.0), (0.78, 0.060, 60.0), (0.68, 0.070, 58.0), (0.55, 0.070, 55.0), (0.40, 0.050, 50.0)]
CHEEK_PLACEMENTS = {"apple": 0, "high": 1, "low": 2}
EYE_REGION_CHANNEL = {"lid": ("A", 0), "crease": ("A", 1), "outer_v": ("A", 2), "inner_corner": ("A", 3),
                      "brow_bone": ("B", 0)}


def lch(lightness: float, chroma: float, hue_deg: float) -> np.ndarray:
    h = np.radians(hue_deg)
    return np.array([lightness, chroma * np.cos(h), chroma * np.sin(h)])


def engine_constants() -> dict[str, float]:
    text = ENGINE_CONFIG.read_text(encoding="utf-8")
    values = {m.group(1): float(m.group(2)) for m in re.finditer(r"constexpr float (k\w+) = ([0-9.]+)f;", text)}
    lash = re.search(r"kLashColor\[3\] = \{([0-9.]+)f, ([0-9.]+)f, ([0-9.]+)f\}", text)
    values["kLashColor"] = tuple(float(lash.group(i)) for i in (1, 2, 3))
    return values


def dart_literal_to_json(text: str):
    """Convierte el literal de mapa Dart de un preset a JSON (comillas simples)."""
    return json.loads(re.sub(r",(\s*[}\]])", r"\1", text.replace("'", '"')))


def presets() -> list[dict]:
    text = PRESETS_DART.read_text(encoding="utf-8")
    out = []
    for match in re.finditer(r"json: (\{.*?\n      \}),\n    \),", text, re.S):
        body = re.sub(r"'schema': kMakeupRecipeSchemaV2,", "", match.group(1))
        out.append(dart_literal_to_json(body))
    return out


def sample(texture: np.ndarray, rect, u: np.ndarray, v: np.ndarray) -> np.ndarray:
    """Bilineal con CLAMP_TO_EDGE, como GL. texture (H, W, C) uint8 -> [0,1]."""
    height, width, _ = texture.shape
    x = np.clip((u - rect[0]) / rect[2] * width - 0.5, 0, width - 1)
    y = np.clip((v - rect[1]) / rect[3] * height - 0.5, 0, height - 1)
    x0, y0 = np.floor(x).astype(int), np.floor(y).astype(int)
    x1, y1 = np.minimum(x0 + 1, width - 1), np.minimum(y0 + 1, height - 1)
    fx, fy = (x - x0)[..., None], (y - y0)[..., None]
    t = texture.astype(float) / 255.0
    top = t[y0, x0] * (1 - fx) + t[y0, x1] * fx
    bottom = t[y1, x0] * (1 - fx) + t[y1, x1] * fx
    return top * (1 - fy) + bottom * fy


class Maps:
    """Mapas del motor muestreados sobre la grilla UV de una celda."""

    def __init__(self):
        geo = fm.Geometry(json.loads(fm.PARAMS.read_text(encoding="utf-8")))
        face_params = json.loads(fm.PARAMS.read_text(encoding="utf-8"))
        rgb, face_rect, self.cheeks = fm.build_face(face_params, geo)
        a8, b8, eye_rect, *_, c8 = fm.build_eyes(face_params, geo)
        lips_rg8, lips_rect, *_ = lm.build(json.loads(lm.PARAMS.read_text(encoding="utf-8")))

        us = np.linspace(U_RANGE[0], U_RANGE[1], CELL_W)
        vs = np.linspace(V_RANGE[1], V_RANGE[0], CELL_H)  # fila 0 arriba (frente)
        self.u, self.v = np.meshgrid(us, vs)
        self.mirrored = np.minimum(self.u, 1.0 - self.u)
        face = sample(rgb, face_rect, self.mirrored, self.v)
        self.skin, self.contour, self.highlight, self.cheeks_nose = (face[..., i] for i in range(4))
        # Coordenadas del mapa de media cara (las de los efectos de face.frag).
        self.face_map_uv = np.stack([(self.mirrored - face_rect[0]) / face_rect[2],
                                     (self.v - face_rect[1]) / face_rect[3]], axis=-1)
        self.eye_a = sample(a8, eye_rect, self.mirrored, self.v)
        self.eye_b = sample(b8, eye_rect, self.mirrored, self.v)
        self.eye_c = sample(c8, eye_rect, self.mirrored, self.v)
        self.side = (self.u > 0.5).astype(float)
        lips = sample(lips_rg8, lips_rect, self.u, self.v)
        self.lips_mask, self.lips_gloss, self.lips_liner = lips[..., 0], lips[..., 1], lips[..., 2]

        points = np.stack([self.mirrored.ravel(), self.v.ravel()], axis=1)
        shape = self.u.shape
        self.oval = lm.inside_polygon(np.stack([self.u.ravel(), self.v.ravel()], axis=1), geo.oval).reshape(shape)
        self.eye = lm.inside_polygon(points, geo.eye_opening).reshape(shape)
        self.brow = lm.inside_polygon(points, geo.brow).reshape(shape)
        full = np.stack([self.u.ravel(), self.v.ravel()], axis=1)
        self.lips = (lm.inside_polygon(full, geo.lips_outer) & ~lm.inside_polygon(full, geo.lips_inner)).reshape(shape)
        iris_center = geo.eye_upper[[3, 4, 5]].mean(axis=0) * 0.5 + geo.eye_lower[[3, 4, 5]].mean(axis=0) * 0.5
        self.iris = np.hypot(self.mirrored - iris_center[0], self.v - iris_center[1]) < 0.016

    def cheek(self, placement: int, spread: float, k: dict[str, float]) -> np.ndarray:
        cu, cv, su, sv, angle = self.cheeks[placement]
        scale = k["kCheekSpreadScaleMin"] + (k["kCheekSpreadScaleMax"] - k["kCheekSpreadScaleMin"]) * spread
        du, dv = self.mirrored - cu, self.v - cv
        c, s = np.cos(angle), np.sin(angle)
        gu = (c * du + s * dv) / (su * scale)
        gv = (-s * du + c * dv) / (sv * scale)
        return np.exp(-0.5 * (gu * gu + gv * gv))


def bare_face(maps: Maps, skin_lch) -> np.ndarray:
    """Cámara sintética (sRGB): piel con luz frontal, ojos, cejas y labios."""
    skin_l, skin_c, skin_h = skin_lch
    u, v = maps.u, maps.v
    light = 1.0 - 0.30 * ((u - 0.5) / 0.5) ** 2 - 0.25 * np.clip(0.3 - v, 0, None)
    light += 0.05 * np.exp(-(((u - 0.5) / 0.02) ** 2 + ((v - 0.52) / 0.06) ** 2))  # puente de la nariz
    rng = np.random.default_rng(3)
    light += rng.normal(0, 0.006, size=u.shape)
    lab = np.broadcast_to(lch(skin_l, skin_c, skin_h), u.shape + (3,)).copy()
    lab[maps.brow] = lch(min(0.32, skin_l - 0.25), 0.03, 60)
    lab[maps.lips] = lch(skin_l - 0.07, 0.075, 22)
    lab[maps.eye] = lch(0.88, 0.01, 90)
    lab[maps.eye & maps.iris] = lch(0.3, 0.04, 60)
    lab = lab * light[..., None]
    rgb = np.clip(from_ok(lab), 0, 1)
    background = np.array([0.18, 0.18, 0.2])
    rgb = np.where(maps.oval[..., None], rgb, background)
    return lin_to_srgb(rgb)


def apply_recipe(camera: np.ndarray, maps: Maps, recipe: dict, k: dict[str, float]) -> np.ndarray:
    lab = to_ok(np.power(camera, 2.2))
    skin_ref = float(np.median(lab[(maps.skin > 0.9) & (maps.cheek(0, 0.5, k) > 0.5), 0]))
    lip_ref = float(np.median(lab[maps.lips_mask > 0.9, 0]))
    out = camera.copy()

    def color(hex_value: str) -> np.ndarray:
        return srgb_to_oklab(hex_to_srgb(hex_value))

    # Pasada de cara: base, contorno, rubor, iluminador.
    layers = []
    skin = recipe.get("skin", {})
    if "foundation" in skin:
        layers.append(Layer(color(skin["foundation"]["color"]), maps.skin * skin["foundation"]["coverage"]))
    if "contour" in skin:
        layers.append(Layer(color(skin["contour"]["color"]), maps.contour * skin["contour"]["opacity"]))
    cheeks = recipe.get("cheeks")
    if cheeks:
        gauss = maps.cheek(CHEEK_PLACEMENTS[cheeks.get("placement", "apple")], cheeks.get("spread", 0.5), k)
        layers.append(Layer(color(cheeks["color"]), maps.skin * gauss * cheeks["opacity"]))
    if "highlight" in skin:
        layers.append(Layer(color(skin["highlight"]["color"]), maps.highlight * skin["highlight"]["opacity"],
                            luma_follow=k["kHighlightLumaFollow"], shine=k["kHighlightShine"]))
    # Efectos de cara (variante EFFECTS): pecas como capa (después de la base),
    # sheen y glitter como brillo. Los de ojos y labios no se simulan acá.
    shine_extra = np.zeros(camera.shape[:2])
    gain = np.ones(camera.shape[:2])
    camera_lab = to_ok(np.power(camera, 2.2))
    shading = np.clip(camera_lab[..., 0] / max(skin_ref, 0.1), 0.0, 1.6)
    for effect in recipe.get("effects", []):
        kind = effect["type"]
        region = effect.get("region", "eyes" if kind == "glitter" else "cheeks_nose")
        if region not in ("cheeks_nose", "full_face"):
            continue
        mask = maps.skin if region == "full_face" else maps.cheeks_nose
        k_int = effect["intensity"]
        if kind == "freckles":
            density = k["kFreckleDensityMin"] + (k["kFreckleDensityMax"] - k["kFreckleDensityMin"]) * k_int
            alpha = np.zeros(camera.shape[:2])
            for side in (0.0, 1.0):
                part = freckle_alpha(maps.face_map_uv, density, side=side)
                alpha = np.where(maps.side == side, part, alpha)
            # Capa con el color de la piel media (compose lo multiplica por el
            # sombreado de cada píxel, como el shader con la piel del píxel).
            skin_lab = np.median(camera_lab[maps.skin > 0.9], axis=0)
            layers.insert(1 if layers else 0,
                          Layer(freckle_lab(skin_lab), alpha * mask * k_int * k["kFreckleOpacity"]))
        elif kind == "sheen":
            gain = gain * sheen_gain(shading, mask * k_int * k["kSheenGain"])
        elif kind == "glitter":
            density = k["kGlitterDensityMin"] + (k["kGlitterDensityMax"] - k["kGlitterDensityMin"]) * k_int
            shine_extra += glitter_sparkle(maps.face_map_uv, density) * mask * k_int * k["kGlitterSparkle"]
    if layers or shine_extra.any() or (gain != 1).any():
        result, coverage = compose(camera, layers, skin_ref)
        linear = np.power(result, 2.2) * gain[..., None] + shine_extra[..., None]
        result = lin_to_srgb(np.minimum(linear, 1.0))
        coverage = np.where((shine_extra > 0) | (gain != 1), np.maximum(coverage, 1e-6), coverage)
        out = blend(out, *layer_over(result, camera, coverage))

    # Pasada de ojos: sombras en el orden de la receta y el delineado encima.
    eyes = recipe.get("eyes", {})
    layers = []
    for shadow in eyes.get("shadow", [])[:4]:
        channel_map, index = EYE_REGION_CHANNEL[shadow["region"]]
        mask = (maps.eye_a if channel_map == "A" else maps.eye_b)[..., index]
        finish = shadow.get("finish", "matte")
        shine = k["kShadowSatinShine"] if finish in ("satin", "shimmer") else 0.0
        layers.append(Layer(color(shadow["color"]), mask * shadow["opacity"], shine=shine))
    liner = eyes.get("liner")
    if liner:
        edge0 = k["kLinerThicknessMin"] + (k["kLinerThicknessMax"] - k["kLinerThicknessMin"]) * liner.get("thickness", 0.5)
        edge1 = edge0 + k["kLinerFeather"]
        wing = liner.get("wing", 0.0)
        line = 1.0 - _smooth(edge0, edge1, maps.eye_b[..., 1])
        wing_mask = (1.0 - _smooth(edge0, edge1, maps.eye_b[..., 2])) * (1.0 - _smooth(wing - 0.05, wing, maps.eye_b[..., 3]))
        layers.append(Layer(color(liner["color"]), np.maximum(line, wing_mask) * liner["opacity"]))
    lashes = eyes.get("lashes")
    if lashes:
        volume = lashes.get("volume", 0.5)
        lerp = lambda a, b, t: a + (b - a) * t  # noqa: E731
        params = (lerp(k["kLashCountMin"], k["kLashCountMax"], volume),
                  lerp(k["kLashLengthMin"], k["kLashLengthMax"], lashes.get("length", 0.5)),
                  lerp(k["kLashWidthMin"], k["kLashWidthMax"], volume), k["kLashCurl"])
        opacity = lashes["opacity"]
        # Las dos mitades por separado: el hash de las hebras depende del lado.
        alpha = np.zeros(camera.shape[:2])
        for side in (0.0, 1.0):
            part = lash_alpha(maps.eye_c, opacity, opacity * k["kLowerLashOpacity"], params,
                              volume * k["kLashRootMax"], side=side)
            alpha = np.where(maps.side == side, part, alpha)
        layers.append(Layer(srgb_to_oklab(np.array(k["kLashColor"])), alpha))
    if layers:
        result, coverage = compose(camera, layers, skin_ref)
        out = blend(out, *layer_over(result, camera, coverage))

    # Labios: mismos acabados que Renderer::setLips (tools/lips/calibration_grid.py).
    lips = recipe.get("lips")
    if lips:
        finish = lips.get("finish", "satin")
        gloss, sharpness = lips.get("gloss", 0.0), 2.0
        if finish == "matte":
            gloss = 0.0
        elif finish == "gloss":
            sharpness = k["kLipsSharpnessGloss"]
        else:
            gloss *= k["kLipsSatinGlossScale"]
            sharpness = k["kLipsSharpnessSatin"]
        params = LipParams(target_lab=color(lips["color"]), opacity=lips["opacity"],
                           luma_follow=lips.get("lumaFollow", 0.8), lip_lightness=lip_ref, gloss=gloss,
                           sharpness=sharpness, light=1.0)
        w = np.clip(maps.lips_mask * params.opacity, 0, 1)
        liner = np.zeros_like(w)
        liner_lab = None
        if lips.get("liner"):
            spec = LipLiner(color(lips["liner"]["color"]), lips["liner"]["opacity"], k["kLipLinerEdge"])
            gy, gx = np.gradient(maps.lips_liner)
            liner = liner_alpha(maps.lips_liner, spec, np.abs(gx) + np.abs(gy))
            liner_lab = spec.target_lab
        result = shade(camera, maps.lips_mask, maps.lips_gloss, params, liner=liner, liner_lab=liner_lab)
        out = blend(out, *layer_over(result, camera, 1.0 - (1.0 - w) * (1.0 - liner)))
    return np.clip(out, 0, 1)


def _smooth(edge0: float, edge1: float, x: np.ndarray) -> np.ndarray:
    t = np.clip((x - edge0) / (edge1 - edge0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def main() -> int:
    k = engine_constants()
    looks = presets()
    # Columna de prueba: ningún preset usa el delineado de labios.
    red = next(r for r in looks if r["name"] == "Rojo clásico")
    looks.append({**red, "name": "Rojo + delineado (prueba)",
                  "lips": {**red["lips"], "liner": {"color": "#6E0A1A", "opacity": 0.8}}})
    maps = Maps()
    columns = 1 + len(looks)
    width = columns * CELL_W + (columns + 1) * GAP
    height = SWATCH_H + len(SKIN_TONES) * CELL_H + (len(SKIN_TONES) + 2) * GAP
    canvas = np.full((height, width, 3), 0.12)
    for col, recipe in enumerate(looks, start=1):
        x0 = GAP + col * (CELL_W + GAP)
        lips = recipe.get("lips")
        if lips:
            canvas[GAP:GAP + SWATCH_H, x0:x0 + CELL_W] = hex_to_srgb(lips["color"])
    for row, tone in enumerate(SKIN_TONES):
        camera = bare_face(maps, tone)
        y0 = 2 * GAP + SWATCH_H + row * (CELL_H + GAP)
        canvas[y0:y0 + CELL_H, GAP:GAP + CELL_W] = camera
        for col, recipe in enumerate(looks, start=1):
            x0 = GAP + col * (CELL_W + GAP)
            canvas[y0:y0 + CELL_H, x0:x0 + CELL_W] = apply_recipe(camera, maps, recipe, k)
    pixels = (np.clip(canvas, 0, 1) * 255 + 0.5).astype(np.uint8)
    OUTPUT.write_bytes(lm.png_bytes(pixels))
    names = ", ".join(r["name"] for r in looks)
    print(f"columnas: sin maquillaje, {names}")
    print(f"escrito {OUTPUT.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

"""Grilla de calibración del labial (P4): 5 tonos de piel sintéticos × presets.

Pinta un labio sintético (forma, sombreado, pliegues verticales y un reflejo
real en el labio inferior) para cada tono de piel y le aplica cada preset de
lib/features/ar/domain/recipe_presets.dart con la misma matemática que
lips.frag (lip_shading.shade) y los mismos acabados que Renderer::setLips
(engine_config.h). Sin datasets ni fotos: los tonos se definen en OKLab.

Salida: docs/ar_engine/img/lips_calibration.png
  fila 0      muestra del color de cada preset (columna 0: sin maquillaje)
  filas 1..5  piel muy clara -> profunda
y en consola, por celda, la diferencia entre el color medio del labio pintado
y el de la receta (ΔL y Δcroma OKLab): sirve para ajustar lumaFollow.

Uso:  python tools/lips/calibration_grid.py
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.path.insert(0, str(ROOT / "tools" / "uv_masks"))
from lip_shading import LipParams, from_ok, lin_to_srgb, shade, srgb_to_oklab, hex_to_srgb, to_ok  # noqa: E402
from gen_lips_maps import png_bytes  # noqa: E402

PRESETS_DART = ROOT / "lib" / "features" / "ar" / "domain" / "recipe_presets.dart"
ENGINE_CONFIG = ROOT / "packages" / "makeup_engine" / "android" / "src" / "main" / "cpp" / "engine_config.h"
OUTPUT = ROOT / "docs" / "ar_engine" / "img" / "lips_calibration.png"

CELL_W, CELL_H = 200, 120
SWATCH_H = 36
GAP = 4

# Tonos de piel (L, croma, tono en grados OKLab) y labio relativo a la piel:
# el labio es algo más oscuro y más rojo. Valores típicos, no de un dataset.
SKIN_TONES = [
    (0.86, 0.045, 65.0),
    (0.78, 0.060, 60.0),
    (0.68, 0.070, 58.0),
    (0.55, 0.070, 55.0),
    (0.40, 0.050, 50.0),
]
LIP_DELTA_L = -0.07
LIP_CHROMA = 0.075
LIP_HUE = 22.0


def lch(lightness: float, chroma: float, hue_deg: float) -> np.ndarray:
    h = np.radians(hue_deg)
    return np.array([lightness, chroma * np.cos(h), chroma * np.sin(h)])


def engine_constants() -> dict[str, float]:
    text = ENGINE_CONFIG.read_text(encoding="utf-8")
    return {m.group(1): float(m.group(2))
            for m in re.finditer(r"constexpr float (kLips\w+) = ([0-9.]+)f;", text)}


def presets() -> list[tuple[str, dict]]:
    """(nombre, lips) de cada preset, en el orden del archivo Dart."""
    text = PRESETS_DART.read_text(encoding="utf-8")
    out = []
    for match in re.finditer(r"'name': '([^']+)',\s*'lips': \{([^}]*)\}", text):
        lips = {}
        for key, value in re.findall(r"'(\w+)': ('[^']*'|[0-9.]+)", match.group(2)):
            lips[key] = value.strip("'") if value.startswith("'") else float(value)
        out.append((match.group(1), lips))
    return out


def lip_geometry(width: int, height: int):
    """Máscara (suave), sombreado relativo y mapa de brillo de un labio frontal."""
    y, x = np.mgrid[0:height, 0:width].astype(float)
    x = (x + 0.5) / width * 2.0 - 1.0
    y = (y + 0.5) / height * 2.0 - 1.0
    span = np.clip(1.0 - x * x, 0.0, None)
    bow = 0.10 * np.exp(-(x / 0.12) ** 2)
    top = -0.62 * np.power(span, 0.55) + bow
    mid = 0.04 * x * x - 0.02
    bottom = 0.70 * np.power(span, 0.7)
    feather = 0.06
    upper = np.clip((y - top) / feather, 0, 1) * np.clip((mid - y) / feather, 0, 1)
    lower = np.clip((y - mid) / feather, 0, 1) * np.clip((bottom - y) / feather, 0, 1)
    mask = np.clip(upper + lower, 0.0, 1.0) * np.clip((0.97 - np.abs(x)) / 0.05, 0, 1)

    # Sombreado (factor sobre L): labio superior mira hacia abajo, el inferior
    # recibe más luz en el centro; pliegues verticales finos; comisuras oscuras.
    rng = np.random.default_rng(11)
    light = np.where(y < mid, 0.86 + 0.08 * (y - top) / np.maximum(mid - top, 1e-3), 1.0)
    light = light + np.where(y >= mid, 0.10 * np.exp(-((y - 0.28) / 0.22) ** 2) - 0.12 * np.clip((y - 0.45) / 0.3, 0, 1), 0)
    creases = 0.035 * np.sin(x * 55.0 + 3.0 * np.sin(y * 7.0)) * np.exp(-((y - mid) / 0.5) ** 2)
    corners = -0.18 * np.clip((np.abs(x) - 0.7) / 0.3, 0, 1)
    light = light + creases + corners + rng.normal(0, 0.008, size=x.shape)
    # Reflejo real del labio inferior (el que ya trae la cámara).
    highlight = np.exp(-((x / 0.30) ** 2 + ((y - 0.25) / 0.08) ** 2))
    gloss = np.exp(-((x / 0.38) ** 2 + ((y - 0.27) / 0.12) ** 2))
    gloss += 0.45 * np.exp(-(((np.abs(x) - 0.28) / 0.18) ** 2 + ((y + 0.30) / 0.08) ** 2))
    return mask, light, highlight, np.clip(gloss, 0, 1)


def bare_face(skin: np.ndarray, lip: np.ndarray, mask, light, highlight) -> np.ndarray:
    """Cámara sintética: piel alrededor y labio con su sombreado, en sRGB."""
    lip_lab = lip[None, None, :] * light[..., None]
    lip_lin = np.clip(from_ok(lip_lab), 0, 1) + 0.12 * highlight[..., None]
    skin_lin = np.clip(from_ok(skin), 0, 1)
    rgb = skin_lin[None, None, :] * (1 - mask[..., None]) + lip_lin * mask[..., None]
    return lin_to_srgb(np.clip(rgb, 0, 1))


def lip_params(lips: dict, lip_lightness: float, k: dict[str, float]) -> tuple[LipParams, float]:
    """Mismos acabados que Renderer::setLips; devuelve también los destellos."""
    finish = lips.get("finish", "satin")
    gloss = float(lips.get("gloss", 0.0))
    sharpness = 2.0
    sparkle = 0.0
    if finish == "matte":
        gloss = 0.0
    elif finish == "gloss":
        sharpness = k["kLipsSharpnessGloss"]
    else:
        gloss *= k["kLipsSatinGlossScale"]
        sharpness = k["kLipsSharpnessSatin"]
        if finish == "shimmer":
            sparkle = k["kLipsSparkle"] * gloss  # Renderer::setLips: uSparkle = kLipsSparkle · gloss
    params = LipParams(target_lab=srgb_to_oklab(hex_to_srgb(lips["color"])), opacity=float(lips["opacity"]),
                       luma_follow=float(lips.get("lumaFollow", 0.8)), lip_lightness=lip_lightness,
                       gloss=gloss, sharpness=sharpness, light=1.0)
    return params, sparkle


def main() -> int:
    k = engine_constants()
    looks = presets()
    mask, light, highlight, gloss_map = lip_geometry(CELL_W, CELL_H)
    rng = np.random.default_rng(5)
    sparkle_cells = (rng.uniform(size=(CELL_H // 3 + 1, CELL_W // 3 + 1)) > 0.94).astype(float)
    sparkle = np.kron(sparkle_cells, np.ones((3, 3)))[:CELL_H, :CELL_W]

    columns = 1 + len(looks)
    width = columns * CELL_W + (columns + 1) * GAP
    height = SWATCH_H + len(SKIN_TONES) * CELL_H + (len(SKIN_TONES) + 2) * GAP
    canvas = np.full((height, width, 3), 0.12)
    for col, (_, lips) in enumerate(looks, start=1):
        x0 = GAP + col * (CELL_W + GAP)
        canvas[GAP:GAP + SWATCH_H, x0:x0 + CELL_W] = hex_to_srgb(lips["color"])

    inside = mask > 0.9
    print(f"{'piel L':>7} | " + " | ".join(f"{name[:12]:>12}" for name, _ in looks))
    for row, (skin_l, skin_c, skin_h) in enumerate(SKIN_TONES):
        skin = lch(skin_l, skin_c, skin_h)
        lip = lch(skin_l + LIP_DELTA_L, LIP_CHROMA, LIP_HUE)
        camera = bare_face(skin, lip, mask, light, highlight)
        # Como el tracker: mediana de L en el cuerpo del labio.
        lip_lightness = float(np.median(to_ok(np.power(camera[inside], 2.2))[:, 0]))
        y0 = 2 * GAP + SWATCH_H + row * (CELL_H + GAP)
        canvas[y0:y0 + CELL_H, GAP:GAP + CELL_W] = camera
        cells = []
        for col, (_, lips) in enumerate(looks, start=1):
            params, sparkle_k = lip_params(lips, lip_lightness, k)
            out = shade(camera, mask, gloss_map, params, sparkle=sparkle * sparkle_k)
            x0 = GAP + col * (CELL_W + GAP)
            canvas[y0:y0 + CELL_H, x0:x0 + CELL_W] = out
            # Color medio fuera del reflejo (gloss_map bajo) vs. la receta.
            body = inside & (gloss_map < 0.2)
            mean_lab = to_ok(np.power(out[body], 2.2)).mean(axis=0)
            target = params.target_lab
            d_l = mean_lab[0] - target[0]
            d_c = np.hypot(*mean_lab[1:]) - np.hypot(*target[1:])
            cells.append(f"{d_l:+.2f}/{d_c:+.2f}")
        print(f"{skin_l:>7.2f} | " + " | ".join(f"{c:>12}" for c in cells))

    pixels = (np.clip(canvas, 0, 1) * 255 + 0.5).astype(np.uint8)
    OUTPUT.write_bytes(png_bytes(pixels))
    print(f"(dL/dC: L y croma OKLab del labio pintado menos los de la receta)\nescrito {OUTPUT.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

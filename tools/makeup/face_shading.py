"""Referencia (Python) del compositor de capas del motor (P5).

Es la especificación de face.frag / eyes.frag y de layerOver (color.glsl):
si cambia uno, cambia el otro. Los labios siguen en tools/lips/lip_shading.py
(misma idea, con el L medido del labio y el brillo del mapa).

Cada pasada (cara u ojos) parte del píxel de cámara en OKLab y aplica sus
capas en orden con el modelo de P4:
    s      = L_píxel / L_referencia       (sombreado; L de la piel medida)
    lit    = color · s                    (el producto bajo la misma luz)
    L      = mix(L, lit.L, a · lumaFollow)
    ab     = mix(ab, lit.ab, a)
    brillo = mix(brillo, brillo_capa, a)  (una capa encima tapa el de abajo)
y convierte una sola vez (bajando croma si sale de gamut). La cobertura de la
pasada es A = 1 - Π(1 - a_i); la salida va premultiplicada (layer_over) y el
blending la compone sobre lo ya dibujado (blend).

Todo opera sobre arrays de numpy con forma (..., 3) o (...), por píxel.
"""

from __future__ import annotations

import sys
from dataclasses import dataclass
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "lips"))
from lip_shading import (  # noqa: E402
    LIP_LIGHTNESS_MIN,
    SHADING_MAX,
    _smoothstep,
    hex_to_srgb,
    lin_to_srgb,
    oklab_to_linear_in_gamut,
    srgb_to_lin,
    srgb_to_oklab,
    to_ok,
)

__all__ = ["Layer", "compose", "layer_over", "blend", "hex_to_srgb", "srgb_to_oklab", "SHADING_MAX"]


@dataclass(frozen=True)
class Layer:
    """Una región de la receta ya resuelta: color OKLab y cobertura por píxel
    (máscara · opacidad · orientación). shine > 0 suma un brillo leve donde
    hay luz (iluminador, sombras satinadas)."""

    target_lab: np.ndarray
    alpha: np.ndarray | float
    luma_follow: float = 1.0
    shine: float = 0.0


# face.frag: SHINE_SHADING_LOW / SHINE_SHADING_HIGH (mismo criterio que el
# brillo de los labios: no aparece en las sombras).
SHINE_SHADING_LOW = 0.85
SHINE_SHADING_HIGH = 1.1


def compose(camera_srgb: np.ndarray, layers: list[Layer], reference_lightness: float):
    """Color final sRGB de la pasada sobre la cámara y su cobertura A."""
    lab = to_ok(srgb_to_lin(camera_srgb))
    shading = np.clip(lab[..., 0] / max(reference_lightness, LIP_LIGHTNESS_MIN), 0.0, SHADING_MAX)
    keep = np.ones(lab.shape[:-1])
    shine = np.zeros(lab.shape[:-1])
    for layer in layers:
        a = np.clip(np.broadcast_to(layer.alpha, keep.shape), 0.0, 1.0)
        lit = layer.target_lab * shading[..., None]
        lightness = lab[..., 0] + (lit[..., 0] - lab[..., 0]) * a * layer.luma_follow
        ab = lab[..., 1:] + (lit[..., 1:] - lab[..., 1:]) * a[..., None]
        lab = np.concatenate([np.clip(lightness, 0.0, 1.0)[..., None], ab], axis=-1)
        shine = shine + (layer.shine - shine) * a
        keep = keep * (1.0 - a)
    out = oklab_to_linear_in_gamut(lab)
    out = np.minimum(out + (shine * _smoothstep(SHINE_SHADING_LOW, SHINE_SHADING_HIGH, shading))[..., None], 1.0)
    coverage = 1.0 - keep
    result = lin_to_srgb(out)
    # Sin cobertura el shader no toca el píxel (sale antes): queda la cámara.
    return np.where((coverage > 0.0)[..., None], result, camera_srgb), coverage


def layer_over(result_srgb: np.ndarray, camera_srgb: np.ndarray, coverage: np.ndarray):
    """color.glsl: layerOver. Salida premultiplicada (rgb, a): sobre la cámara
    da exactamente [result]; si oscurece más de lo que la cobertura permite,
    la cobertura efectiva sube para que el rgb no sea negativo."""
    coverage = np.asarray(coverage, dtype=float)
    ratio = result_srgb / np.maximum(camera_srgb, 1e-3)
    keep = np.minimum(1.0 - coverage, ratio.min(axis=-1))
    return result_srgb - keep[..., None] * camera_srgb, 1.0 - keep


def blend(dst_srgb: np.ndarray, src_rgb: np.ndarray, src_alpha: np.ndarray) -> np.ndarray:
    """glBlendFuncSeparate(ONE, ONE_MINUS_SRC_ALPHA, ...) sobre el color."""
    return src_rgb + (1.0 - np.asarray(src_alpha, dtype=float))[..., None] * dst_srgb


# --- Pestañas (eyes.frag: lashCoord, lashStrands) ---

LASH_ROOT_HEIGHT = 0.07
LASH_S_START = 0.03
LASH_S_END = 0.96
LOWER_LASH_COUNT = 0.6
LOWER_LASH_WIDTH = 0.7
LOWER_LASH_CURL = 0.4


def hash12(p: np.ndarray) -> np.ndarray:
    """color.glsl: hash12 (Dave Hoskins). p (..., 2) -> [0,1)."""
    p3 = np.modf(np.stack([p[..., 0], p[..., 1], p[..., 0]], axis=-1) * 0.1031)[0]
    p3 = np.where(p3 < 0, p3 + 1, p3)
    p3 = p3 + (p3 * (p3[..., [1, 2, 0]] + 33.33)).sum(axis=-1, keepdims=True)
    value = (p3[..., 0] + p3[..., 1]) * p3[..., 2]
    return value - np.floor(value)


def lash_coord(s, h, count, curl):
    return (s + curl * h * h * (1.2 - 1.6 * s)) * count


def lash_strands(x, s, h, length_max, half_width, aa, side):
    cell = np.floor(x)
    jitter = hash12(np.stack([cell, np.full_like(cell, side * 31.0 + 7.0)], axis=-1))
    length = length_max * (0.6 + 0.4 * jitter) * (0.55 + 0.45 * _smoothstep(1.0, 0.6, s))
    t = h / np.maximum(length, 1e-3)
    w = half_width * np.power(np.maximum(1.0 - t, 0.0), 0.7)
    f = np.abs(x - np.floor(x) - 0.5 - (jitter - 0.5) * 0.3)
    strand = 1.0 - _smoothstep_any(w - aa, w + aa, f)
    window = _smoothstep(LASH_S_START, LASH_S_START + 0.04, s) * (1.0 - _smoothstep(LASH_S_END - 0.03, LASH_S_END, s))
    return strand * (t <= 0.98) * window


def lash_alpha(map_c: np.ndarray, amount: float, lower_amount: float, params, root: float, side: float = 0.0,
               aa: tuple[np.ndarray, np.ndarray] | None = None) -> np.ndarray:
    """Cobertura de las pestañas (sin orientación). map_c (..., 4) en [0,1];
    params = (hebras, largo, medio ancho, inclinación) como uLashParams. aa: el
    fwidth de las coordenadas superior e inferior (por defecto, por gradiente
    de la imagen, como en pantalla)."""
    count, length, width, curl = params
    upper_x = lash_coord(map_c[..., 0], map_c[..., 1], count, curl)
    lower_x = lash_coord(map_c[..., 2], map_c[..., 3], count * LOWER_LASH_COUNT, curl * LOWER_LASH_CURL)
    if aa is None:
        aa = (_fwidth(upper_x), _fwidth(lower_x))
    upper = lash_strands(upper_x, map_c[..., 0], map_c[..., 1], length, width, aa[0], side)
    root_mask = (1.0 - _smoothstep(0.0, LASH_ROOT_HEIGHT, map_c[..., 1])) * root
    root_mask = root_mask * _smoothstep(LASH_S_START, LASH_S_START + 0.08, map_c[..., 0]) * \
        (1.0 - _smoothstep(LASH_S_END - 0.1, LASH_S_END, map_c[..., 0]))
    lower = lash_strands(lower_x, map_c[..., 2], map_c[..., 3], length, width * LOWER_LASH_WIDTH, aa[1], side + 2.0)
    return np.clip(np.maximum(upper, root_mask) * amount + lower * lower_amount, 0.0, 1.0)


def _smoothstep_any(edge0, edge1, x):
    """smoothstep de GLSL con bordes por píxel (edge0 < edge1)."""
    t = np.clip((x - edge0) / np.maximum(edge1 - edge0, 1e-9), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def _fwidth(x: np.ndarray) -> np.ndarray:
    if x.ndim < 2:
        return np.zeros_like(x)
    gy, gx = np.gradient(x)
    return np.abs(gx) + np.abs(gy)


# --- Efectos procedurales (face.frag variante EFFECTS) ---

FRECKLE_CELLS = np.array([80.0, 140.0])
GLITTER_CELLS = np.array([120.0, 210.0])
FRECKLE_SCALE = np.array([0.74, 1.2, 1.35])  # face.frag: FRECKLE_SCALE
SHEEN_SHADING_LOW = 0.95  # color.glsl
SHEEN_SHADING_HIGH = 1.2


def freckle_alpha(map_uv: np.ndarray, density: float, side: float = 0.0, aa: np.ndarray | float | None = None):
    """Puntos de pecas (cobertura [0,1] sin intensidad ni máscara). map_uv
    (..., 2) en coordenadas del mapa de media cara."""
    fc = map_uv * FRECKLE_CELLS
    cell = np.floor(fc) + np.array([side * 613.0, 0.0])
    if aa is None:
        aa = _fwidth(fc[..., 0])
    center = np.stack([hash12(cell + 17.0), hash12(cell + 41.0)], axis=-1) * 0.6 + 0.2
    radius = 0.1 + (0.26 - 0.1) * hash12(cell + 73.0)
    present = hash12(cell) <= density
    dist = np.linalg.norm(fc - np.floor(fc) - center, axis=-1)
    return present * (1.0 - _smoothstep_any(radius - aa, radius + aa, dist))


def freckle_lab(camera_lab: np.ndarray) -> np.ndarray:
    """Color de las pecas: la piel del píxel (ya con la base, como en
    face.frag) más oscura y más cálida (proporcional, para que valga en todos
    los tonos)."""
    return camera_lab * FRECKLE_SCALE


def sheen_gain(shading: np.ndarray, gain: float) -> np.ndarray:
    """Factor sobre la luz lineal: solo aclara lo más iluminado que la piel media."""
    return 1.0 + gain * _smoothstep(SHEEN_SHADING_LOW, SHEEN_SHADING_HIGH, shading)


def glitter_sparkle(map_uv: np.ndarray, density: float, tick: float = 0.0, side: float = 0.0) -> np.ndarray:
    """Destellos 0/1 por celda (cambian con tick)."""
    cell = np.floor(map_uv * GLITTER_CELLS) + np.array([side * 997.0, 0.0])
    return (hash12(cell + np.array([tick * 17.0, tick * 31.0])) >= 1.0 - density).astype(float)

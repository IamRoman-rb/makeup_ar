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

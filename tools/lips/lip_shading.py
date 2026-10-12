"""Referencia (Python) del sombreado de labios del motor (P4).

Es la especificación de lo que hacen shaders/lips.frag y shaders/color.glsl
(oklabToLinearInGamut): si cambia una, cambia la otra. Sirve para los tests y para la
grilla de calibración (calibration_grid.py); el motor no la usa.

Todo opera sobre arrays de numpy con forma (..., 3) o (...), por píxel.
"""

from __future__ import annotations

import sys
from dataclasses import dataclass
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "studio"))
from sample_region_reference import from_ok, lin_to_srgb, srgb_to_lin, to_ok  # noqa: E402


GAMUT_STEPS = 6  # color.glsl: GAMUT_STEPS
GAMUT_EPSILON = 1e-5  # color.glsl: GAMUT_EPSILON
# lips.frag: SHADING_MAX, LIP_LIGHTNESS_MIN, GLOSS_SHADING_LOW/HIGH.
SHADING_MAX = 1.6
LIP_LIGHTNESS_MIN = 0.1
GLOSS_SHADING_LOW = 0.75
GLOSS_SHADING_HIGH = 1.05


def _in_gamut(rgb_lin: np.ndarray) -> np.ndarray:
    return np.all((rgb_lin >= -GAMUT_EPSILON) & (rgb_lin <= 1.0 + GAMUT_EPSILON), axis=-1)


def oklab_to_linear_in_gamut(lab: np.ndarray) -> np.ndarray:
    """OKLab -> RGB lineal en [0,1]³ bajando solo la croma, con L y tono fijos
    (color.glsl: oklabToLinearInGamut). lab[..., 0] tiene que estar en [0,1]."""
    lab = np.asarray(lab, dtype=float)
    direct = from_ok(lab)
    lo = np.zeros(lab.shape[:-1])
    hi = np.ones(lab.shape[:-1])
    for _ in range(GAMUT_STEPS):
        mid = 0.5 * (lo + hi)
        trial = np.concatenate([lab[..., :1], lab[..., 1:] * mid[..., None]], axis=-1)
        inside = _in_gamut(from_ok(trial))
        lo = np.where(inside, mid, lo)
        hi = np.where(inside, hi, mid)
    reduced = np.concatenate([lab[..., :1], lab[..., 1:] * lo[..., None]], axis=-1)
    clipped = np.clip(from_ok(reduced), 0.0, 1.0)
    return np.where(_in_gamut(direct)[..., None], np.clip(direct, 0.0, 1.0), clipped)


@dataclass(frozen=True)
class LipParams:
    """Uniforms de lips.frag ya resueltos en CPU."""

    target_lab: np.ndarray  # OKLab del color de la receta
    opacity: float  # opacidad de la receta × fundido del tracker, [0, 1]
    luma_follow: float  # [0, 1]
    lip_lightness: float  # L OKLab medido del labio (o el de respaldo)
    gloss: float  # intensidad del brillo [0, 1]; 0 en mate
    sharpness: float  # exponente sobre el mapa de brillo, [1, 8]
    light: float  # atenuación por luz de la escena, [0, 1]


def shade(camera_srgb: np.ndarray, mask: np.ndarray, gloss_map: np.ndarray, p: LipParams,
          sparkle: np.ndarray | float = 0.0) -> np.ndarray:
    """Color sRGB de salida por píxel (lips.frag).

    camera_srgb (..., 3) en [0,1]; mask y gloss_map (...) en [0,1] (canales R
    y G del mapa de labios; gloss_map ya leído en la posición desplazada por
    la pose). sparkle (...) son los destellos ya multiplicados por uSparkle
    (el hash de celdas del shader no se reproduce). La orientación (vFacing
    de lips.vert) no está: equivale a 1, el labio de frente.
    """
    w = np.clip(mask * p.opacity, 0.0, 1.0)
    lab = to_ok(srgb_to_lin(camera_srgb))
    # Sombreado del píxel relativo al labio medio. OKLab es homogéneo: escalar
    # la luz lineal por k escala (L, a, b) por k^(1/3), así que el labial bajo
    # la misma luz es target · shading (sombras menos saturadas, como en un
    # labio real; el color plano parece una calcomanía).
    shading = np.clip(lab[..., 0] / max(p.lip_lightness, LIP_LIGHTNESS_MIN), 0.0, SHADING_MAX)
    lit = p.target_lab * shading[..., None]
    lightness = np.clip(lab[..., 0] + (lit[..., 0] - lab[..., 0]) * w * p.luma_follow, 0.0, 1.0)
    ab = lab[..., 1:] + (lit[..., 1:] - lab[..., 1:]) * w[..., None]
    out = oklab_to_linear_in_gamut(np.concatenate([lightness[..., None], ab], axis=-1))
    # El brillo necesita luz: no aparece en las sombras y pliegues del labio.
    lit_gate = _smoothstep(GLOSS_SHADING_LOW, GLOSS_SHADING_HIGH, shading)
    spec = (np.power(gloss_map, p.sharpness) + sparkle) * p.gloss * p.light * w * lit_gate
    out = np.minimum(out + spec[..., None], 1.0)
    # Fuera de la máscara el shader devuelve la cámara tal cual.
    return np.where((w > 0.0)[..., None], lin_to_srgb(out), camera_srgb)


def _smoothstep(edge0: float, edge1: float, x: np.ndarray) -> np.ndarray:
    t = np.clip((x - edge0) / (edge1 - edge0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def hex_to_srgb(value: str) -> np.ndarray:
    value = value.lstrip("#")
    return np.array([int(value[i:i + 2], 16) / 255.0 for i in (0, 2, 4)])


def srgb_to_oklab(srgb: np.ndarray) -> np.ndarray:
    return to_ok(srgb_to_lin(srgb))

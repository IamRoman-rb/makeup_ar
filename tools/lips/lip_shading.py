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


def _in_gamut(rgb_lin: np.ndarray) -> np.ndarray:
    return np.all((rgb_lin >= 0.0) & (rgb_lin <= 1.0), axis=-1)


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
    return np.where(_in_gamut(direct)[..., None], direct, clipped)


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
    y G del mapa de labios); sparkle (...) en [0,1] solo con shimmer.
    """
    w = np.clip(mask * p.opacity, 0.0, 1.0)
    lab = to_ok(srgb_to_lin(camera_srgb))
    # L: se conserva la textura del labio y se corre su media hacia la L del
    # color, en la medida de lumaFollow.
    lightness = np.clip(lab[..., 0] + (p.target_lab[0] - p.lip_lightness) * w * p.luma_follow, 0.0, 1.0)
    ab = lab[..., 1:] + (p.target_lab[1:] - lab[..., 1:]) * w[..., None]
    out = oklab_to_linear_in_gamut(np.concatenate([lightness[..., None], ab], axis=-1))
    spec = (np.power(gloss_map, p.sharpness) + sparkle) * p.gloss * p.light * w
    out = np.minimum(out + spec[..., None], 1.0)
    # Fuera de la máscara el shader devuelve la cámara tal cual.
    return np.where((w > 0.0)[..., None], lin_to_srgb(out), camera_srgb)


def hex_to_srgb(value: str) -> np.ndarray:
    value = value.lstrip("#")
    return np.array([int(value[i:i + 2], 16) / 255.0 for i in (0, 2, 4)])


def srgb_to_oklab(srgb: np.ndarray) -> np.ndarray:
    return to_ok(srgb_to_lin(srgb))

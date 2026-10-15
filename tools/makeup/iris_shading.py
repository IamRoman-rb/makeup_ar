"""Referencia (Python) de la capa de iris (fase 4).

Es la especificación de iris.frag: si cambia uno, cambia el otro. Las
constantes son las de engine_config.h (kIris*); test_iris_shading.py verifica
que coincidan.

Por píxel, con r = |forma · (p - centro)| (la elipse del iris llevada a la
unidad, ver iris_r) y amount = opacidad · orientación · fundido:
    borde   = max(borde_receta, borde_mínimo)  (en el motor, 1,5 px vía fwidth)
    máscara = smoothstep(pupila ± borde, r) · (1 - smoothstep(1 ± borde_ext, r))
    a       = máscara · amount · (1 - reflejo(L_píxel)) · oscuridad(L_píxel)
    s       = min(max(L / L_ref, s_min + pendiente · L / L_ref), s_max)
    lit     = color · s, con L · (1 - oscurecimiento · smoothstep(inicio_limbal, 1, r))
    lab     = mix(lab, lit, a)
La salida va premultiplicada con layer_over, como el resto de las capas.
"""

from __future__ import annotations

import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "lips"))
from lip_shading import _smoothstep, lin_to_srgb, oklab_to_linear_in_gamut, srgb_to_lin, to_ok  # noqa: E402

IRIS_PUPIL = 0.38
IRIS_PUPIL_FEATHER = 0.08
IRIS_EDGE_FEATHER = 0.1
IRIS_LIMBAL_START = 0.72
IRIS_LIMBAL_DARKEN = 0.35
IRIS_REF_L = 0.42
IRIS_SHADING_MIN = 0.45
IRIS_SHADING_SLOPE = 0.5
IRIS_SHADING_MAX = 1.5
IRIS_DARK_LOW = 0.08
IRIS_DARK_HIGH = 0.14
IRIS_SPECULAR_LOW = 0.72
IRIS_SPECULAR_HIGH = 0.86

# Nombre en engine_config.h de cada constante (para el test de paridad).
ENGINE_NAMES = {
    "kIrisPupil": IRIS_PUPIL,
    "kIrisPupilFeather": IRIS_PUPIL_FEATHER,
    "kIrisEdgeFeather": IRIS_EDGE_FEATHER,
    "kIrisLimbalStart": IRIS_LIMBAL_START,
    "kIrisLimbalDarken": IRIS_LIMBAL_DARKEN,
    "kIrisRefL": IRIS_REF_L,
    "kIrisShadingMin": IRIS_SHADING_MIN,
    "kIrisShadingSlope": IRIS_SHADING_SLOPE,
    "kIrisShadingMax": IRIS_SHADING_MAX,
    "kIrisDarkLow": IRIS_DARK_LOW,
    "kIrisDarkHigh": IRIS_DARK_HIGH,
    "kIrisSpecularLow": IRIS_SPECULAR_LOW,
    "kIrisSpecularHigh": IRIS_SPECULAR_HIGH,
}


def iris_r(points: np.ndarray, center, ring) -> np.ndarray:
    """r de cada punto (..., 2) respecto de la elipse del iris: semiejes
    u = (p1 - p3) / 2 y v = (p2 - p4) / 2 del anillo (face_style.cpp:
    irisEllipses). r = 1 en el anillo."""
    ring = np.asarray(ring, dtype=float)
    axes = np.stack([(ring[0] - ring[2]) / 2.0, (ring[1] - ring[3]) / 2.0], axis=1)  # columnas u, v
    inverse = np.linalg.inv(axes)
    delta = np.asarray(points, dtype=float) - np.asarray(center, dtype=float)
    return np.linalg.norm(delta @ inverse.T, axis=-1)


def iris_mask(r: np.ndarray, min_feather: float = 0.0) -> np.ndarray:
    """Disco del iris sin la pupila, en radios del iris. [min_feather]: ancho
    mínimo de los bordes en radios (en el motor, 1,5 px con fwidth)."""
    r = np.asarray(r, dtype=float)
    pupil_feather = max(IRIS_PUPIL_FEATHER, min_feather)
    edge_feather = max(IRIS_EDGE_FEATHER, min_feather)
    pupil = _smoothstep(IRIS_PUPIL - pupil_feather, IRIS_PUPIL + pupil_feather, r)
    edge = 1.0 - _smoothstep(1.0 - edge_feather, 1.0 + edge_feather, r)
    return pupil * edge


def iris_shading(lightness: np.ndarray) -> np.ndarray:
    """Sombreado con piso suave: un iris oscuro sube, pero sigue el orden."""
    raw = np.asarray(lightness, dtype=float) / IRIS_REF_L
    return np.minimum(np.maximum(raw, IRIS_SHADING_MIN + IRIS_SHADING_SLOPE * raw), IRIS_SHADING_MAX)


def shade_iris(camera_srgb: np.ndarray, r: np.ndarray, target_lab: np.ndarray, amount: float,
               min_feather: float = 0.0):
    """Color final sRGB y cobertura a de la capa de iris sobre la cámara."""
    camera_srgb = np.asarray(camera_srgb, dtype=float)
    r = np.asarray(r, dtype=float)
    coverage = iris_mask(r, min_feather) * amount
    lab = to_ok(srgb_to_lin(camera_srgb))
    lightness = lab[..., 0]
    a = np.clip(coverage * (1.0 - _smoothstep(IRIS_SPECULAR_LOW, IRIS_SPECULAR_HIGH, lightness)) *
                _smoothstep(IRIS_DARK_LOW, IRIS_DARK_HIGH, lightness), 0.0, 1.0)
    shading = iris_shading(lightness)
    lit = np.asarray(target_lab, dtype=float) * shading[..., None]
    limbal = 1.0 - IRIS_LIMBAL_DARKEN * _smoothstep(IRIS_LIMBAL_START, 1.0, r)
    lit = np.concatenate([(lit[..., 0] * limbal)[..., None], lit[..., 1:]], axis=-1)
    lightness = np.clip(lab[..., 0] + (lit[..., 0] - lab[..., 0]) * a, 0.0, 1.0)
    ab = lab[..., 1:] + (lit[..., 1:] - lab[..., 1:]) * a[..., None]
    out = lin_to_srgb(oklab_to_linear_in_gamut(np.concatenate([lightness[..., None], ab], axis=-1)))
    # Fuera del disco el shader sale antes: queda la cámara.
    return np.where((coverage > 0.0)[..., None], out, camera_srgb), a

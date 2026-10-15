"""Métricas del modelo propio (informe §6.2): las que le importan al producto.

- NME por región: error medio de los puntos dividido por la distancia entre
  los ángulos externos de los ojos (33-263), por cara. Con máscara: en el set
  de validación etiquetado a mano no se marcan los 478 puntos.
- Jitter: con la cara quieta (videos estáticos), desvío estándar de cada punto
  alrededor de su media, en px, promediado. Es lo que se ve como temblor del
  maquillaje.
La latencia p95 se mide en el E20 con lib/main_benchmark.dart, no acá.
"""

from __future__ import annotations

import numpy as np

from geometry import EYE_LEFT_IN_IMAGE, EYE_RIGHT_IN_IMAGE, regions


def interocular(points: np.ndarray) -> np.ndarray:
    """(N,) distancia entre los ángulos externos de los ojos (px)."""
    points = np.asarray(points, dtype=np.float64)
    return np.linalg.norm(points[:, EYE_LEFT_IN_IMAGE, :2] - points[:, EYE_RIGHT_IN_IMAGE, :2], axis=-1)


def nme_by_region(pred: np.ndarray, truth: np.ndarray, mask: np.ndarray | None = None,
                  normalizer: np.ndarray | None = None) -> dict[str, float]:
    """NME medio por región sobre N caras. pred/truth: (N, 478, ≥2) px de
    imagen; mask (N, 478) bool: puntos etiquetados. [normalizer]: distancia
    entre ojos por cara (por defecto, la de [truth]; si a mano no se marcaron
    los ojos, pasala aparte). Regiones sin puntos etiquetados no aparecen."""
    pred = np.asarray(pred, dtype=np.float64)[..., :2]
    truth = np.asarray(truth, dtype=np.float64)[..., :2]
    if pred.shape != truth.shape:
        raise ValueError(f"formas distintas: {pred.shape} vs {truth.shape}")
    mask = np.ones(pred.shape[:2], dtype=bool) if mask is None else np.asarray(mask, dtype=bool)
    norm = interocular(truth) if normalizer is None else np.asarray(normalizer, dtype=np.float64)
    if np.any(norm <= 0):
        raise ValueError("distancia entre ojos no positiva")
    error = np.linalg.norm(pred - truth, axis=-1) / norm[:, None]
    out = {}
    for name, indices in regions().items():
        idx = np.array(indices)
        selected = mask[:, idx]
        if selected.any():
            out[name] = float(error[:, idx][selected].mean())
    return out


def jitter_px(sequence: np.ndarray, indices=None) -> float:
    """Temblor de una secuencia estática: (T, 478, ≥2) px -> σ medio (px).
    Se descuenta una deriva lineal lenta (la persona nunca está del todo
    quieta): queda el ruido de cuadro a cuadro."""
    points = np.asarray(sequence, dtype=np.float64)[..., :2]
    if indices is not None:
        points = points[:, list(indices)]
    if len(points) < 3:
        raise ValueError("hacen falta al menos 3 cuadros")
    t = np.arange(len(points), dtype=np.float64)
    t = (t - t.mean())[:, None, None]
    slope = (t * (points - points.mean(axis=0))).sum(axis=0) / (t * t).sum()
    residual = points - points.mean(axis=0) - t * slope
    return float(np.sqrt((residual ** 2).sum(axis=-1).mean()))


def exit_criterion(student: dict[str, float], teacher: dict[str, float], tolerance: float = 0.0) -> dict[str, bool]:
    """Criterio de salida de la fase 3 (§7): NME del alumno <= el del modelo
    abierto en cada región, contra las etiquetas a mano."""
    return {name: student[name] <= teacher[name] * (1.0 + tolerance) for name in teacher if name in student}

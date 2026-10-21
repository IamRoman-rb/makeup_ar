"""Modelo más denso (opción 5 de precisión, TRACKER.md §10): infraestructura.

FaceMesh-V2 da 478 puntos; en el contorno de los labios son 20 por lado y
entre punto y punto el borde se interpola. Para un modelo propio que vea el
borde con más detalle, el alumno suma un cabezal "denso": contornos de labios
y ojos remuestreados por largo de arco (DENSE_SPEC), que se pueden etiquetar
a mano como polilíneas sin marcar los 478 puntos.

- Pseudo-etiquetas del maestro: spline Catmull-Rom centrípeta por los
  landmarks del contorno, remuestreada (dense_targets). Imitan al maestro;
  para superarlo hacen falta las polilíneas a mano (MODEL.md, paso 4).
- Métrica: distancia punto-a-contorno normalizada por la distancia entre
  ojos (contour_nme): mide si el borde cae donde está el borde real, sin
  depender de dónde cae cada punto a lo largo del contorno.
- Espejo horizontal para el aumento de datos (mirror_map, flip_points): el
  mapa izquierda<->derecha de los 468 puntos sale de la malla canónica y el
  iris se reordena por ángulo en cada muestra.

Sin datos ni modelos: todo es geometría sobre los landmarks.
"""

from __future__ import annotations

import re
import sys
from functools import lru_cache
from pathlib import Path

import numpy as np

from geometry import CONNECTIONS, LANDMARK_COUNT, MESH_VERTEX_COUNT

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "mesh"))
import gen_canonical_mesh as canonical  # noqa: E402

# Contornos densos: (nombre, conexión de face_mesh_connections.py, punto de
# arranque del lazo, puntos remuestreados). El arranque fija el orden (las
# comisuras y los ángulos externos de los ojos).
DENSE_SPEC = (
    ("labios_externo", "FACEMESH_LIPS", 61, 64),
    ("labios_interno", "FACEMESH_LIPS", 78, 48),
    ("ojo_izquierdo_imagen", "FACEMESH_RIGHT_EYE", 33, 32),
    ("ojo_derecho_imagen", "FACEMESH_LEFT_EYE", 263, 32),
)
DENSE_POINTS = sum(count for *_, count in DENSE_SPEC)
IRIS_CENTERS = (468, 473)
IRIS_RING = 4


def _edges(name: str) -> list[tuple[int, int]]:
    text = CONNECTIONS.read_text(encoding="utf-8")
    match = re.search(name + r"\s*=\s*frozenset\(\[(.*?)\]\)", text, re.S)
    if match is None:
        raise ValueError(f"{name} no está en {CONNECTIONS.name}")
    return [(int(a), int(b)) for a, b in re.findall(r"\((\d+),\s*(\d+)\)", match.group(1))]


@lru_cache(maxsize=None)
def loop(name: str, start: int) -> tuple[int, ...]:
    """Lazo ordenado de una conexión que contiene [start] (cada vértice, grado 2)."""
    return tuple(canonical.ordered_loop(_edges(name), start))


def _catmull_rom_closed(points: np.ndarray, samples_per_segment: int = 16) -> np.ndarray:
    """Curva cerrada centrípeta (alpha 0,5) por [points] (N, 2): pasa por todos."""
    n = len(points)
    out = []
    for i in range(n):
        p0, p1, p2, p3 = points[(i - 1) % n], points[i], points[(i + 1) % n], points[(i + 2) % n]

        def knot(a, b, t):
            return t + max(float(np.linalg.norm(b - a)) ** 0.5, 1e-6)

        t0 = 0.0
        t1 = knot(p0, p1, t0)
        t2 = knot(p1, p2, t1)
        t3 = knot(p2, p3, t2)
        for t in np.linspace(t1, t2, samples_per_segment, endpoint=False):
            a1 = (t1 - t) / (t1 - t0) * p0 + (t - t0) / (t1 - t0) * p1
            a2 = (t2 - t) / (t2 - t1) * p1 + (t - t1) / (t2 - t1) * p2
            a3 = (t3 - t) / (t3 - t2) * p2 + (t - t2) / (t3 - t2) * p3
            b1 = (t2 - t) / (t2 - t0) * a1 + (t - t0) / (t2 - t0) * a2
            b2 = (t3 - t) / (t3 - t1) * a2 + (t - t1) / (t3 - t1) * a3
            out.append((t2 - t) / (t2 - t1) * b1 + (t - t1) / (t2 - t1) * b2)
    return np.asarray(out)


def resample_closed(curve: np.ndarray, count: int) -> np.ndarray:
    """[count] puntos equiespaciados por largo de arco sobre la polilínea
    cerrada [curve] (M, 2), empezando por su primer punto."""
    closed = np.vstack([curve, curve[:1]])
    lengths = np.linalg.norm(np.diff(closed, axis=0), axis=1)
    cumulative = np.concatenate([[0.0], np.cumsum(lengths)])
    total = cumulative[-1]
    if total <= 0:
        return np.repeat(curve[:1], count, axis=0)
    targets = np.linspace(0.0, total, count, endpoint=False)
    out = np.empty((count, 2))
    for k in range(2):
        out[:, k] = np.interp(targets, cumulative, closed[:, k])
    return out


def dense_targets(points: np.ndarray) -> np.ndarray:
    """Pseudo-etiquetas densas (DENSE_POINTS, 2) desde los landmarks (478, ≥2)."""
    parts = []
    for _, name, start, count in DENSE_SPEC:
        ids = loop(name, start)
        parts.append(resample_closed(_catmull_rom_closed(points[list(ids), :2]), count))
    return np.vstack(parts)


def _point_to_polyline(points: np.ndarray, polyline: np.ndarray) -> np.ndarray:
    """Distancia de cada punto (N, 2) a la polilínea cerrada (M, 2)."""
    a = polyline
    b = np.roll(polyline, -1, axis=0)
    ab = b - a
    denom = np.maximum((ab * ab).sum(axis=1), 1e-12)
    ap = points[:, None, :] - a[None, :, :]
    t = np.clip((ap * ab[None]).sum(axis=-1) / denom[None], 0.0, 1.0)
    closest = a[None] + t[..., None] * ab[None]
    return np.linalg.norm(points[:, None, :] - closest, axis=-1).min(axis=1)


def contour_nme(pred_dense: np.ndarray, truth_polylines: dict[str, np.ndarray], interocular: float) -> dict[str, float]:
    """Distancia media de los puntos densos predichos a cada contorno real
    (polilínea cerrada, p. ej. etiquetada a mano), / distancia entre ojos."""
    out = {}
    offset = 0
    for name, _, _, count in DENSE_SPEC:
        polyline = truth_polylines.get(name)
        if polyline is not None and len(polyline) >= 3:
            d = _point_to_polyline(pred_dense[offset:offset + count], np.asarray(polyline, dtype=float))
            out[name] = float(d.mean() / max(interocular, 1e-6))
        offset += count
    return out


# --- Espejo horizontal --------------------------------------------------------------

@lru_cache(maxsize=1)
def mirror_map() -> np.ndarray:
    """(478,) índice del punto espejado. La malla: el vértice canónico más
    cercano a (−x, y, z). El iris: un ojo con el otro (468..472 <-> 473..477);
    el orden del anillo se corrige por ángulo en flip_points."""
    positions, _, _ = canonical.parse_obj(canonical.SOURCE / "canonical_face_model.obj")
    pos = np.asarray(positions)
    mirrored = pos * np.array([-1.0, 1.0, 1.0])
    distances = np.linalg.norm(mirrored[:, None, :] - pos[None, :, :], axis=-1)
    mesh = list(np.argmin(distances, axis=1))
    iris = list(range(MESH_VERTEX_COUNT, LANDMARK_COUNT))
    swapped = iris[IRIS_RING + 1:] + iris[:IRIS_RING + 1]
    return np.asarray(mesh + swapped, dtype=np.int64)


def _ring_permutation(center: np.ndarray, ring: np.ndarray, reference: np.ndarray) -> np.ndarray:
    """Permutación de los 4 puntos de [ring] (alrededor de [center]) que mejor
    sigue el patrón angular de [reference] (centro + 4, el orden que el
    maestro usa para ese índice): de los 4 giros y su reflejo, la mejor."""
    def angles(points, c):
        return np.arctan2(points[:, 1] - c[1], points[:, 0] - c[0])

    want = angles(reference[1:], reference[0])
    best, best_cost = np.arange(IRIS_RING), np.inf
    for order in (np.arange(IRIS_RING), np.arange(IRIS_RING)[::-1]):
        for shift in range(IRIS_RING):
            permutation = np.roll(order, shift)
            diff = np.angle(np.exp(1j * (angles(ring[permutation], center) - want)))
            cost = float((diff ** 2).sum())
            if cost < best_cost:
                best, best_cost = permutation, cost
    return best


def flip_points(points: np.ndarray, width: float) -> np.ndarray:
    """Landmarks (478, 3) de la imagen espejada horizontalmente (ancho [width]):
    x -> width − x y cada punto pasa a su índice espejado. El anillo de cada
    iris se reordena con el patrón angular que tenía ese mismo índice en la
    imagen original (así no importa la convención de numeración del maestro:
    imagen o anatomía)."""
    points = np.asarray(points, dtype=float)
    flipped = points.copy()
    flipped[:, 0] = width - flipped[:, 0]
    out = flipped[mirror_map()]
    for center in IRIS_CENTERS:
        ring = slice(center + 1, center + 1 + IRIS_RING)
        reference = np.vstack([points[center, :2], points[ring, :2]])
        permutation = _ring_permutation(out[center, :2], out[ring, :2], reference)
        out[ring] = out[ring][permutation]
    return out

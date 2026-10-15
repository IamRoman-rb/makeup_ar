"""Geometría compartida del pipeline del modelo propio (fase 3).

Port en Python de lo que hace el tracker del motor, para que las etiquetas
de destilación y la evaluación usen exactamente los mismos recortes:
  - ROI rotado (packages/makeup_engine/.../tracking/roi.cpp);
  - anclas y decodificación de BlazeFace (tracking/blazeface_decoder.cpp);
  - regiones de la malla (labios, ojos, óvalo, iris) leídas como datos de
    third_party/mediapipe_face_geometry/face_mesh_connections.py (regex,
    nunca se ejecuta).

Las constantes (tamaños de entrada, escala del ROI, umbrales) se leen de
engine_config.h: si cambian en el motor, cambian acá.
"""

from __future__ import annotations

import re
from dataclasses import dataclass
from functools import lru_cache
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
ENGINE_CONFIG = ROOT / "packages/makeup_engine/android/src/main/cpp/engine_config.h"
CONNECTIONS = ROOT / "packages/makeup_engine/third_party/mediapipe_face_geometry/face_mesh_connections.py"

LANDMARK_COUNT = 478
MESH_VERTEX_COUNT = 468
# Ángulos externos de los ojos (mesh/canonical_mesh.h: kEyeLeftInImage / kEyeRightInImage).
EYE_LEFT_IN_IMAGE = 33
EYE_RIGHT_IN_IMAGE = 263
IRIS = tuple(range(468, 478))


@lru_cache(maxsize=1)
def engine_constants() -> dict[str, float]:
    text = ENGINE_CONFIG.read_text(encoding="utf-8")
    values = {m.group(1): float(m.group(2)) for m in re.finditer(r"constexpr float (k\w+) = ([0-9.]+)f;", text)}
    values.update({m.group(1): int(m.group(2)) for m in re.finditer(r"constexpr int (k\w+) = (\d+);", text)})
    return values


def _connection_vertices(name: str) -> tuple[int, ...]:
    text = CONNECTIONS.read_text(encoding="utf-8")
    match = re.search(name + r"\s*=\s*frozenset\(\[(.*?)\]\)", text, re.S)
    if match is None:
        raise ValueError(f"{name} no está en {CONNECTIONS.name}")
    pairs = re.findall(r"\((\d+),\s*(\d+)\)", match.group(1))
    return tuple(sorted({int(v) for pair in pairs for v in pair}))


@lru_cache(maxsize=1)
def regions() -> dict[str, tuple[int, ...]]:
    """Índices por región para el NME (las que le importan al maquillaje)."""
    eyes = sorted(set(_connection_vertices("FACEMESH_LEFT_EYE")) | set(_connection_vertices("FACEMESH_RIGHT_EYE")))
    brows = sorted(set(_connection_vertices("FACEMESH_LEFT_EYEBROW")) |
                   set(_connection_vertices("FACEMESH_RIGHT_EYEBROW")))
    return {
        "labios": _connection_vertices("FACEMESH_LIPS"),
        "ojos": tuple(eyes),
        "cejas": tuple(brows),
        "contorno": _connection_vertices("FACEMESH_FACE_OVAL"),
        "iris": IRIS,
        "malla": tuple(range(MESH_VERTEX_COUNT)),
    }


# --- ROI rotado (roi.cpp) ------------------------------------------------------

@dataclass(frozen=True)
class Roi:
    center_x: float
    center_y: float
    size: float      # lado del cuadrado, px de imagen
    rotation: float  # rad; 0 = cara derecha

    @property
    def valid(self) -> bool:
        return self.size > 0.0


def _normalize_radians(angle: float) -> float:
    return angle - 2.0 * np.pi * np.floor((angle + np.pi) / (2.0 * np.pi))


def roi_to_image(roi: Roi, uv: np.ndarray) -> np.ndarray:
    """(…, 2) en [0,1]² del recorte -> px de imagen."""
    uv = np.asarray(uv, dtype=np.float64)
    c, s = np.cos(roi.rotation), np.sin(roi.rotation)
    du = (uv[..., 0] - 0.5) * roi.size
    dv = (uv[..., 1] - 0.5) * roi.size
    return np.stack([roi.center_x + du * c - dv * s, roi.center_y + du * s + dv * c], axis=-1)


def image_to_roi(roi: Roi, xy: np.ndarray) -> np.ndarray:
    xy = np.asarray(xy, dtype=np.float64)
    c, s = np.cos(roi.rotation), np.sin(roi.rotation)
    dx = xy[..., 0] - roi.center_x
    dy = xy[..., 1] - roi.center_y
    return np.stack([(dx * c + dy * s) / roi.size + 0.5, (-dx * s + dy * c) / roi.size + 0.5], axis=-1)


def letterbox_roi(width: float, height: float) -> Roi:
    return Roi(width * 0.5, height * 0.5, float(max(width, height)), 0.0)


def roi_from_points(points: np.ndarray, scale: float, eye_a: int = EYE_LEFT_IN_IMAGE,
                    eye_b: int = EYE_RIGHT_IN_IMAGE) -> Roi:
    """ROI desde los puntos de la malla (sin iris), como el tracker entre frames."""
    points = np.asarray(points, dtype=np.float64)[:, :2]
    a, b = points[eye_a], points[eye_b]
    rotation = float(_normalize_radians(np.arctan2(b[1] - a[1], b[0] - a[0])))
    c, s = np.cos(rotation), np.sin(rotation)
    u = points[:, 0] * c + points[:, 1] * s
    v = -points[:, 0] * s + points[:, 1] * c
    mid_u, mid_v = 0.5 * (u.min() + u.max()), 0.5 * (v.min() + v.max())
    return Roi(float(mid_u * c - mid_v * s), float(mid_u * s + mid_v * c),
               float(max(u.max() - u.min(), v.max() - v.min()) * scale), rotation)


def roi_from_box(x_min: float, y_min: float, width: float, height: float, eye_a, eye_b, scale: float) -> Roi:
    if width <= 0 or height <= 0:
        return Roi(0.0, 0.0, 0.0, 0.0)
    rotation = float(_normalize_radians(np.arctan2(eye_b[1] - eye_a[1], eye_b[0] - eye_a[0])))
    return Roi(x_min + 0.5 * width, y_min + 0.5 * height, max(width, height) * scale, rotation)


def crop(image: np.ndarray, roi: Roi, size: int) -> np.ndarray:
    """Recorte bilineal (size × size) del ROI, con borde negro, como CropPass."""
    import cv2  # solo para el remapeo; OpenCV ya está en las herramientas

    grid = (np.arange(size) + 0.5) / size
    u, v = np.meshgrid(grid, grid)
    xy = roi_to_image(roi, np.stack([u, v], axis=-1)).astype(np.float32)
    return cv2.remap(image, xy[..., 0] - 0.5, xy[..., 1] - 0.5, interpolation=cv2.INTER_LINEAR,
                     borderMode=cv2.BORDER_CONSTANT, borderValue=0)


# --- BlazeFace (blazeface_decoder.cpp) ------------------------------------------

BLAZEFACE_STRIDES = (8, 16, 16, 16)
BLAZEFACE_ANCHORS_PER_LAYER = 2
BLAZEFACE_KEYPOINTS = 6


@lru_cache(maxsize=4)
def blazeface_anchors(input_size: int = 128) -> np.ndarray:
    """(N, 2) centros de las anclas, en el mismo orden que el modelo."""
    out = []
    layer = 0
    while layer < len(BLAZEFACE_STRIDES):
        last = layer
        while last < len(BLAZEFACE_STRIDES) and BLAZEFACE_STRIDES[last] == BLAZEFACE_STRIDES[layer]:
            last += 1
        per_cell = (last - layer) * BLAZEFACE_ANCHORS_PER_LAYER
        grid = (input_size + BLAZEFACE_STRIDES[layer] - 1) // BLAZEFACE_STRIDES[layer]
        for y in range(grid):
            for x in range(grid):
                out.extend([((x + 0.5) / grid, (y + 0.5) / grid)] * per_cell)
        layer = last
    return np.array(out, dtype=np.float64)


@dataclass(frozen=True)
class Detection:
    score: float
    box: tuple[float, float, float, float]  # x_min, y_min, ancho, alto en [0,1] del recorte
    keypoints: np.ndarray                    # (6, 2) en [0,1] del recorte; 0 y 1 = ojos


def decode_blazeface(regressors: np.ndarray, logits: np.ndarray, min_score: float, min_iou: float,
                     input_size: int = 128) -> Detection | None:
    """La mejor cara con NMS ponderado, igual que BlazeFaceDecoder::decode."""
    anchors = blazeface_anchors(input_size)
    raw = np.asarray(regressors, dtype=np.float64).reshape(len(anchors), -1)
    p = 1.0 / (1.0 + np.exp(-np.clip(np.asarray(logits, dtype=np.float64).reshape(-1), -100, 100)))
    best = int(np.argmax(p))
    if p[best] < min_score:
        return None
    scale = 1.0 / input_size
    cx = raw[:, 0] * scale + anchors[:, 0]
    cy = raw[:, 1] * scale + anchors[:, 1]
    w = raw[:, 2] * scale
    h = raw[:, 3] * scale
    boxes = np.stack([cx - 0.5 * w, cy - 0.5 * h, cx + 0.5 * w, cy + 0.5 * h], axis=1)
    bb = boxes[best]
    ix = np.clip(np.minimum(boxes[:, 2], bb[2]) - np.maximum(boxes[:, 0], bb[0]), 0, None)
    iy = np.clip(np.minimum(boxes[:, 3], bb[3]) - np.maximum(boxes[:, 1], bb[1]), 0, None)
    inter = ix * iy
    area = (boxes[:, 2] - boxes[:, 0]) * (boxes[:, 3] - boxes[:, 1])
    iou = np.where(area + area[best] - inter > 0, inter / (area + area[best] - inter), 0.0)
    keep = (p >= min_score) & ((iou >= min_iou) | (np.arange(len(p)) == best))
    weights = p[keep] / p[keep].sum()
    merged = (boxes[keep] * weights[:, None]).sum(axis=0)
    kp_raw = raw[keep, 4:4 + 2 * BLAZEFACE_KEYPOINTS].reshape(-1, BLAZEFACE_KEYPOINTS, 2) * scale
    kp = ((kp_raw + anchors[keep][:, None, :]) * weights[:, None, None]).sum(axis=0)
    return Detection(float(p[best]), (merged[0], merged[1], merged[2] - merged[0], merged[3] - merged[1]), kp)

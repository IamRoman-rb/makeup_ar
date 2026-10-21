"""Entrenamiento del alumno por destilación (fase 3, informe §6.2).

Uso (con datos propios, ver MODEL.md):
  python tools/model/train.py --data ../makeup_data --out ../makeup_runs/r1 --epochs 60 --qat-epochs 8

Pasos:
1. DistillDataset: cuadros etiquetados por teacher_label.py; el recorte sale
   del ROI de los puntos del maestro (como el tracker entre cuadros), con
   jitter de desplazamiento, escala, rotación y color (el tracker nunca centra
   perfecto).
2. Pérdida: Wing (en px del recorte) + forma (largos de las aristas de la
   malla) + presencia (BCE; los negativos son recortes sin cara).
3. Entrenamiento en float y después QAT int8 (fake-quant, FX). La cuantización
   post-entrenamiento suele romper los puntos finos de labios y ojos.

torch.ao.quantization está deprecado a favor de torchao; se usa porque hoy
funciona con la versión instalada. Si se retira, migrar prepare_qat a la
cuantización PT2E de ai-edge-torch (export.py).
"""

from __future__ import annotations

import argparse
import json
import math
import re
import warnings
from functools import lru_cache
from pathlib import Path

import numpy as np
import torch
from torch import nn

from dense import DENSE_POINTS, dense_targets, flip_points
from geometry import CONNECTIONS, MESH_VERTEX_COUNT, Roi, crop, engine_constants, image_to_roi, roi_from_points
from student import INPUT_SIZE, LandmarkStudent

WING_W = 10.0
WING_EPSILON = 2.0
SHAPE_WEIGHT = 0.5
PRESENCE_WEIGHT = 0.1
# Cabezal denso (contornos de labios y ojos, dense.py): mismo Wing en px.
DENSE_WEIGHT = 1.0
# Probabilidad de espejar horizontalmente cada cuadro de entrenamiento.
FLIP_PROBABILITY = 0.5


@lru_cache(maxsize=1)
def mesh_edges() -> torch.Tensor:
    """(E, 2) aristas de la teselación de la malla (datos, por regex)."""
    text = CONNECTIONS.read_text(encoding="utf-8")
    match = re.search(r"FACEMESH_TESSELATION\s*=\s*frozenset\(\[(.*?)\]\)", text, re.S)
    if match is None:
        raise ValueError("FACEMESH_TESSELATION no está en face_mesh_connections.py")
    pairs = sorted({tuple(sorted((int(a), int(b)))) for a, b in re.findall(r"\((\d+),\s*(\d+)\)", match.group(1))})
    return torch.tensor(pairs, dtype=torch.long)


def wing_loss(pred: torch.Tensor, target: torch.Tensor, w: float = WING_W, epsilon: float = WING_EPSILON) -> torch.Tensor:
    """Wing loss (Feng et al. 2018) sobre x, y en px del recorte: más peso a
    los errores chicos que L2, que es lo que se ve en labios y ojos."""
    diff = (pred - target).abs()
    c = w - w * math.log(1.0 + w / epsilon)
    return torch.where(diff < w, w * torch.log1p(diff / epsilon), diff - c).mean()


def shape_loss(pred: torch.Tensor, target: torch.Tensor) -> torch.Tensor:
    """L1 entre los vectores de las aristas de la malla (consistencia de forma)."""
    edges = mesh_edges().to(pred.device)
    pred_vec = pred[:, edges[:, 1], :2] - pred[:, edges[:, 0], :2]
    target_vec = target[:, edges[:, 1], :2] - target[:, edges[:, 0], :2]
    return (pred_vec - target_vec).abs().mean()


def distill_loss(pred: torch.Tensor, presence_logit: torch.Tensor, target: torch.Tensor,
                 has_face: torch.Tensor, pred_dense: torch.Tensor | None = None,
                 target_dense: torch.Tensor | None = None) -> tuple[torch.Tensor, dict[str, float]]:
    """pred/target: (B, 478, 3) en coordenadas del recorte; has_face (B,) 0/1.
    Los puntos solo cuentan en los recortes con cara. pred_dense/target_dense:
    (B, DENSE_POINTS, 2) del cabezal denso, si lo hay."""
    face = has_face > 0.5
    presence = nn.functional.binary_cross_entropy_with_logits(presence_logit, has_face.float())
    dense = pred.sum() * 0.0
    if face.any():
        p = pred[face] * INPUT_SIZE
        t = target[face] * INPUT_SIZE
        wing = wing_loss(p[..., :2], t[..., :2]) + 0.1 * wing_loss(p[..., 2:], t[..., 2:])
        shape = shape_loss(p, t)
        if pred_dense is not None and target_dense is not None:
            dense = wing_loss(pred_dense[face] * INPUT_SIZE, target_dense[face] * INPUT_SIZE)
    else:
        wing = shape = pred.sum() * 0.0
    total = wing + SHAPE_WEIGHT * shape + PRESENCE_WEIGHT * presence + DENSE_WEIGHT * dense
    parts = {"wing": wing.item(), "forma": shape.item(), "presencia": presence.item()}
    if pred_dense is not None:
        parts["denso"] = dense.item()
    return total, parts


# --- Datos -----------------------------------------------------------------------

def jitter_roi(roi: Roi, rng: np.random.Generator, shift: float = 0.06, scale: float = 0.1,
               rotation_deg: float = 10.0) -> Roi:
    c, s = math.cos(roi.rotation), math.sin(roi.rotation)
    du, dv = rng.uniform(-shift, shift, 2) * roi.size
    return Roi(roi.center_x + du * c - dv * s, roi.center_y + du * s + dv * c,
               roi.size * float(rng.uniform(1 - scale, 1 + scale)),
               roi.rotation + math.radians(float(rng.uniform(-rotation_deg, rotation_deg))))


def color_jitter(image: np.ndarray, rng: np.random.Generator) -> np.ndarray:
    """Brillo, contraste, saturación y balance de blancos (luces cálidas y frías)."""
    x = image.astype(np.float32) / 255.0
    x = x * rng.uniform(0.7, 1.3) + rng.uniform(-0.08, 0.08)
    mean = x.mean()
    x = (x - mean) * rng.uniform(0.7, 1.3) + mean
    gray = x.mean(axis=-1, keepdims=True)
    x = gray + (x - gray) * rng.uniform(0.6, 1.4)
    x = x * rng.uniform(0.85, 1.15, 3)
    return np.clip(x, 0.0, 1.0)


def make_sample(image: np.ndarray, points: np.ndarray, rng: np.random.Generator | None, roi_scale: float,
                flip: bool = False, dense: bool = False):
    """(recorte (3, S, S) float [0,1], puntos (478, 3) en coords del recorte)
    y, con [dense], los contornos densos (DENSE_POINTS, 2) en coords del
    recorte. [flip]: espeja la imagen y los puntos (dense.flip_points)."""
    if flip:
        points = flip_points(points, image.shape[1])
        image = np.ascontiguousarray(image[:, ::-1])
    roi = roi_from_points(points[:MESH_VERTEX_COUNT], roi_scale)
    if rng is not None:
        roi = jitter_roi(roi, rng)
    patch = crop(image, roi, INPUT_SIZE)
    pixels = color_jitter(patch, rng) if rng is not None else patch.astype(np.float32) / 255.0
    uv = image_to_roi(roi, points[:, :2])
    target = np.concatenate([uv, points[:, 2:3] / roi.size], axis=-1).astype(np.float32)
    pixels = np.ascontiguousarray(pixels.transpose(2, 0, 1))
    if not dense:
        return pixels, target
    return pixels, target, image_to_roi(roi, dense_targets(points)).astype(np.float32)


class DistillDataset(torch.utils.data.Dataset):
    """Cuadros de teacher_label.py: data/frames/<id>/<n>.jpg y data/labels/<id>.npz
    (frames, points (F, 478, 3) px, presence (F,)). [negatives]: fracción de
    recortes sin cara (un ROI lejos de la cara) para la presencia."""

    def __init__(self, data_root: Path, video_ids: list[str], train: bool, negatives: float = 0.1, seed: int = 0,
                 dense: bool = False, flip: float = FLIP_PROBABILITY):
        import cv2

        self._cv2 = cv2
        self.root = Path(data_root)
        self.train = train
        self.dense = dense
        self.flip = flip if train else 0.0
        self.negatives = negatives
        self.rng = np.random.default_rng(seed)
        self.roi_scale = float(engine_constants()["kRoiScale"])
        self.items = []
        for vid in video_ids:
            labels = np.load(self.root / "labels" / f"{vid}.npz")
            for frame, pts, presence in zip(labels["frames"], labels["points"], labels["presence"]):
                if presence >= engine_constants()["kPresenceThreshold"]:
                    self.items.append((vid, int(frame), pts.astype(np.float32)))

    def __len__(self) -> int:
        return len(self.items)

    def __getitem__(self, index: int):
        vid, frame, points = self.items[index]
        bgr = self._cv2.imread(str(self.root / "frames" / vid / f"{frame}.jpg"))
        image = self._cv2.cvtColor(bgr, self._cv2.COLOR_BGR2RGB)
        rng = self.rng if self.train else None
        has_face = 1.0
        if self.train and self.rng.random() < self.negatives:
            # Negativo: mismo cuadro, ROI corrido más de un lado de la cara.
            far = points.copy()
            far[:, :2] += np.sign(self.rng.uniform(-1, 1, 2)) * (np.ptp(points[:, :2], axis=0) * 1.6)
            points, has_face = far, 0.0
        flip = self.flip > 0.0 and self.rng.random() < self.flip
        sample = make_sample(image, points, rng, self.roi_scale, flip=flip, dense=self.dense)
        tensors = (torch.from_numpy(sample[0]), torch.from_numpy(sample[1]), torch.tensor(has_face))
        return tensors + ((torch.from_numpy(sample[2]),) if self.dense else ())


# --- Entrenamiento ---------------------------------------------------------------

def train_step(model: nn.Module, optimizer: torch.optim.Optimizer, batch) -> dict[str, float]:
    images, targets, has_face = batch[:3]
    target_dense = batch[3] if len(batch) > 3 else None
    model.train()
    outputs = model(images)
    pred, presence = outputs[0], outputs[1]
    pred_dense = outputs[2] if len(outputs) > 2 else None
    loss, parts = distill_loss(pred, presence, targets, has_face, pred_dense, target_dense)
    optimizer.zero_grad(set_to_none=True)
    loss.backward()
    nn.utils.clip_grad_norm_(model.parameters(), 5.0)
    optimizer.step()
    return {"total": loss.item(), **parts}


def prepare_qat(model: nn.Module) -> nn.Module:
    """Inserta fake-quant int8 (QAT) para afinar antes de exportar."""
    from torch.ao.quantization import get_default_qat_qconfig_mapping
    from torch.ao.quantization.quantize_fx import prepare_qat_fx

    model.train()
    with warnings.catch_warnings():
        warnings.simplefilter("ignore", DeprecationWarning)
        warnings.simplefilter("ignore", FutureWarning)
        return prepare_qat_fx(model, get_default_qat_qconfig_mapping("qnnpack"),
                              (torch.zeros(1, 3, INPUT_SIZE, INPUT_SIZE),))


def run(data_root: Path, out: Path, epochs: int, qat_epochs: int, batch_size: int, lr: float, workers: int,
        dense: bool = False, flip: float = FLIP_PROBABILITY) -> None:
    from dataset import load_manifest, load_revoked, split_records, video_id

    records = load_manifest(data_root / "manifest.jsonl", load_revoked(data_root / "revoked.txt"))
    ids = {name: [video_id(r) for r in recs] for name, recs in split_records(records).items()}
    train_set = DistillDataset(data_root, ids["train"], train=True, dense=dense, flip=flip)
    loader = torch.utils.data.DataLoader(train_set, batch_size=batch_size, shuffle=True, num_workers=workers,
                                         drop_last=True)
    model = LandmarkStudent(dense_points=DENSE_POINTS if dense else 0)
    optimizer = torch.optim.AdamW(model.parameters(), lr=lr, weight_decay=1e-4)
    scheduler = torch.optim.lr_scheduler.CosineAnnealingLR(optimizer, T_max=max(1, epochs * len(loader)))
    out.mkdir(parents=True, exist_ok=True)
    log = (out / "log.jsonl").open("a", encoding="utf-8")
    for epoch in range(epochs):
        for step, batch in enumerate(loader):
            parts = train_step(model, optimizer, batch)
            scheduler.step()
            if step % 50 == 0:
                log.write(json.dumps({"fase": "float", "epoch": epoch, "step": step, **parts}) + "\n")
                log.flush()
        torch.save(model.state_dict(), out / "student_float.pt")
    if qat_epochs > 0:
        qat = prepare_qat(model)
        optimizer = torch.optim.AdamW(qat.parameters(), lr=lr * 0.1, weight_decay=1e-4)
        for epoch in range(qat_epochs):
            for step, batch in enumerate(loader):
                parts = train_step(qat, optimizer, batch)
                if step % 50 == 0:
                    log.write(json.dumps({"fase": "qat", "epoch": epoch, "step": step, **parts}) + "\n")
                    log.flush()
            torch.save(qat.state_dict(), out / "student_qat.pt")
    log.close()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--data", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--epochs", type=int, default=60)
    parser.add_argument("--qat-epochs", type=int, default=8)
    parser.add_argument("--batch-size", type=int, default=64)
    parser.add_argument("--lr", type=float, default=2e-3)
    parser.add_argument("--workers", type=int, default=4)
    parser.add_argument("--dense", action="store_true",
                        help="cabezal denso de contornos de labios y ojos (dense.py)")
    parser.add_argument("--flip", type=float, default=FLIP_PROBABILITY,
                        help="probabilidad de espejar cada cuadro (0 = sin espejo)")
    args = parser.parse_args()
    run(args.data, args.out, args.epochs, args.qat_epochs, args.batch_size, args.lr, args.workers,
        dense=args.dense, flip=args.flip)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

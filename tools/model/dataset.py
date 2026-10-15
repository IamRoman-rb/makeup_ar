"""Datos del modelo propio (fase 3): manifiesto, consentimientos y splits.

Nada de esto sale del equipo de entrenamiento ni se versiona: los videos y el
manifiesto viven en una carpeta de datos aparte (por defecto ../makeup_data,
fuera del repo). Ver CONSENT.md antes de grabar a nadie.

Manifiesto: un JSON por línea (JSONL), un video por línea:
  {"video": "s001/neutral_estatico.mp4", "subject": "s001", "consent_id": "C-2026-001",
   "fitzpatrick": 4, "light": "neutral", "static": true}
- video: ruta relativa a la carpeta de datos (sin "..").
- subject: id seudónimo de la persona (nunca el nombre).
- consent_id: id del consentimiento firmado (CONSENT.md). Obligatorio.
- fitzpatrick: 1..6 (autodeclarado), para medir el NME por tono.
- light: una de LIGHTS.
- static: cara quieta (sirve para medir jitter).
Los consentimientos revocados se listan en revoked.txt (un id por línea) y se
excluyen de todo: entrenamiento, validación y etiquetas ya generadas.
"""

from __future__ import annotations

import hashlib
import json
from collections import Counter
from dataclasses import dataclass
from pathlib import Path, PurePosixPath
from typing import Iterator

import numpy as np

LIGHTS = ("neutral", "warm", "cool", "low", "outdoor", "backlight")
SPLITS = ("train", "val", "test")


@dataclass(frozen=True)
class VideoRecord:
    video: str
    subject: str
    consent_id: str
    fitzpatrick: int
    light: str
    static: bool = False


class ManifestError(ValueError):
    pass


def parse_record(raw: dict, line: int = 0) -> VideoRecord:
    def fail(message: str):
        raise ManifestError(f"línea {line}: {message}")

    allowed = {"video", "subject", "consent_id", "fitzpatrick", "light", "static"}
    extra = set(raw) - allowed
    if extra:
        fail(f"claves desconocidas {sorted(extra)}")
    video = raw.get("video")
    if not isinstance(video, str) or not video or PurePosixPath(video).is_absolute() or ".." in PurePosixPath(video).parts:
        fail("video tiene que ser una ruta relativa sin '..'")
    subject = raw.get("subject")
    if not isinstance(subject, str) or not subject:
        fail("falta subject")
    consent = raw.get("consent_id")
    if not isinstance(consent, str) or not consent.strip():
        fail("falta consent_id: sin consentimiento firmado no se usa")
    tone = raw.get("fitzpatrick")
    if not isinstance(tone, int) or isinstance(tone, bool) or not 1 <= tone <= 6:
        fail("fitzpatrick tiene que ser un entero de 1 a 6")
    light = raw.get("light")
    if light not in LIGHTS:
        fail(f"light tiene que ser una de {LIGHTS}")
    static = raw.get("static", False)
    if not isinstance(static, bool):
        fail("static tiene que ser true o false")
    return VideoRecord(video, subject, consent.strip(), tone, light, static)


def load_manifest(path: Path, revoked: set[str] | None = None) -> list[VideoRecord]:
    """Registros válidos sin los consentimientos revocados. Un registro mal
    formado corta la carga (mejor fallar que entrenar con datos dudosos)."""
    revoked = revoked or set()
    out = []
    for number, line in enumerate(Path(path).read_text(encoding="utf-8").splitlines(), start=1):
        if not line.strip():
            continue
        record = parse_record(json.loads(line), number)
        if record.consent_id not in revoked:
            out.append(record)
    return out


def load_revoked(path: Path) -> set[str]:
    path = Path(path)
    if not path.exists():
        return set()
    return {line.strip() for line in path.read_text(encoding="utf-8").splitlines() if line.strip()}


def video_id(record: VideoRecord) -> str:
    """Nombre de archivo de las etiquetas y cuadros de un video."""
    return PurePosixPath(record.video).with_suffix("").as_posix().replace("/", "__")


def split_of(subject: str, val: float = 0.15, test: float = 0.15) -> str:
    """Split determinístico por persona (hash del id): todos los videos de una
    persona caen en el mismo split, así el NME de validación no se infla."""
    h = int.from_bytes(hashlib.sha256(subject.encode("utf-8")).digest()[:8], "big") / 2.0 ** 64
    if h < test:
        return "test"
    if h < test + val:
        return "val"
    return "train"


def split_records(records: list[VideoRecord], val: float = 0.15, test: float = 0.15) -> dict[str, list[VideoRecord]]:
    out: dict[str, list[VideoRecord]] = {name: [] for name in SPLITS}
    for record in records:
        out[split_of(record.subject, val, test)].append(record)
    return out


def coverage(records: list[VideoRecord]) -> dict[str, Counter]:
    """Cuántas personas por tono y por luz: el set tiene que cubrir Fitzpatrick
    1-6 y las luces, o el modelo hereda el sesgo."""
    by_tone: dict[int, set[str]] = {}
    by_light: dict[str, set[str]] = {}
    for r in records:
        by_tone.setdefault(r.fitzpatrick, set()).add(r.subject)
        by_light.setdefault(r.light, set()).add(r.subject)
    return {
        "personas_por_tono": Counter({k: len(v) for k, v in sorted(by_tone.items())}),
        "personas_por_luz": Counter({k: len(v) for k, v in sorted(by_light.items())}),
    }


def iter_frames(video: Path, every: int = 1) -> Iterator[tuple[int, np.ndarray]]:
    """(índice, imagen RGB uint8) de cada [every] cuadros."""
    import cv2

    capture = cv2.VideoCapture(str(video))
    if not capture.isOpened():
        raise FileNotFoundError(video)
    index = 0
    try:
        while True:
            ok, frame = capture.read()
            if not ok:
                break
            if index % every == 0:
                yield index, cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            index += 1
    finally:
        capture.release()

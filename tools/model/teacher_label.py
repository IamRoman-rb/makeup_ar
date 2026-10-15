"""Etiquetas de destilación con el maestro (fase 3, informe §6.1).

El maestro es FaceMesh-V2 (Apache 2.0, el mismo .tflite que usa la app; ver
packages/makeup_engine/third_party/mediapipe_face_landmarker/README.md). Para
cada video del manifiesto (sin consentimientos revocados):
  BlazeFace (letterbox 128) -> ROI de la caja y los ojos -> landmarks (256)
  -> ROI de los puntos -> landmarks otra vez (2 pasadas, como el análisis de
  fotos del motor) -> puntos en px de imagen.
Escribe, solo en la carpeta de datos (nunca en el repo):
  frames/<id>/<n>.jpg  y  labels/<id>.npz (frames, points (F,478,3), presence (F,), rois (F,4)).

Uso:  python tools/model/teacher_label.py --data ../makeup_data --every 3
Necesita ai-edge-litert (tools/model/requirements.txt).
"""

from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np

from dataset import iter_frames, load_manifest, load_revoked, video_id
from geometry import (MESH_VERTEX_COUNT, ROOT, crop, decode_blazeface, engine_constants, letterbox_roi, roi_from_box,
                      roi_from_points, roi_to_image)

MODELS = ROOT / "packages/makeup_engine/android/src/main/assets/makeup_engine/models"


class Teacher:
    def __init__(self):
        from ai_edge_litert.interpreter import Interpreter

        k = engine_constants()
        self.k = k
        self.detector = Interpreter(model_path=str(MODELS / "face_detector.tflite"))
        self.landmarker = Interpreter(model_path=str(MODELS / "face_landmarks_detector.tflite"))
        for interpreter in (self.detector, self.landmarker):
            interpreter.allocate_tensors()

    @staticmethod
    def _outputs(interpreter) -> list[np.ndarray]:
        return [interpreter.get_tensor(d["index"]) for d in interpreter.get_output_details()]

    def detect(self, image: np.ndarray):
        size = int(self.k["kDetectorInputSize"])
        roi = letterbox_roi(image.shape[1], image.shape[0])
        patch = crop(image, roi, size).astype(np.float32) / 127.5 - 1.0  # BlazeFace: [-1, 1]
        self.detector.set_tensor(self.detector.get_input_details()[0]["index"], patch[None])
        self.detector.invoke()
        outputs = self._outputs(self.detector)
        regressors = next(o for o in outputs if o.shape[-1] == 16)
        logits = next(o for o in outputs if o.shape[-1] == 1)
        det = decode_blazeface(regressors, logits, self.k["kDetectorMinScore"], self.k["kDetectorNmsIou"], size)
        if det is None:
            return None
        x0, y0, w, h = det.box
        top_left = roi_to_image(roi, np.array([x0, y0]))
        bottom_right = roi_to_image(roi, np.array([x0 + w, y0 + h]))
        eyes = roi_to_image(roi, det.keypoints[:2])
        return roi_from_box(top_left[0], top_left[1], bottom_right[0] - top_left[0], bottom_right[1] - top_left[1],
                            eyes[0], eyes[1], self.k["kRoiScale"])

    def landmarks(self, image: np.ndarray, roi):
        size = int(self.k["kLandmarkInputSize"])
        patch = crop(image, roi, size).astype(np.float32) / 255.0  # FaceMesh-V2: [0, 1]
        self.landmarker.set_tensor(self.landmarker.get_input_details()[0]["index"], patch[None])
        self.landmarker.invoke()
        outputs = self._outputs(self.landmarker)
        raw = next(o for o in outputs if o.size == 478 * 3).reshape(478, 3)
        logit = float(next(o for o in outputs if o.size == 1).reshape(()))
        xy = roi_to_image(roi, raw[:, :2] / size)
        points = np.concatenate([xy, raw[:, 2:3] * roi.size / size], axis=-1)
        return points, 1.0 / (1.0 + np.exp(-logit))

    def label(self, image: np.ndarray):
        roi = self.detect(image)
        if roi is None or not roi.valid:
            return None
        points, _ = self.landmarks(image, roi)
        roi = roi_from_points(points[:MESH_VERTEX_COUNT], self.k["kRoiScale"])
        points, presence = self.landmarks(image, roi)
        return points, presence, roi


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--data", type=Path, required=True, help="carpeta de datos (fuera del repo)")
    parser.add_argument("--every", type=int, default=3, help="etiquetar 1 de cada N cuadros")
    args = parser.parse_args()
    import cv2

    data = args.data.resolve()
    if ROOT in data.parents or data == ROOT:
        raise SystemExit("la carpeta de datos no puede estar dentro del repo")
    records = load_manifest(data / "manifest.jsonl", load_revoked(data / "revoked.txt"))
    teacher = Teacher()
    (data / "labels").mkdir(exist_ok=True)
    for record in records:
        vid = video_id(record)
        frames_dir = data / "frames" / vid
        frames_dir.mkdir(parents=True, exist_ok=True)
        indices, points, presence, rois = [], [], [], []
        for index, image in iter_frames(data / record.video, args.every):
            result = teacher.label(image)
            if result is None:
                continue
            pts, p, roi = result
            cv2.imwrite(str(frames_dir / f"{index}.jpg"), cv2.cvtColor(image, cv2.COLOR_RGB2BGR),
                        [cv2.IMWRITE_JPEG_QUALITY, 92])
            indices.append(index)
            points.append(pts.astype(np.float32))
            presence.append(p)
            rois.append((roi.center_x, roi.center_y, roi.size, roi.rotation))
        np.savez_compressed(data / "labels" / f"{vid}.npz", frames=np.array(indices), points=np.array(points),
                            presence=np.array(presence, dtype=np.float32), rois=np.array(rois, dtype=np.float32))
        print(f"{vid}: {len(indices)} cuadros etiquetados")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

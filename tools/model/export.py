"""Exportación del alumno a LiteRT (.tflite) para medirlo en el E20.

Uso:  python tools/model/export.py --weights ../makeup_runs/r1/student_float.pt --out student.tflite [--int8]

Usa ai-edge-torch (Apache 2.0), que no está en requirements.txt a propósito:
recién hace falta cuando haya un modelo entrenado. Con --int8 cuantiza con su
flujo PT2E calibrando con recortes del set de validación (--calibration, un
npz con images (N,3,192,192) en [0,1]); la QAT de train.py sirve para elegir
esa cuantización sin perder labios y ojos (comparar NME float vs int8 con
evaluate.py antes de llevarlo al teléfono).

El .tflite resultante tiene la misma salida que espera el tracker si se
reemplaza face_landmarks_detector.tflite: 478 × 3 en px del recorte. Ojo: el
alumno usa 192 px de entrada y FaceMesh-V2 256 (kLandmarkInputSize en
engine_config.h), y la salida va en [0,1]; WrappedForEngine adapta las dos cosas.
"""

from __future__ import annotations

import argparse
from pathlib import Path

import torch
from torch import nn

from student import INPUT_SIZE, LandmarkStudent


class WrappedForEngine(nn.Module):
    """Entrada NHWC [0,1] como la que arma CropPass; salida en px del recorte
    (escala de kLandmarkInputSize) y logit de presencia, como FaceMesh-V2."""

    def __init__(self, student: LandmarkStudent, engine_input: int):
        super().__init__()
        self.student = student
        self.engine_input = engine_input

    def forward(self, image_nhwc: torch.Tensor):
        image = image_nhwc.permute(0, 3, 1, 2)
        if image.shape[-1] != INPUT_SIZE:
            image = nn.functional.interpolate(image, size=(INPUT_SIZE, INPUT_SIZE), mode="bilinear",
                                              align_corners=False)
        points, presence = self.student(image)
        return (points * self.engine_input).reshape(points.shape[0], -1), presence.reshape(-1, 1)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--weights", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--engine-input", type=int, default=256)
    parser.add_argument("--int8", action="store_true")
    parser.add_argument("--calibration", type=Path)
    args = parser.parse_args()
    try:
        import ai_edge_torch
    except ImportError:
        raise SystemExit("falta ai-edge-torch: pip install ai-edge-torch (solo para exportar)")
    student = LandmarkStudent()
    student.load_state_dict(torch.load(args.weights, map_location="cpu"))
    model = WrappedForEngine(student, args.engine_input).eval()
    sample = (torch.zeros(1, args.engine_input, args.engine_input, 3),)
    if args.int8:
        if args.calibration is None:
            raise SystemExit("--int8 necesita --calibration")
        import numpy as np
        from ai_edge_torch.quantize import pt2e_quantizer, quant_config
        from torch.ao.quantization.quantize_pt2e import convert_pt2e, prepare_pt2e

        quantizer = pt2e_quantizer.PT2EQuantizer().set_global(
            pt2e_quantizer.get_symmetric_quantization_config(is_per_channel=True))
        exported = torch.export.export(model, sample).module()
        prepared = prepare_pt2e(exported, quantizer)
        images = np.load(args.calibration)["images"]
        for image in images[:256]:
            prepared(torch.from_numpy(image).permute(1, 2, 0)[None].float())
        model = convert_pt2e(prepared, fold_quantize=False)
        edge = ai_edge_torch.convert(model, sample, quant_config=quant_config.QuantConfig(pt2e_quantizer=quantizer))
    else:
        edge = ai_edge_torch.convert(model, sample)
    edge.export(str(args.out))
    print(f"escrito {args.out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

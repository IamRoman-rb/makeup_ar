"""Evaluación del alumno contra el modelo abierto (criterio de salida §7).

Entradas (npz, todo en px de imagen, mismos cuadros y en el mismo orden):
  --truth    etiquetas a mano del set de validación: points (N,478,2) y
             mask (N,478) con los puntos marcados (no hace falta marcar los 478).
  --teacher  predicciones de FaceMesh-V2 (points (N,478,3)).
  --student  predicciones del alumno (points (N,478,3)).
  --static   opcional: secuencias de cara quieta para el jitter, una clave
             por secuencia con (T,478,3) del alumno y otra "<clave>_teacher".

Sale con código 0 si el alumno cumple NME <= maestro en todas las regiones
marcadas; la latencia p95 se mide aparte en el E20 (lib/main_benchmark.dart).

Uso:  python tools/model/evaluate.py --truth val_truth.npz --teacher val_teacher.npz --student val_student.npz
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np

from metrics import exit_criterion, jitter_px, nme_by_region


def report(truth: dict, teacher: dict, student: dict, static: dict | None = None) -> dict:
    mask = truth.get("mask")
    out = {
        "nme_maestro": nme_by_region(teacher["points"], truth["points"], mask),
        "nme_alumno": nme_by_region(student["points"], truth["points"], mask),
        # Cuánto se aparta el alumno del maestro (destilación), sin etiquetas.
        "nme_alumno_vs_maestro": nme_by_region(student["points"], teacher["points"]),
    }
    out["cumple"] = exit_criterion(out["nme_alumno"], out["nme_maestro"])
    if static:
        out["jitter_px"] = {
            name: {"alumno": jitter_px(seq), "maestro": jitter_px(static[f"{name}_teacher"])}
            for name, seq in static.items() if not name.endswith("_teacher")
        }
    return out


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--truth", type=Path, required=True)
    parser.add_argument("--teacher", type=Path, required=True)
    parser.add_argument("--student", type=Path, required=True)
    parser.add_argument("--static", type=Path)
    args = parser.parse_args()
    load = lambda path: dict(np.load(path))  # noqa: E731
    result = report(load(args.truth), load(args.teacher), load(args.student),
                    load(args.static) if args.static else None)
    print(json.dumps(result, indent=2, ensure_ascii=False))
    return 0 if result["cumple"] and all(result["cumple"].values()) else 1


if __name__ == "__main__":
    raise SystemExit(main())

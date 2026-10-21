"""Vista previa del borde real del labial (opción 3, TRACKER.md §10).

Un labio sintético (elipse) sobre 3 tonos de piel. La malla del tracker está
corrida respecto del labio real: se pasa sobre la piel arriba y no llega
abajo. Por fila: la cámara, el labial con la máscara de la malla (lo de hoy)
y con el borde real (lips.frag: uEdgeRefine, la referencia de
lip_shading.refined_mask). Sirve para ver qué hace antes de probarlo en el
E20; no reemplaza mirarlo en el teléfono.

Uso:  python tools/lips/edge_preview.py  ->  docs/ar_engine/img/lips_edge_preview.png
"""

from __future__ import annotations

import sys
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.path.insert(0, str(ROOT / "tools" / "uv_masks"))
from gen_lips_maps import png_bytes  # noqa: E402
from lip_shading import (LipEdge, LipParams, edge_strength, from_ok, hex_to_srgb, lin_to_srgb, shade,  # noqa: E402
                         srgb_to_oklab)

OUTPUT = ROOT / "docs" / "ar_engine" / "img" / "lips_edge_preview.png"
W, H = 220, 120
GAP = 4
# Tonos de piel (L, croma, tono) como la grilla de calibración; labio natural
# L − 0,07, croma 0,075, 22° (calibration_grid.py, bare_face).
TONES = [(0.80, 0.055, 62.0), (0.66, 0.070, 58.0), (0.45, 0.055, 52.0)]
# Elipse del labio real (px) y corrimiento de la malla: 4 px hacia arriba.
CX, CY, RX, RY = W / 2, H / 2, 70.0, 26.0
MESH_SHIFT = 4.0
# Distancia normalizada del canal B (lips.json: maxDistance 0,008 UV): en esta
# escala ~8 px por unidad (el labio de 140 px ≈ 0,236 UV).
PX_PER_UNIT = 8.0
FEATHER_PX = 2.0


def lch(l: float, c: float, h_deg: float) -> np.ndarray:
    h = np.radians(h_deg)
    return np.array([l, c * np.cos(h), c * np.sin(h)])


def ellipse_distance(x: np.ndarray, y: np.ndarray, cy: float) -> np.ndarray:
    """Distancia aproximada (px, con signo: < 0 adentro) al borde de la elipse."""
    dx = (x - CX) / RX
    dy = (y - cy) / RY
    r = np.sqrt(dx * dx + dy * dy)
    return (r - 1.0) * np.minimum(RX, RY) * 1.6


def scene(tone) -> tuple[np.ndarray, np.ndarray, np.ndarray, float]:
    """(cámara sRGB, máscara de la malla, distancia B, L del labio)."""
    y, x = np.mgrid[0:H, 0:W].astype(float) + 0.5
    skin = lch(*tone)
    lip = lch(tone[0] - 0.07, 0.075, 22.0)
    real = ellipse_distance(x, y, CY)
    t = np.clip(0.5 - real / FEATHER_PX, 0.0, 1.0)[..., None]
    lab = skin * (1 - t) + lip * t
    # Textura suave para que no sea plano.
    lab[..., 0] += 0.01 * np.sin(x / 3.0) * np.cos(y / 4.0)
    camera = lin_to_srgb(np.clip(from_ok(lab), 0.0, 1.0))
    mesh = ellipse_distance(x, y, CY - MESH_SHIFT)
    mask = np.clip(0.5 - mesh / FEATHER_PX, 0.0, 1.0)
    distance = np.abs(mesh) / PX_PER_UNIT
    return camera, mask, distance, float(lip[0])


def main() -> None:
    params = dict(target_lab=srgb_to_oklab(hex_to_srgb("#B3122D")), opacity=0.85, luma_follow=0.8, gloss=0.0,
                  sharpness=2.0, light=1.0)
    rows = []
    for tone in TONES:
        camera, mask, distance, lip_l = scene(tone)
        p = LipParams(lip_lightness=lip_l, **params)
        skin_lab, lip_lab = lch(*tone), lch(tone[0] - 0.07, 0.075, 22.0)
        skin_chroma = skin_lab[1:] / skin_lab[0]
        d = lip_lab[1:] / lip_lab[0] - skin_chroma
        axis = d / np.dot(d, d)
        edge = LipEdge(strength=edge_strength(axis), skin=skin_chroma, axis=axis)
        plain = shade(camera, mask, np.zeros_like(mask), p, distance=distance)
        refined = shade(camera, mask, np.zeros_like(mask), p, edge=edge, distance=distance)
        gap = np.ones((H, GAP, 3))
        rows.append(np.concatenate([camera, gap, plain, gap, refined], axis=1))
    image = np.concatenate([np.concatenate([r, np.ones((GAP, r.shape[1], 3))], axis=0) for r in rows], axis=0)
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_bytes(png_bytes((np.clip(image, 0, 1) * 255).round().astype(np.uint8)))
    print(f"{OUTPUT.relative_to(ROOT)}: cámara | malla (hoy) | borde real, {len(TONES)} tonos")


if __name__ == "__main__":
    main()

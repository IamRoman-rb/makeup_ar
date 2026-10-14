"""Referencia (Python) del render por región que usa el QA automático (F5).

lib/features/studio/domain/recipe_qa.dart calcula, para cada capa de una receta,
el color del píxel medio de su región sobre caras de prueba sintéticas (los
tonos y luces de tools/makeup/calibration_grid.py) con la matemática del motor.
Este script hace lo mismo con las funciones de referencia reales
(lip_shading.shade, face_shading.compose, scene_gain, adapt_oklab) y escribe
test/fixtures/qa_render_cases.json: el test de Dart compara contra ese archivo
(misma idea que recipe_v2_cases.json). Si cambia la matemática de un lado, el
otro falla.

Caras de prueba sintéticas, no fotos: sin dataset ni consentimiento que
gestionar (docs/ar_engine/STUDIO.md, F5).

Uso:
  python tools/studio/qa_reference.py           escribe el fixture
  python tools/studio/qa_reference.py --check   verifica que esté al día
  python tools/studio/qa_reference.py --report  valores de los presets para calibrar
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
for sub in ("tools/makeup", "tools/lips", "tools/uv_masks", "tools/studio"):
    sys.path.insert(0, str(ROOT / sub))
import importlib.util  # noqa: E402

# tools/lips también tiene un calibration_grid.py: se carga el de maquillaje por ruta.
_spec = importlib.util.spec_from_file_location("makeup_calibration_grid", ROOT / "tools/makeup/calibration_grid.py")
_grid = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_grid)
LIGHT_ROWS, SKIN_TONES, engine_constants, lch, presets = (_grid.LIGHT_ROWS, _grid.SKIN_TONES, _grid.engine_constants,
                                                          _grid.lch, _grid.presets)
from face_shading import Layer, adapt_oklab, compose, scene_gain  # noqa: E402
from lip_shading import (GAMUT_EPSILON, LipParams, from_ok, hex_to_srgb, lin_to_srgb,  # noqa: E402
                         shade, srgb_to_oklab, to_ok)

FIXTURE = ROOT / "test/fixtures/qa_render_cases.json"

# Escenas: los 5 tonos con luz neutra y el tono medio con luz cálida y fría.
LIGHTS = {"neutral": None, "warm": LIGHT_ROWS[0][1], "cool": LIGHT_ROWS[1][1]}
SCENES = [(tone, "neutral") for tone in range(len(SKIN_TONES))] + [(2, "warm"), (2, "cool")]
# Rango de sombreado en que se busca hasta dónde el color entra en gamut
# (lips.frag/face.frag: SHADING_MAX = 1,6) y pasos de la búsqueda.
SHADING_MAX = 1.6
SHADING_STEPS = 12
# Labio natural de cada tono (calibration_grid.bare_face).
LIP_DELTA_L, LIP_CHROMA, LIP_HUE = 0.07, 0.075, 22.0
# Fondo gris para la ganancia gray-world de la escena.
BACKGROUND_SRGB = 0.5
LUMINANCE = np.array([0.2126, 0.7152, 0.0722])


def normalized_tint(name: str) -> np.ndarray | None:
    tint = LIGHTS[name]
    return None if tint is None else tint / (tint @ LUMINANCE)


def camera_srgb(lab: np.ndarray, tint: np.ndarray | None) -> np.ndarray:
    linear = from_ok(lab)
    if tint is not None:
        linear = linear * tint
    return lin_to_srgb(np.clip(linear, 0.0, 1.0))


def scene(tone: int, light: str, k: dict) -> dict:
    tint = normalized_tint(light)
    skin_l, skin_c, skin_h = SKIN_TONES[tone]
    gain = None
    if tint is not None:
        background = lin_to_srgb(np.clip(np.full(3, BACKGROUND_SRGB ** 2.2) * tint, 0.0, 1.0))
        gain = scene_gain(background[None, :], k["kLightAdaptDegree"], k["kLightAdaptGainMin"],
                          k["kLightAdaptGainMax"])
    return {
        "skin": camera_srgb(lch(skin_l, skin_c, skin_h), tint),
        "lip": camera_srgb(lch(skin_l - LIP_DELTA_L, LIP_CHROMA, LIP_HUE), tint),
        "gain": gain,
    }


def in_gamut(lab: np.ndarray) -> bool:
    rgb = from_ok(lab)
    return bool(np.all((rgb >= -GAMUT_EPSILON) & (rgb <= 1.0 + GAMUT_EPSILON)))


def max_shading(lab: np.ndarray) -> float:
    """Mayor sombreado s en [1, SHADING_MAX] con color · s todavía en gamut (1 si ya
    sale con s = 1). Más allá el motor baja la croma (oklabToLinearInGamut): si
    sale apenas pasando 1, la mitad iluminada de la región se lava."""
    if not in_gamut(lab):
        return 1.0
    if in_gamut(lab * SHADING_MAX):
        return SHADING_MAX
    lo, hi = 1.0, SHADING_MAX
    for _ in range(SHADING_STEPS):
        mid = 0.5 * (lo + hi)
        if in_gamut(lab * mid):
            lo = mid
        else:
            hi = mid
    return lo


def layers_of(recipe: dict, k: dict):
    """(capa, tipo, color hex, cantidad, lumaFollow, brillo) en el orden del editor (RecipeLayer)."""
    out = []
    lips = recipe.get("lips")
    if lips:
        out.append(("lips", "lips", lips["color"], lips["opacity"], lips.get("lumaFollow", 0.8), 0.0))
        if lips.get("liner"):
            out.append(("lipLiner", "lipLiner", lips["liner"]["color"], lips["liner"]["opacity"], 1.0, 0.0))
    cheeks = recipe.get("cheeks")
    if cheeks:
        out.append(("cheeks", "face", cheeks["color"], cheeks["opacity"], 1.0, 0.0))
    skin = recipe.get("skin", {})
    if "foundation" in skin:
        out.append(("foundation", "face", skin["foundation"]["color"], skin["foundation"]["coverage"], 1.0, 0.0))
    if "contour" in skin:
        out.append(("contour", "face", skin["contour"]["color"], skin["contour"]["opacity"], 1.0, 0.0))
    if "highlight" in skin:
        out.append(("highlight", "face", skin["highlight"]["color"], skin["highlight"]["opacity"],
                    k["kHighlightLumaFollow"], k["kHighlightShine"]))
    eyes = recipe.get("eyes", {})
    if eyes.get("liner"):
        out.append(("eyeLiner", "face", eyes["liner"]["color"], eyes["liner"]["opacity"], 1.0, 0.0))
    for i, shadow in enumerate(eyes.get("shadow", [])[:4]):
        shine = k["kShadowSatinShine"] if shadow.get("finish", "matte") in ("satin", "shimmer") else 0.0
        out.append((f"shadow{i}", "face", shadow["color"], shadow["opacity"], 1.0, shine))
    return out


def render(kind: str, target: np.ndarray, amount: float, luma: float, shine: float, sc: dict,
           recipe: dict, adapt) -> np.ndarray:
    """sRGB del píxel medio de la región (sombreado 1)."""
    if kind == "face":
        lab = to_ok(np.power(sc["skin"], 2.2))
        result, _ = compose(sc["skin"][None, :], [Layer(target, amount, luma_follow=luma, shine=shine)], float(lab[0]))
        return result[0]
    lip_lab = to_ok(np.power(sc["lip"], 2.2))
    lips = recipe["lips"]
    params = LipParams(target_lab=adapt(srgb_to_oklab(hex_to_srgb(lips["color"]))), opacity=lips["opacity"],
                       luma_follow=lips.get("lumaFollow", 0.8), lip_lightness=float(lip_lab[0]), gloss=0.0,
                       sharpness=1.0, light=1.0)
    camera = sc["lip"][None, :]
    if kind == "lips":
        return shade(camera, np.ones(1), np.zeros(1), params)[0]
    # Delineado de labios encima del labial.
    return shade(camera, np.ones(1), np.zeros(1), params, liner=np.full(1, amount), liner_lab=target)[0]


def cases(k: dict, looks: list[dict]) -> list[dict]:
    out = []
    for recipe in looks:
        for tone, light in SCENES:
            sc = scene(tone, light, k)
            gain = sc["gain"]
            adapt = (lambda lab: lab) if gain is None else (lambda lab, g=gain: adapt_oklab(lab, g))
            for name, kind, hex_value, amount, luma, shine in layers_of(recipe, k):
                target = adapt(srgb_to_oklab(hex_to_srgb(hex_value)))
                camera = sc["skin"] if kind == "face" else sc["lip"]
                rendered = render(kind, target, amount, luma, shine, sc, recipe, adapt)
                out.append({
                    "recipe": recipe["name"], "tone": tone, "light": light, "layer": name,
                    "camera": [round(float(v), 6) for v in camera],
                    "out": [round(float(v), 6) for v in rendered],
                    "maxShading": round(max_shading(target), 6),
                })
    return out


def report(k: dict, looks: list[dict]) -> None:
    """ΔE de visibilidad (tono medio, neutra), ΔL en la piel profunda y recorte, por capa."""
    def delta(entry):
        a = to_ok(np.power(np.array(entry["camera"]), 2.2))
        b = to_ok(np.power(np.array(entry["out"]), 2.2))
        return float(np.linalg.norm(a - b)), float(b[0] - a[0])
    by_key = {(c["recipe"], c["tone"], c["light"], c["layer"]): c for c in cases(k, looks)}
    for recipe in looks:
        print(recipe["name"])
        for name, *_ in layers_of(recipe, k):
            mid = by_key[(recipe["name"], 2, "neutral", name)]
            deep = by_key[(recipe["name"], 4, "neutral", name)]
            light = by_key[(recipe["name"], 0, "neutral", name)]
            print(f"  {name:10s} vis={delta(mid)[0]:.3f} deep={delta(deep)[0]:.3f} dL={delta(deep)[1]:+.3f} "
                  f"light={delta(light)[0]:.3f} maxS={mid['maxShading']:.2f}")


def main() -> int:
    k = engine_constants()
    looks = presets()
    if "--report" in sys.argv:
        report(k, looks)
        return 0
    text = json.dumps(cases(k, looks), ensure_ascii=False, indent=1) + "\n"
    if "--check" in sys.argv:
        if not FIXTURE.exists() or FIXTURE.read_text(encoding="utf-8") != text:
            print(f"{FIXTURE.relative_to(ROOT)} desactualizado: correr python tools/studio/qa_reference.py")
            return 1
        print("fixture del QA al día")
        return 0
    FIXTURE.write_text(text, encoding="utf-8", newline="\n")
    print(f"escrito {FIXTURE.relative_to(ROOT)} ({len(json.loads(text))} casos)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

"""Valida sintaxis y tipos de los shaders del motor con glslc (viene con el NDK).

Simula el preprocesado de gl_program.cpp (include de color.glsl y #define
después de #version) y compila cada shader y cada variante con glslc.
Limitaciones, porque glslc apunta a SPIR-V:
  - valida como `#version 310 es` (ES 3.00 no existe para SPIR-V);
  - samplerExternalOES se reemplaza por sampler2D (la extensión OES no está).
No reemplaza probar en el dispositivo: el driver de Mali tiene la última palabra.

Uso:  python tools/shaders/check_shaders.py
glslc se busca en ANDROID_HOME / ANDROID_SDK_ROOT / %LOCALAPPDATA%\\Android\\Sdk (NDK más nuevo
que lo tenga) o en la variable GLSLC.
"""

from __future__ import annotations

import os
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SHADERS = ROOT / "packages/makeup_engine/android/src/main/cpp/shaders"

# Variantes que el Renderer compila con #define (archivo, defines).
VARIANTS = [
    ("crop_roi.frag", "#define TAPS 4\n"),
    ("crop_roi.frag", "#define TAPS 2\n"),
    ("lips.frag", "#define SHIMMER 1\n"),
    ("eyes.frag", "#define SHIMMER 1\n"),
    ("face.frag", "#define EFFECTS 1\n"),
]
INCLUDE_MARKER = "// @include color.glsl"
OES_EXTENSION = "#extension GL_OES_EGL_image_external_essl3 : require"


def find_glslc() -> str:
    explicit = os.environ.get("GLSLC")
    if explicit:
        return explicit
    roots = [os.environ.get("ANDROID_HOME"), os.environ.get("ANDROID_SDK_ROOT")]
    local = os.environ.get("LOCALAPPDATA")
    if local:
        roots.append(str(Path(local) / "Android" / "Sdk"))
    for root in filter(None, roots):
        for ndk in sorted((Path(root) / "ndk").glob("*"), reverse=True):
            for candidate in (ndk / "shader-tools").glob("*/glslc*"):
                return str(candidate)
    sys.exit("no encontré glslc: definí GLSLC o instalá el NDK")


def preprocess(path: Path, defines: str, color: str) -> str:
    text = path.read_text(encoding="utf-8").replace(INCLUDE_MARKER, color)
    text = text.replace("samplerExternalOES", "sampler2D").replace(OES_EXTENSION, "")
    first, rest = text.split("\n", 1)
    if first.strip() != "#version 300 es":
        raise ValueError(f"{path.name}: la primera línea tiene que ser #version 300 es")
    return "#version 310 es\n" + defines + rest


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8")
    glslc = find_glslc()
    color = (SHADERS / "color.glsl").read_text(encoding="utf-8")
    jobs = [(p, "") for p in sorted(SHADERS.glob("*.vert")) + sorted(SHADERS.glob("*.frag"))]
    jobs += [(SHADERS / name, defines) for name, defines in VARIANTS if (SHADERS / name).exists()]
    failures = 0
    with tempfile.TemporaryDirectory() as tmp:
        for path, defines in jobs:
            label = path.name + (f" [{defines.strip()}]" if defines else "")
            source = Path(tmp) / (path.stem + "_" + path.suffix[1:] + ".glsl")
            source.write_text(preprocess(path, defines, color), encoding="utf-8")
            stage = "vert" if path.suffix == ".vert" else "frag"
            result = subprocess.run(
                [glslc, f"-fshader-stage={stage}", "--target-env=opengl", "-fauto-map-locations",
                 "-fauto-bind-uniforms", "-o", str(Path(tmp) / "out.spv"), str(source)],
                capture_output=True, text=True)
            if result.returncode == 0:
                print(f"OK    {label}")
            else:
                failures += 1
                print(f"FALLA {label}\n{result.stderr}")
    print(f"{len(jobs) - failures}/{len(jobs)} shaders válidos")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())

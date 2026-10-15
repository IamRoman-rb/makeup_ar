"""Fuentes del plugin de iOS generadas desde el núcleo de Android (fase 4).

El C++ del motor vive en packages/makeup_engine/android/src/main/cpp y es el
mismo para las dos plataformas. CocoaPods no compila archivos fuera de la
carpeta del pod, así que acá se generan (y se versionan):
  - ios/Classes/core/<ruta>.cpp: un archivo por fuente del núcleo que solo la
    incluye (uno por archivo, no un "unity build": los namespaces anónimos
    de distintos .cpp chocarían);
  - ios/Classes/generated/shader_sources.h: los shaders embebidos, igual que
    el paso de CMake (sin bytes no ASCII).
La lista de fuentes y de shaders sale de CMakeLists.txt: si cambia, regenerar.

Uso:  python tools/ios/gen_ios_sources.py [--check]
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PLUGIN = ROOT / "packages/makeup_engine"
CPP = PLUGIN / "android/src/main/cpp"
CMAKE = CPP / "CMakeLists.txt"
CORE = PLUGIN / "ios/Classes/core"
SHADER_HEADER = PLUGIN / "ios/Classes/generated/shader_sources.h"
# Solo de Android: JNI.
ANDROID_ONLY = {"jni_bridge.cpp"}


def cmake_sources() -> list[str]:
    text = CMAKE.read_text(encoding="utf-8")
    block = re.search(r"add_library\(makeup_engine SHARED(.*?)\)", text, re.S)
    if block is None:
        raise SystemExit("no encontré add_library en CMakeLists.txt")
    return [s for s in block.group(1).split() if s.endswith(".cpp") and s not in ANDROID_ONLY]


def cmake_shaders() -> list[str]:
    text = CMAKE.read_text(encoding="utf-8")
    block = re.search(r"set\(SHADER_FILES(.*?)\)", text, re.S)
    if block is None:
        raise SystemExit("no encontré SHADER_FILES en CMakeLists.txt")
    return [s.replace("${SHADER_DIR}/", "") for s in block.group(1).split()]


def forward_name(source: str) -> str:
    return source.replace("/", "_")


def forward_text(source: str) -> str:
    depth = "../" * 3  # ios/Classes/core -> packages/makeup_engine
    return (
        "// Generado por tools/ios/gen_ios_sources.py. No editar.\n"
        f'#include "{depth}android/src/main/cpp/{source}"\n'
    )


def c_identifier(name: str) -> str:
    return re.sub(r"[^A-Za-z0-9_]", "_", name)


def shader_header() -> str:
    out = ["// Generado por tools/ios/gen_ios_sources.py desde cpp/shaders (como el paso de CMake). No editar.",
           "#pragma once", "", "namespace makeup::shaders {"]
    for name in cmake_shaders():
        # Bytes, no texto: se conserva el fin de línea del checkout, como file(READ) de CMake.
        source = (CPP / "shaders" / name).read_bytes().decode("utf-8")
        source = re.sub(r"[^\t\n\r -~]", "", source).replace("\r\n", "\n")
        out.append(f'inline constexpr char k_{c_identifier(name)}[] = R"GLSL({source})GLSL";')
    out.append("}  // namespace makeup::shaders")
    return "\n".join(out) + "\n"


def outputs() -> dict[Path, str]:
    files = {CORE / forward_name(s): forward_text(s) for s in cmake_sources()}
    files[SHADER_HEADER] = shader_header()
    return files


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true", help="verificar sin escribir")
    args = parser.parse_args()
    files = outputs()
    stale = [p for p in CORE.glob("*.cpp") if p not in files]
    if args.check:
        bad = [p for p, text in files.items()
               if not p.exists() or p.read_text(encoding="utf-8").replace("\r\n", "\n") != text] + stale
        for path in bad:
            print(f"desactualizado: {path.relative_to(ROOT)}")
        if bad:
            print("correr: python tools/ios/gen_ios_sources.py")
            return 1
        print(f"fuentes de iOS al día ({len(files)} archivos)")
        return 0
    for path in stale:
        path.unlink()
    for path, text in files.items():
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8", newline="\n")
    print(f"escritos {len(files)} archivos en {PLUGIN.relative_to(ROOT)}/ios/Classes")
    return 0


if __name__ == "__main__":
    sys.exit(main())

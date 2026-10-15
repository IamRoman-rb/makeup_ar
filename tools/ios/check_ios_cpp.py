"""Verifica que el C++ del plugin de iOS compile, sin una Mac (fase 4).

Compila con el clang del NDK, en modo solo sintaxis y con los mismos -Werror
que Android, cada fuente de packages/makeup_engine/ios/Classes/core más
engine_c_api.cpp, con MAKEUP_PLATFORM_IOS definido y shims de los headers de
Apple (tools/ios/shims: OpenGLES/ES3 -> GLES3 del NDK, os/log.h). Detecta
errores de la rama iOS del núcleo (headers, tipos, sampler 2D, framebuffer
de salida); no reemplaza compilar con Xcode ni probar en un iPhone.

Uso:  python tools/ios/check_ios_cpp.py
"""

from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PLUGIN = ROOT / "packages/makeup_engine"
CLASSES = PLUGIN / "ios/Classes"


def find_clang() -> Path:
    roots = [os.environ.get(k) for k in ("ANDROID_NDK_HOME", "ANDROID_NDK_ROOT")]
    sdk = os.environ.get("ANDROID_HOME") or os.environ.get("ANDROID_SDK_ROOT") or \
        str(Path.home() / "AppData/Local/Android/Sdk")
    candidates = [Path(r) for r in roots if r] + sorted((Path(sdk) / "ndk").glob("*"), reverse=True)
    for ndk in candidates:
        for clang in (ndk / "toolchains/llvm/prebuilt").glob("*/bin/clang++*"):
            if clang.suffix in ("", ".exe"):
                return clang
    raise SystemExit("no encontré el NDK (ANDROID_NDK_HOME o el SDK de Android)")


def main() -> int:
    clang = find_clang()
    sources = sorted((CLASSES / "core").glob("*.cpp")) + [CLASSES / "engine_c_api.cpp"]
    flags = [
        "--target=aarch64-none-linux-android24", "-std=c++17", "-fsyntax-only", "-fno-exceptions", "-fno-rtti",
        "-Wall", "-Wextra", "-Werror", "-DMAKEUP_PLATFORM_IOS=1",
        f"-I{ROOT / 'tools/ios/shims'}", f"-I{PLUGIN / 'android/src/main/cpp'}", f"-I{CLASSES / 'generated'}",
        f"-I{CLASSES}",
    ]
    failed = 0
    for source in sources:
        result = subprocess.run([str(clang), *flags, str(source)], capture_output=True, text=True)
        ok = result.returncode == 0
        failed += not ok
        print(f"{'OK  ' if ok else 'FALLA'} {source.relative_to(PLUGIN)}")
        if not ok:
            print(result.stderr)
    print(f"{len(sources) - failed}/{len(sources)} fuentes de iOS compilan (sintaxis, NDK + shims)")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())

// Shim para compilar la rama iOS con el NDK (tools/ios/check_ios_cpp.py):
// la API de OpenGL ES 3.0 de iOS es la misma que la de GLES3/gl3.h.
#pragma once
#include <GLES3/gl3.h>

// Compilación y enlace de programas GLSL (solo en init, en el hilo de render).
#pragma once

#include <string>

#include "gl_utils.h"

namespace makeup {

// Compila [vertexSource] + [fragmentSource] (con "// @include color.glsl"
// reemplazado) y enlaza. [attributes] se atan en orden a las ubicaciones 0..n-1.
// [fragmentDefines] (p. ej. "#define TAPS 4\n") se inserta después de la línea
// #version del fragment shader. Devuelve un programa vacío y llena [error] si falla.
GlProgram buildGlProgram(const char* vertexSource, const char* fragmentSource,
                         const char* const* attributes, int attributeCount, std::string* error,
                         const char* fragmentDefines = nullptr);

}  // namespace makeup

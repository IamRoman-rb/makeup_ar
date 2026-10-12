#include "gl_program.h"

#include <cstring>

#include "shader_sources.h"

namespace makeup {

namespace {

constexpr char kIncludeMarker[] = "// @include color.glsl";

// Reemplaza el marcador de include por shaders/color.glsl e inserta [defines]
// después de la línea #version (tiene que ser la primera).
std::string preprocess(const char* source, const char* defines) {
  std::string result(source);
  const size_t at = result.find(kIncludeMarker);
  if (at != std::string::npos) {
    result.replace(at, std::strlen(kIncludeMarker), shaders::k_color_glsl);
  }
  if (defines != nullptr) {
    const size_t lineEnd = result.find('\n');
    result.insert(lineEnd == std::string::npos ? result.size() : lineEnd + 1, defines);
  }
  return result;
}

GLuint compileShader(GLenum type, const std::string& source, std::string* error) {
  GLuint shader = glCreateShader(type);
  const char* text = source.c_str();
  glShaderSource(shader, 1, &text, nullptr);
  glCompileShader(shader);
  GLint ok = GL_FALSE;
  glGetShaderiv(shader, GL_COMPILE_STATUS, &ok);
  if (ok != GL_TRUE) {
    GLint length = 0;
    glGetShaderiv(shader, GL_INFO_LOG_LENGTH, &length);
    std::string log(static_cast<size_t>(length > 1 ? length : 1), '\0');
    glGetShaderInfoLog(shader, length, nullptr, log.data());
    *error = std::string(type == GL_VERTEX_SHADER ? "vertex" : "fragment") + " shader: " + log;
    glDeleteShader(shader);
    return 0;
  }
  return shader;
}

}  // namespace

GlProgram buildGlProgram(const char* vertexSource, const char* fragmentSource,
                         const char* const* attributes, int attributeCount, std::string* error,
                         const char* fragmentDefines) {
  GLuint vertex = compileShader(GL_VERTEX_SHADER, preprocess(vertexSource, nullptr), error);
  if (vertex == 0) return GlProgram();
  GLuint fragment =
      compileShader(GL_FRAGMENT_SHADER, preprocess(fragmentSource, fragmentDefines), error);
  if (fragment == 0) {
    glDeleteShader(vertex);
    return GlProgram();
  }
  GlProgram program(glCreateProgram());
  glAttachShader(program.get(), vertex);
  glAttachShader(program.get(), fragment);
  for (int i = 0; i < attributeCount; ++i) {
    glBindAttribLocation(program.get(), static_cast<GLuint>(i), attributes[i]);
  }
  glLinkProgram(program.get());
  glDeleteShader(vertex);
  glDeleteShader(fragment);
  GLint ok = GL_FALSE;
  glGetProgramiv(program.get(), GL_LINK_STATUS, &ok);
  if (ok != GL_TRUE) {
    GLint length = 0;
    glGetProgramiv(program.get(), GL_INFO_LOG_LENGTH, &length);
    std::string log(static_cast<size_t>(length > 1 ? length : 1), '\0');
    glGetProgramInfoLog(program.get(), length, nullptr, log.data());
    *error = "link: " + log;
    return GlProgram();
  }
  MAKEUP_GL_CHECK("buildGlProgram");
  return program;
}

}  // namespace makeup

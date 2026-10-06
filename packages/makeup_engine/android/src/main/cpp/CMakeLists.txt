cmake_minimum_required(VERSION 3.22.1)
project(makeup_engine LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Los shaders viven como archivos .vert/.frag/.glsl (revisables y con sus
# reglas propias) y se embeben en un header generado al configurar.
set(SHADER_DIR ${CMAKE_CURRENT_SOURCE_DIR}/shaders)
set(SHADER_FILES
    ${SHADER_DIR}/color.glsl
    ${SHADER_DIR}/camera_quad.vert
    ${SHADER_DIR}/passthrough.frag
    ${SHADER_DIR}/tint_oklab.frag)
set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS ${SHADER_FILES})

set(GENERATED_DIR ${CMAKE_CURRENT_BINARY_DIR}/generated)
set(SHADER_HEADER_CONTENT "// Generado por CMake desde cpp/shaders. No editar.\n#pragma once\n\nnamespace makeup::shaders {\n")
foreach(SHADER_FILE ${SHADER_FILES})
  get_filename_component(SHADER_NAME ${SHADER_FILE} NAME)
  string(MAKE_C_IDENTIFIER ${SHADER_NAME} SHADER_ID)
  file(READ ${SHADER_FILE} SHADER_SOURCE)
  # Algunos compiladores GLSL de Mali rechazan bytes no ASCII aunque estén en
  # comentarios: los comentarios en español se mantienen en el archivo fuente
  # y se quitan acá, al embeber.
  string(REGEX REPLACE "[^\t\n\r -~]" "" SHADER_SOURCE "${SHADER_SOURCE}")
  string(APPEND SHADER_HEADER_CONTENT "inline constexpr char k_${SHADER_ID}[] = R\"GLSL(${SHADER_SOURCE})GLSL\";\n")
endforeach()
string(APPEND SHADER_HEADER_CONTENT "}  // namespace makeup::shaders\n")
# file(CONFIGURE) solo reescribe si cambió: no fuerza recompilar en cada configure.
file(CONFIGURE OUTPUT ${GENERATED_DIR}/shader_sources.h CONTENT "${SHADER_HEADER_CONTENT}" @ONLY)

add_library(makeup_engine SHARED
    frame_stats.cpp
    jni_bridge.cpp
    renderer.cpp)

target_include_directories(makeup_engine PRIVATE ${CMAKE_CURRENT_SOURCE_DIR} ${GENERATED_DIR})
target_compile_options(makeup_engine PRIVATE -Wall -Wextra -Werror -fno-exceptions -fno-rtti)
target_link_libraries(makeup_engine PRIVATE GLESv3 EGL log)

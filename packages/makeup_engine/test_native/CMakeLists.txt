# Tests de host (PC) del código C++ del motor que no depende de GL ni de
# Android: matemática del tracker. Ver run_host_tests.cmd.
cmake_minimum_required(VERSION 3.22)
project(makeup_engine_host_tests LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(ENGINE_CPP ${CMAKE_CURRENT_SOURCE_DIR}/../android/src/main/cpp)

add_executable(makeup_engine_host_tests
    test_main.cpp
    one_euro_test.cpp
    roi_test.cpp
    umeyama_test.cpp
    blazeface_decoder_test.cpp
    extrapolator_test.cpp
    canonical_mesh_test.cpp
    lips_maps_test.cpp
    appearance_test.cpp
    tracking_state_test.cpp
    ${ENGINE_CPP}/tracking/roi.cpp
    ${ENGINE_CPP}/tracking/umeyama.cpp
    ${ENGINE_CPP}/tracking/blazeface_decoder.cpp
    ${ENGINE_CPP}/tracking/tracking_state.cpp
    ${ENGINE_CPP}/tracking/appearance.cpp)

target_include_directories(makeup_engine_host_tests PRIVATE ${ENGINE_CPP} ${CMAKE_CURRENT_SOURCE_DIR})

if(MSVC)
  # /utf-8: los comentarios están en español.
  target_compile_options(makeup_engine_host_tests PRIVATE /W4 /WX /utf-8 /permissive-)
  target_compile_definitions(makeup_engine_host_tests PRIVATE _USE_MATH_DEFINES _CRT_SECURE_NO_WARNINGS)
else()
  target_compile_options(makeup_engine_host_tests PRIVATE -Wall -Wextra -Werror)
endif()

enable_testing()
add_test(NAME makeup_engine_host_tests COMMAND makeup_engine_host_tests)

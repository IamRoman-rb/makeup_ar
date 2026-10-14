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
    face_maps_test.cpp
    face_style_test.cpp
    appearance_test.cpp
    lip_occlusion_test.cpp
    scene_light_test.cpp
    studio_sampling_test.cpp
    studio_look_test.cpp
    studio_locator_test.cpp
    studio_palette_test.cpp
    tracking_state_test.cpp
    ${ENGINE_CPP}/tracking/roi.cpp
    ${ENGINE_CPP}/tracking/umeyama.cpp
    ${ENGINE_CPP}/tracking/blazeface_decoder.cpp
    ${ENGINE_CPP}/tracking/tracking_state.cpp
    ${ENGINE_CPP}/tracking/appearance.cpp
    ${ENGINE_CPP}/tracking/lip_occlusion.cpp
    ${ENGINE_CPP}/face_style.cpp
    ${ENGINE_CPP}/scene_light.cpp
    ${ENGINE_CPP}/studio/still_image.cpp
    ${ENGINE_CPP}/studio/still_face_locator.cpp
    ${ENGINE_CPP}/studio/uv_rectify.cpp
    ${ENGINE_CPP}/studio/region_sampling.cpp
    ${ENGINE_CPP}/studio/look_analysis.cpp
    ${ENGINE_CPP}/studio/palette.cpp)

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

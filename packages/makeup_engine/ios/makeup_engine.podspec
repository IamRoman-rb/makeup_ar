#
# Plugin makeup_engine para iOS (fase 4; docs/ar_engine/IOS.md).
#
# El C++ del motor es el mismo de Android (android/src/main/cpp): Classes/core
# tiene un .cpp por fuente que solo la incluye y Classes/generated el header de
# shaders; los genera tools/ios/gen_ios_sources.py (CocoaPods no compila
# archivos fuera de la carpeta del pod). Gráficos: OpenGL ES 3 de EAGL
# (deprecado por Apple pero soportado), así el núcleo y los shaders son los
# mismos. Inferencia: TensorFlowLiteSwift (LiteRT, Apache 2.0) con Metal.
#
Pod::Spec.new do |s|
  s.name             = 'makeup_engine'
  s.version          = '0.1.0'
  s.summary          = 'Motor AR de maquillaje propio (cámara -> OpenGL ES 3 -> Texture).'
  s.homepage         = 'https://github.com/IamRoman-rb/makeup_ar'
  s.license          = { :type => 'Propietaria' }
  s.author           = { 'makeup_ar' => 'roman.borla2004@gmail.com' }
  s.source           = { :path => '.' }
  s.platform         = :ios, '13.0'
  s.swift_version    = '5.0'

  s.source_files        = 'Classes/**/*.{swift,h,cpp}'
  s.public_header_files = 'Classes/engine_c_api.h'
  s.dependency 'Flutter'
  s.dependency 'TensorFlowLiteSwift', '~> 2.17.0'
  s.dependency 'TensorFlowLiteSwift/Metal', '~> 2.17.0'
  s.frameworks = 'AVFoundation', 'CoreMedia', 'CoreVideo', 'OpenGLES', 'UIKit'
  s.libraries  = 'c++'

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'CLANG_CXX_LANGUAGE_STANDARD' => 'c++17',
    'GCC_PREPROCESSOR_DEFINITIONS' => '$(inherited) GLES_SILENCE_DEPRECATION=1',
    'OTHER_CPLUSPLUSFLAGS' => '$(inherited) -fno-exceptions -fno-rtti',
    'HEADER_SEARCH_PATHS' => '$(inherited) "${PODS_TARGET_SRCROOT}/../android/src/main/cpp" ' \
                             '"${PODS_TARGET_SRCROOT}/Classes/generated"',
    # Flutter no publica arm64 para el simulador en todas las versiones.
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
  }

  # Los modelos son los mismos .tflite de Android (Apache 2.0, ver
  # third_party/mediapipe_face_landmarker): se copian al bundle del pod al
  # compilar, sin duplicarlos en el repo.
  s.script_phase = {
    :name => 'Copiar modelos de MediaPipe',
    :execution_position => :before_compile,
    :input_files => [
      '${PODS_TARGET_SRCROOT}/../android/src/main/assets/makeup_engine/models/face_detector.tflite',
      '${PODS_TARGET_SRCROOT}/../android/src/main/assets/makeup_engine/models/face_landmarks_detector.tflite',
    ],
    :output_files => [
      '${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/face_detector.tflite',
      '${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/face_landmarks_detector.tflite',
    ],
    :script => 'set -e
mkdir -p "${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}"
cp "${PODS_TARGET_SRCROOT}/../android/src/main/assets/makeup_engine/models/"*.tflite "${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/"',
  }
end

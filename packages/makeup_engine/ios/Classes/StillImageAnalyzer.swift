import Foundation
import UIKit

/// Studio (F4): analiza una foto en el teléfono. Port de StillImageAnalyzer.kt.
/// Nada sale del dispositivo y la foto no se guarda: se decodifica, se mide y
/// se descarta; a Dart solo vuelven números.
///
/// Bloqueante: el plugin lo corre en su propia cola de fondo. Los modelos se
/// cargan en CPU (no compiten con la sesión de cámara por la GPU) y se liberan
/// al terminar. Con [cameraActive], un solo hilo de inferencia.
final class StillImageAnalyzer {
  // Lado de la foto para la paleta: 4× la miniatura (kPaletteMaxSide = 96).
  private static let paletteDecodeSide = 384

  private let cameraActive: Bool
  private let maxSide: Int
  private let detectorSize: Int
  private let landmarkSize: Int
  private let lookValueCount: Int

  init(cameraActive: Bool) {
    self.cameraActive = cameraActive
    var config = [Int32](repeating: 0, count: Int(MAKEUP_CONFIG_COUNT))
    makeup_get_config(&config, Int32(config.count))
    maxSide = Int(config[Int(MAKEUP_CONFIG_STILL_MAX_SIDE)])
    detectorSize = Int(config[Int(MAKEUP_CONFIG_DETECTOR_INPUT_SIZE)])
    landmarkSize = Int(config[Int(MAKEUP_CONFIG_LANDMARK_INPUT_SIZE)])
    lookValueCount = Int(config[Int(MAKEUP_CONFIG_LOOK_VALUE_COUNT)])
  }

  /// Medidas del look, o nil si la foto no se pudo leer.
  func analyzeFace(_ data: Data) throws -> [Float]? {
    guard let pixels = StillImageAnalyzer.decode(data, maxSide: maxSide) else { return nil }
    let still = pixels.rgba.withUnsafeBufferPointer {
      makeup_still_create($0.baseAddress, Int32(pixels.width), Int32(pixels.height))
    }
    guard let handle = still else { return nil }
    defer { makeup_still_destroy(handle) }
    let threads = cameraActive ? 1 : 2
    var detector: ModelRunner?
    var landmarker: ModelRunner?
    loop: while true {
      switch makeup_still_step(handle) {
      case EngineConst.stillDetector:
        let model = try detector ?? ModelRunner(name: ModelRunner.detectorName, threads: threads, preferGpu: false)
        detector = model
        try runDetector(handle, model)
      case EngineConst.stillLandmarks:
        let model = try landmarker ?? ModelRunner(name: ModelRunner.landmarksName, threads: threads, preferGpu: false)
        landmarker = model
        try runLandmarks(handle, model)
      default:
        break loop
      }
    }
    var values = [Float](repeating: 0, count: lookValueCount)
    makeup_still_analyze(handle, &values, Int32(values.count))
    return values
  }

  /// Paleta (r, g, b, fracción por swatch), o nil si la foto no se pudo leer.
  func palette(_ data: Data) -> [Float]? {
    guard let pixels = StillImageAnalyzer.decode(data, maxSide: StillImageAnalyzer.paletteDecodeSide) else {
      return nil
    }
    var out = [Float](repeating: 0, count: 64)
    let written = pixels.rgba.withUnsafeBufferPointer {
      makeup_still_palette($0.baseAddress, Int32(pixels.width), Int32(pixels.height), &out, Int32(out.count))
    }
    return Array(out.prefix(Int(written)))
  }

  private func runDetector(_ handle: OpaquePointer, _ model: ModelRunner) throws {
    var input = [Float](repeating: 0, count: detectorSize * detectorSize * 3)
    // BlazeFace espera la imagen en [-1, 1] (igual que el tracker).
    let filled = input.withUnsafeMutableBufferPointer {
      makeup_still_fill_input(handle, $0.baseAddress, Int32($0.count), 2, -1)
    }
    guard filled else {
      makeup_still_fail(handle, EngineConst.stillStatusBadImage)
      return
    }
    let outputs = try input.withUnsafeBufferPointer { try model.run($0) }
    guard let split = ModelRunner.splitDetections(outputs) else {
      makeup_still_fail(handle, EngineConst.stillStatusBadImage)
      return
    }
    split.regressors.withUnsafeBufferPointer { r in
      split.scores.withUnsafeBufferPointer { s in
        makeup_still_submit_detections(handle, r.baseAddress, Int32(r.count), s.baseAddress, Int32(s.count))
      }
    }
  }

  private func runLandmarks(_ handle: OpaquePointer, _ model: ModelRunner) throws {
    var input = [Float](repeating: 0, count: landmarkSize * landmarkSize * 3)
    // FaceMesh-V2 espera la imagen en [0, 1].
    let filled = input.withUnsafeMutableBufferPointer {
      makeup_still_fill_input(handle, $0.baseAddress, Int32($0.count), 1, 0)
    }
    guard filled else {
      makeup_still_fail(handle, EngineConst.stillStatusBadImage)
      return
    }
    let outputs = try input.withUnsafeBufferPointer { try model.run($0) }
    let split = ModelRunner.splitLandmarks(outputs)
    split.landmarks.withUnsafeBufferPointer {
      makeup_still_submit_landmarks(handle, $0.baseAddress, Int32($0.count), split.presenceLogit)
    }
  }

  struct Pixels {
    let rgba: [UInt8]
    let width: Int
    let height: Int
  }

  /// JPEG/PNG/HEIC -> RGBA8 derecho (orientación EXIF aplicada, como en
  /// Android) con el lado mayor <= [maxSide]. nil si no se puede decodificar.
  static func decode(_ data: Data, maxSide: Int) -> Pixels? {
    guard let image = UIImage(data: data), image.size.width > 0, image.size.height > 0 else { return nil }
    let longSide = max(image.size.width, image.size.height)
    let scale = longSide <= CGFloat(maxSide) ? 1 : CGFloat(maxSide) / longSide
    let width = max(1, Int((image.size.width * scale).rounded()))
    let height = max(1, Int((image.size.height * scale).rounded()))
    var rgba = [UInt8](repeating: 0, count: width * height * 4)
    let drawn: Bool = rgba.withUnsafeMutableBytes { bytes in
      guard let context = CGContext(
        data: bytes.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
        return false
      }
      // UIImage.draw aplica la orientación; el contexto de CG tiene el origen
      // abajo: se invierte para que la fila 0 sea la de arriba.
      UIGraphicsPushContext(context)
      context.translateBy(x: 0, y: CGFloat(height))
      context.scaleBy(x: 1, y: -1)
      image.draw(in: CGRect(x: 0, y: 0, width: width, height: height))
      UIGraphicsPopContext()
      return true
    }
    return drawn ? Pixels(rgba: rgba, width: width, height: height) : nil
  }
}

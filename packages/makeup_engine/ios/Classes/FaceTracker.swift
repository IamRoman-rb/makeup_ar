import Foundation
import TensorFlowLite

/// Un modelo .tflite cargado (BlazeFace o FaceMesh-V2), en Metal o en CPU.
/// Port de la carga de LiteRtFaceTracker.kt / StillImageAnalyzer.kt.
final class ModelRunner {
  static let detectorName = "face_detector"
  static let landmarksName = "face_landmarks_detector"

  let backend: String
  private let interpreter: Interpreter

  /// [preferGpu]: Metal y, si falla, CPU con [threads] hilos.
  init(name: String, threads: Int, preferGpu: Bool) throws {
    guard let path = Bundle(for: ModelRunner.self).path(forResource: name, ofType: "tflite") else {
      throw EngineError(code: "models_missing", message: "falta \(name).tflite en el bundle del plugin")
    }
    var options = Interpreter.Options()
    options.threadCount = threads
    if preferGpu {
      // Si Metal falla al crear o al reservar los tensores, CPU (como Android).
      do {
        let gpu = try Interpreter(modelPath: path, options: options, delegates: [MetalDelegate()])
        try gpu.allocateTensors()
        interpreter = gpu
        backend = "gpu"
        return
      } catch {
        NSLog("makeup_tracker: \(name) en Metal falló, uso CPU: \(error)")
      }
    }
    interpreter = try Interpreter(modelPath: path, options: options)
    try interpreter.allocateTensors()
    backend = "cpu"
  }

  /// Corre el modelo con [input] (NHWC float) y devuelve todas las salidas.
  func run(_ input: UnsafeBufferPointer<Float>) throws -> [[Float]] {
    try interpreter.copy(Data(buffer: input), toInputAt: 0)
    try interpreter.invoke()
    return try (0..<interpreter.outputTensorCount).map { index in
      let data = try interpreter.output(at: index).data
      return data.withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }
    }
  }

  /// BlazeFace: regressors (896×16) es la salida grande; classificators (896), la chica.
  static func splitDetections(_ outputs: [[Float]]) -> (regressors: [Float], scores: [Float])? {
    guard outputs.count >= 2 else { return nil }
    let first = outputs[0]
    let second = outputs[1]
    return first.count >= second.count ? (first, second) : (second, first)
  }

  /// FaceMesh-V2: la salida más grande son los puntos; la de tamaño 1, la presencia.
  static func splitLandmarks(_ outputs: [[Float]]) -> (landmarks: [Float], presenceLogit: Float) {
    var landmarks: [Float] = []
    var presence = -Float.infinity
    for values in outputs {
      if values.count > landmarks.count {
        landmarks = values
      } else if values.count == 1 && presence == -Float.infinity {
        presence = values[0]
      }
    }
    return (landmarks, presence)
  }
}

extension NSLock {
  /// Como withLock (iOS 16+), para versiones anteriores.
  func sync<T>(_ body: () throws -> T) rethrows -> T {
    lock()
    defer { unlock() }
    return try body()
  }
}

struct EngineError: Error {
  let code: String
  let message: String
}

/// Tracker de la sesión en vivo: port de LiteRtFaceTracker.kt.
///
/// Cola serie "makeup-tracker": carga, inferencia y liberación. El núcleo C++
/// pide recortes; acá solo se convierten a tensor (en C++), se infiere y se
/// devuelven las salidas. Por inferencia se alocan las salidas (API de
/// TensorFlowLite): se acepta porque es esta cola, no la de render.
final class FaceTracker {
  private let queue = DispatchQueue(label: "makeup-tracker", qos: .userInitiated)
  private let engine: OpaquePointer
  private let detectorSize: Int
  private let landmarkSize: Int

  // Solo cola del tracker.
  private var detectorInput: [Float]
  private var landmarkInput: [Float]
  private var detector: ModelRunner?
  private var landmarker: ModelRunner?
  private var enabled = false
  private var running = false
  private var consecutiveErrors = 0
  private static let maxConsecutiveErrors = 5

  private let lock = NSLock()
  private var releasedFlag = false
  private var _backend: String?
  private var _error: String?
  private var _initMs = Double.nan

  init(engine: OpaquePointer, config: [Int32]) {
    self.engine = engine
    let detector = Int(config[Int(MAKEUP_CONFIG_DETECTOR_INPUT_SIZE)])
    let landmarks = Int(config[Int(MAKEUP_CONFIG_LANDMARK_INPUT_SIZE)])
    detectorSize = detector
    landmarkSize = landmarks
    detectorInput = [Float](repeating: 0, count: detector * detector * 3)
    landmarkInput = [Float](repeating: 0, count: landmarks * landmarks * 3)
  }

  var backend: String? { lock.sync { _backend } }
  var error: String? { lock.sync { _error } }
  var initMs: Double { lock.sync { _initMs } }
  private var released: Bool { lock.sync { releasedFlag } }

  private func setError(_ message: String?) { lock.sync { _error = message } }

  func start() { queue.async { self.load() } }

  /// Hilo de render: sin allocations (un bloque por recorte, como el Runnable de Android).
  func onCropReady() { queue.async { self.process() } }

  func setEnabled(_ value: Bool) {
    queue.async {
      self.enabled = value
      self.syncRunning()
    }
  }

  func release(_ onReleased: @escaping () -> Void) {
    lock.sync { releasedFlag = true }
    queue.async {
      if self.running { makeup_tracker_stop(self.engine) }
      self.running = false
      self.detector = nil
      self.landmarker = nil
      DispatchQueue.main.async(execute: onReleased)
    }
  }

  private func load() {
    if released { return }
    let start = DispatchTime.now().uptimeNanoseconds
    do {
      detector = try ModelRunner(name: ModelRunner.detectorName, threads: 2, preferGpu: true)
      landmarker = try ModelRunner(name: ModelRunner.landmarksName, threads: 2, preferGpu: true)
      let ms = Double(DispatchTime.now().uptimeNanoseconds - start) / 1e6
      lock.sync {
        _initMs = ms
        _backend = "detector=\(detector?.backend ?? "-") landmarks=\(landmarker?.backend ?? "-")"
      }
      syncRunning()
    } catch let error as EngineError {
      setError("no se pudieron cargar los modelos: \(error.message)")
    } catch {
      setError("no se pudieron cargar los modelos: \(error)")
    }
  }

  private func syncRunning() {
    if released || detector == nil || landmarker == nil { return }
    if enabled && !running {
      makeup_tracker_start(engine)
      running = true
    } else if !enabled && running {
      makeup_tracker_stop(engine)
      running = false
    }
  }

  private func process() {
    if released || !running { return }
    do {
      let ok: Bool
      switch makeup_tracker_ready_kind(engine) {
      case EngineConst.cropDetector: ok = try runDetector()
      case EngineConst.cropLandmarks: ok = try runLandmarks()
      default: ok = true
      }
      if !ok {
        // Sin esto el recorte quedaría tomado y el ciclo, trabado para siempre.
        makeup_tracker_abort(engine)
        setError("el recorte no coincide con la entrada del modelo")
        return
      }
      if consecutiveErrors > 0 { setError(nil) }
      consecutiveErrors = 0
    } catch {
      // El recorte quedó tomado: reiniciar el ciclo (vuelve a buscar la cara).
      setError("inferencia: \(error)")
      makeup_tracker_stop(engine)
      consecutiveErrors += 1
      if consecutiveErrors < FaceTracker.maxConsecutiveErrors {
        makeup_tracker_start(engine)
      } else {
        running = false
      }
    }
  }

  private func runDetector() throws -> Bool {
    guard let model = detector else { return false }
    let start = DispatchTime.now().uptimeNanoseconds
    // BlazeFace espera la imagen en [-1, 1].
    let filled = detectorInput.withUnsafeMutableBufferPointer {
      makeup_tracker_fill_input(engine, $0.baseAddress, Int32($0.count), 2, -1)
    }
    if !filled { return false }
    let outputs = try detectorInput.withUnsafeBufferPointer { try model.run($0) }
    guard let split = ModelRunner.splitDetections(outputs) else { return false }
    let ms = Float(DispatchTime.now().uptimeNanoseconds - start) / 1e6
    split.regressors.withUnsafeBufferPointer { r in
      split.scores.withUnsafeBufferPointer { s in
        makeup_tracker_submit_detections(engine, r.baseAddress, Int32(r.count), s.baseAddress, Int32(s.count), ms)
      }
    }
    return true
  }

  private func runLandmarks() throws -> Bool {
    guard let model = landmarker else { return false }
    let start = DispatchTime.now().uptimeNanoseconds
    // FaceMesh-V2 espera la imagen en [0, 1].
    let filled = landmarkInput.withUnsafeMutableBufferPointer {
      makeup_tracker_fill_input(engine, $0.baseAddress, Int32($0.count), 1, 0)
    }
    if !filled { return false }
    let outputs = try landmarkInput.withUnsafeBufferPointer { try model.run($0) }
    let split = ModelRunner.splitLandmarks(outputs)
    let ms = Float(DispatchTime.now().uptimeNanoseconds - start) / 1e6
    split.landmarks.withUnsafeBufferPointer {
      makeup_tracker_submit_landmarks(engine, $0.baseAddress, Int32($0.count), split.presenceLogit, ms)
    }
    return true
  }
}

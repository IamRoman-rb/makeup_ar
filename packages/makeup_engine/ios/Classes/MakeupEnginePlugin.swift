import Flutter
import Foundation

/// Canal `makeup_engine` en iOS (port de MakeupEnginePlugin.kt). Métodos:
/// start, stop, setTint, setRecipe, setRenderOptions, getStats, resetStats,
/// analyzeFaceImage y extractPalette. runBenchmark no está en iOS (el
/// benchmark del E20 es de Android). Una sola sesión a la vez. Contrato en
/// lib/makeup_engine.dart.
public final class MakeupEnginePlugin: NSObject, FlutterPlugin {
  private let textures: FlutterTextureRegistry
  private var session: EngineSession?
  // Un análisis de foto a la vez, en orden, en segundo plano (F4).
  private let stillQueue = DispatchQueue(label: "makeup-still", qos: .utility)

  init(textures: FlutterTextureRegistry) {
    self.textures = textures
    super.init()
  }

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "makeup_engine", binaryMessenger: registrar.messenger())
    let instance = MakeupEnginePlugin(textures: registrar.textures())
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func detachFromEngine(for registrar: FlutterPluginRegistrar) {
    session?.release()
    session = nil
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "start":
      start(result)
    case "stop":
      session?.release()
      session = nil
      result(nil)
    case "setTint":
      session?.setTint(r: float(args["r"]), g: float(args["g"]), b: float(args["b"]), amount: float(args["amount"]))
      result(nil)
    case "setRecipe":
      session?.setRecipe(args["recipe"] as? [String: Any])
      result(nil)
    case "setRenderOptions":
      session?.setRenderOptions(
        showLandmarks: args["showLandmarks"] as? Bool ?? false,
        region: Int32(args["region"] as? Int ?? Int(EngineConst.regionFull)),
        lightAdaptation: args["lightAdaptation"] as? Bool ?? true)
      result(nil)
    case "getStats":
      result(session?.stats())
    case "resetStats":
      session?.resetStats()
      result(nil)
    case "runBenchmark":
      result(FlutterError(code: "unsupported", message: "El benchmark de modelos solo existe en Android", details: nil))
    case "analyzeFaceImage":
      analyzeStill(args, result) { analyzer, data in try analyzer.analyzeFace(data) }
    case "extractPalette":
      analyzeStill(args, result) { analyzer, data in analyzer.palette(data) }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func start(_ result: @escaping FlutterResult) {
    if session != nil {
      result(FlutterError(code: "already_started", message: "Ya hay una sesión activa: llamá a stop() primero",
                          details: nil))
      return
    }
    let newSession = EngineSession(registry: textures)
    session = newSession
    newSession.start { [weak self] outcome in
      switch outcome {
      case .success(let info):
        result([
          "textureId": info.textureId,
          "width": info.width,
          "height": info.height,
          "previewWidth": info.previewWidth,
          "previewHeight": info.previewHeight,
          // Informativos: el buffer ya llega vertical y sin espejo.
          "sensorOrientation": 0,
          "rotationDegrees": 0,
          "fpsMin": info.fps,
          "fpsMax": info.fps,
          "glInfo": info.glInfo,
        ])
      case .failure(let error):
        newSession.release()
        if self?.session === newSession { self?.session = nil }
        result(FlutterError(code: error.code, message: error.message, details: nil))
      }
    }
  }

  /// Foto (bytes) -> números en la cola de fondo. Responde [Double];
  /// "bad_image" si no se pudo decodificar.
  private func analyzeStill(_ args: [String: Any], _ result: @escaping FlutterResult,
                            _ work: @escaping (StillImageAnalyzer, Data) throws -> [Float]?) {
    guard let bytes = args["bytes"] as? FlutterStandardTypedData, !bytes.data.isEmpty else {
      result(FlutterError(code: "bad_image", message: "Faltan los bytes de la foto", details: nil))
      return
    }
    let analyzer = StillImageAnalyzer(cameraActive: session != nil)
    stillQueue.async {
      let outcome: Result<[Float]?, Error> = Result { try work(analyzer, bytes.data) }
      DispatchQueue.main.async {
        switch outcome {
        case .success(let values?):
          result(values.map { Double($0) })
        case .success(nil):
          result(FlutterError(code: "bad_image", message: "No se pudo leer la foto", details: nil))
        case .failure(let error):
          result(FlutterError(code: "analysis_failed", message: "\(error)", details: nil))
        }
      }
    }
  }

  private func float(_ value: Any?) -> Float {
    (value as? NSNumber)?.floatValue ?? 0
  }
}

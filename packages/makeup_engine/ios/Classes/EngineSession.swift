import AVFoundation
import CoreVideo
import Flutter
import Foundation
import OpenGLES

/// Una sesión cámara -> OpenGL ES 3 -> Texture de Flutter: port de
/// EngineSession.kt para iOS (docs/ar_engine/IOS.md).
///
/// Colas:
///  - main: start/release/stats y el registro de la textura.
///  - "makeup-render" (serie): dueña del EAGLContext. AVFoundation entrega
///    cada frame acá; se dibuja y se recorta la cara para el tracker.
///  - "makeup-tracker": inferencia (FaceTracker).
/// Dart no cruza por frame.
///
/// Salida: el núcleo dibuja en un FBO propio (como en Android, fila 0 abajo)
/// y se copia invertido con glBlitFramebuffer a uno de tres CVPixelBuffer que
/// lee Flutter (fila 0 arriba). Así el núcleo y Dart son los mismos que en Android.
final class EngineSession: NSObject, FlutterTexture, AVCaptureVideoDataOutputSampleBufferDelegate {
  struct StartInfo {
    let textureId: Int64
    let width: Int
    let height: Int
    let previewWidth: Int
    let previewHeight: Int
    let fps: Int
    let glInfo: String
  }

  private static let outputBufferCount = 3
  // GL_BGRA (APPLE/EXT): formato de los CVPixelBuffer de cámara y de salida.
  private static let glBgra = GLenum(0x80E1)
  // El buffer de cámara llega derecho (fila 0 arriba): misma convención que la
  // matriz de SurfaceTexture en Android (v invertida). Column-major.
  private static let texMatrix: [Float] = [1, 0, 0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 0, 1, 0, 1]

  private let registry: FlutterTextureRegistry
  private let renderQueue = DispatchQueue(label: "makeup-render", qos: .userInteractive)
  private let cameraControlQueue = DispatchQueue(label: "makeup-camera")
  private let config: [Int32]
  private let engine: OpaquePointer
  private let tracker: FaceTracker
  private let captureSession = AVCaptureSession()

  // Solo cola de render.
  private var context: EAGLContext?
  private var textureCache: CVOpenGLESTextureCache?
  private var renderFramebuffer: GLuint = 0
  private var renderTexture: GLuint = 0
  private var outputs: [(buffer: CVPixelBuffer, texture: CVOpenGLESTexture, framebuffer: GLuint)] = []
  private var nextOutput = 0
  private var width = 0
  private var height = 0
  private var lastTimestampNs: Int64 = .min

  // Último buffer terminado (copyPixelBuffer lo lee desde el hilo de Flutter).
  private let latestLock = NSLock()
  private var latest: CVPixelBuffer?

  // Solo main.
  private var textureId: Int64 = -1
  private var trackerLoading = false
  private var renderReleased = false
  private var trackerReleased = false
  private var statsBuffer: [Float]
  private var trackerStatsBuffer: [Float]
  private var startInfo: StartInfo?

  private let stateLock = NSLock()
  private var releasedFlag = false
  private var lastErrorValue: String?
  private var released: Bool { stateLock.sync { releasedFlag } }
  private var lastError: String? {
    get { stateLock.sync { lastErrorValue } }
    set { stateLock.sync { lastErrorValue = newValue } }
  }

  init(registry: FlutterTextureRegistry) {
    self.registry = registry
    var values = [Int32](repeating: 0, count: Int(MAKEUP_CONFIG_COUNT))
    makeup_get_config(&values, Int32(values.count))
    config = values
    // Variable local: Swift no deja leer propiedades de self antes de super.init.
    let core: OpaquePointer = makeup_create()
    engine = core
    tracker = FaceTracker(engine: core, config: values)
    statsBuffer = [Float](repeating: 0, count: Int(makeup_stat_count()))
    trackerStatsBuffer = [Float](repeating: 0, count: Int(makeup_tracker_stat_count()))
    super.init()
  }

  // MARK: - Inicio

  /// [completion] en main, una sola vez.
  func start(completion: @escaping (Result<StartInfo, EngineError>) -> Void) {
    switch AVCaptureDevice.authorizationStatus(for: .video) {
    case .authorized:
      configureCamera(completion: completion)
    case .notDetermined:
      AVCaptureDevice.requestAccess(for: .video) { granted in
        DispatchQueue.main.async {
          if granted {
            self.configureCamera(completion: completion)
          } else {
            completion(.failure(EngineError(code: "camera_permission", message: "Sin permiso de cámara")))
          }
        }
      }
    default:
      completion(.failure(EngineError(code: "camera_permission", message: "Sin permiso de cámara")))
    }
  }

  private func configureCamera(completion: @escaping (Result<StartInfo, EngineError>) -> Void) {
    guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
      completion(.failure(EngineError(code: "no_front_camera", message: "No hay cámara frontal")))
      return
    }
    let input: AVCaptureDeviceInput
    do {
      input = try AVCaptureDeviceInput(device: device)
    } catch {
      completion(.failure(EngineError(code: "camera_unavailable", message: "\(error)")))
      return
    }
    captureSession.beginConfiguration()
    // kMaxPreviewLongSide/ShortSide = 1280×720 (engine_config.h).
    captureSession.sessionPreset = captureSession.canSetSessionPreset(.hd1280x720) ? .hd1280x720 : .vga640x480
    guard captureSession.canAddInput(input) else {
      captureSession.commitConfiguration()
      completion(.failure(EngineError(code: "camera_unavailable", message: "No se pudo usar la cámara frontal")))
      return
    }
    captureSession.addInput(input)
    let output = AVCaptureVideoDataOutput()
    output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
    output.alwaysDiscardsLateVideoFrames = true  // los frames se descartan, nunca se encolan
    output.setSampleBufferDelegate(self, queue: renderQueue)
    guard captureSession.canAddOutput(output) else {
      captureSession.commitConfiguration()
      completion(.failure(EngineError(code: "camera_unavailable", message: "No se pudo leer la cámara")))
      return
    }
    captureSession.addOutput(output)
    // Vertical y sin espejo: el espejo lo hace la matriz de pantalla y el
    // tracker trabaja sobre la imagen sin espejar, como en Android.
    if let connection = output.connection(with: .video) {
      if #available(iOS 17.0, *) {
        if connection.isVideoRotationAngleSupported(90) { connection.videoRotationAngle = 90 }
      } else if connection.isVideoOrientationSupported {
        connection.videoOrientation = .portrait
      }
      if connection.isVideoMirroringSupported {
        connection.automaticallyAdjustsVideoMirroring = false
        connection.isVideoMirrored = false
      }
    }
    captureSession.commitConfiguration()
    let fps = Int(config[Int(MAKEUP_CONFIG_TARGET_FPS)])
    setFrameRate(device, fps: fps)

    let dimensions = CMVideoFormatDescriptionGetDimensions(device.activeFormat.formatDescription)
    let preview = (Int(dimensions.width), Int(dimensions.height))
    // El buffer llega rotado a vertical: lado corto de ancho.
    let outputWidth = min(preview.0, preview.1)
    let outputHeight = max(preview.0, preview.1)

    renderQueue.async {
      let error = self.initGl(width: outputWidth, height: outputHeight)
      DispatchQueue.main.async {
        if let error = error {
          completion(.failure(EngineError(code: "gl_init_failed", message: error)))
          return
        }
        if self.released {
          // stop() llegó durante start(): se responde igual para no colgar el Future de Dart.
          completion(.failure(EngineError(code: "cancelled", message: "La sesión se cerró durante el inicio")))
          return
        }
        self.textureId = self.registry.register(self)
        self.cameraControlQueue.async { self.captureSession.startRunning() }
        let info = StartInfo(textureId: self.textureId, width: outputWidth, height: outputHeight,
                             previewWidth: preview.0, previewHeight: preview.1, fps: fps,
                             glInfo: self.glInfoText())
        self.startInfo = info
        completion(.success(info))
      }
    }
  }

  private func setFrameRate(_ device: AVCaptureDevice, fps: Int) {
    let supported = device.activeFormat.videoSupportedFrameRateRanges.contains {
      $0.minFrameRate <= Double(fps) && Double(fps) <= $0.maxFrameRate
    }
    guard supported, (try? device.lockForConfiguration()) != nil else { return }
    let duration = CMTime(value: 1, timescale: CMTimeScale(fps))
    device.activeVideoMinFrameDuration = duration
    device.activeVideoMaxFrameDuration = duration
    device.unlockForConfiguration()
  }

  /// Cola de render. nil si salió bien.
  private func initGl(width: Int, height: Int) -> String? {
    guard let context = EAGLContext(api: .openGLES3), EAGLContext.setCurrent(context) else {
      return "no hay OpenGL ES 3 en este equipo"
    }
    self.context = context
    var cache: CVOpenGLESTextureCache?
    guard CVOpenGLESTextureCacheCreate(kCFAllocatorDefault, nil, context, nil, &cache) == kCVReturnSuccess,
          let textureCache = cache else {
      return "no se pudo crear la caché de texturas"
    }
    self.textureCache = textureCache
    if makeup_init_gl(engine) == 0 { return nativeError() }
    self.width = width
    self.height = height

    // FBO donde dibuja el núcleo.
    glGenTextures(1, &renderTexture)
    glBindTexture(GLenum(GL_TEXTURE_2D), renderTexture)
    glTexStorage2D(GLenum(GL_TEXTURE_2D), 1, GLenum(GL_RGBA8), GLsizei(width), GLsizei(height))
    glGenFramebuffers(1, &renderFramebuffer)
    glBindFramebuffer(GLenum(GL_FRAMEBUFFER), renderFramebuffer)
    glFramebufferTexture2D(GLenum(GL_FRAMEBUFFER), GLenum(GL_COLOR_ATTACHMENT0), GLenum(GL_TEXTURE_2D),
                           renderTexture, 0)
    guard glCheckFramebufferStatus(GLenum(GL_FRAMEBUFFER)) == GLenum(GL_FRAMEBUFFER_COMPLETE) else {
      return "framebuffer de render incompleto"
    }
    // Buffers de salida para Flutter (IOSurface, compatibles con GLES).
    let attributes: [String: Any] = [
      kCVPixelBufferOpenGLESCompatibilityKey as String: true,
      kCVPixelBufferIOSurfacePropertiesKey as String: [String: Any](),
    ]
    for _ in 0..<EngineSession.outputBufferCount {
      var buffer: CVPixelBuffer?
      guard CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA,
                                attributes as CFDictionary, &buffer) == kCVReturnSuccess, let pixels = buffer else {
        return "no se pudo crear el buffer de salida"
      }
      var cvTexture: CVOpenGLESTexture?
      guard CVOpenGLESTextureCacheCreateTextureFromImage(
        kCFAllocatorDefault, textureCache, pixels, nil, GLenum(GL_TEXTURE_2D), GL_RGBA, GLsizei(width),
        GLsizei(height), EngineSession.glBgra, GLenum(GL_UNSIGNED_BYTE), 0, &cvTexture) == kCVReturnSuccess,
        let texture = cvTexture else {
        return "no se pudo crear la textura de salida"
      }
      var framebuffer: GLuint = 0
      glGenFramebuffers(1, &framebuffer)
      glBindFramebuffer(GLenum(GL_FRAMEBUFFER), framebuffer)
      glFramebufferTexture2D(GLenum(GL_FRAMEBUFFER), GLenum(GL_COLOR_ATTACHMENT0),
                             CVOpenGLESTextureGetTarget(texture), CVOpenGLESTextureGetName(texture), 0)
      guard glCheckFramebufferStatus(GLenum(GL_FRAMEBUFFER)) == GLenum(GL_FRAMEBUFFER_COMPLETE) else {
        return "framebuffer de salida incompleto"
      }
      outputs.append((pixels, texture, framebuffer))
    }
    glBindFramebuffer(GLenum(GL_FRAMEBUFFER), 0)
    makeup_set_output_framebuffer(engine, renderFramebuffer)
    let display = CameraMath.displayMatrix(rotationDegrees: 0, mirror: true)
    let trackerMatrix = CameraMath.displayMatrix(rotationDegrees: 0, mirror: false)
    makeup_set_geometry(engine, display, trackerMatrix, Int32(width), Int32(height), true)
    return nil
  }

  // MARK: - Frames (cola de render)

  func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer,
                     from connection: AVCaptureConnection) {
    if released { return }
    guard let context = context, EAGLContext.setCurrent(context), let cache = textureCache,
          let pixels = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
    let frameStart = Int64(clock_gettime_nsec_np(CLOCK_MONOTONIC))
    let time = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
    let timestamp = Int64(CMTimeGetSeconds(time) * 1e9)
    if timestamp == lastTimestampNs { return }
    lastTimestampNs = timestamp
    let frameWidth = CVPixelBufferGetWidth(pixels)
    let frameHeight = CVPixelBufferGetHeight(pixels)
    guard frameWidth == width, frameHeight == height else {
      lastError = "la cámara entregó \(frameWidth)×\(frameHeight), se esperaba \(width)×\(height)"
      return
    }
    var cvTexture: CVOpenGLESTexture?
    guard CVOpenGLESTextureCacheCreateTextureFromImage(
      kCFAllocatorDefault, cache, pixels, nil, GLenum(GL_TEXTURE_2D), GL_RGBA, GLsizei(frameWidth),
      GLsizei(frameHeight), EngineSession.glBgra, GLenum(GL_UNSIGNED_BYTE), 0, &cvTexture) == kCVReturnSuccess,
      let cameraTexture = cvTexture else {
      lastError = "no se pudo leer el frame de cámara"
      return
    }
    let name = CVOpenGLESTextureGetName(cameraTexture)
    glBindTexture(GLenum(GL_TEXTURE_2D), name)
    glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MIN_FILTER), GL_LINEAR)
    glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MAG_FILTER), GL_LINEAR)
    glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_S), GL_CLAMP_TO_EDGE)
    glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_T), GL_CLAMP_TO_EDGE)
    glBindTexture(GLenum(GL_TEXTURE_2D), 0)
    makeup_set_camera_texture(engine, name)

    let flags = EngineSession.texMatrix.withUnsafeBufferPointer {
      makeup_draw_frame(engine, $0.baseAddress, Int32(width), Int32(height), frameStart, timestamp)
    }
    let target = outputs[nextOutput]
    nextOutput = (nextOutput + 1) % outputs.count
    glBindFramebuffer(GLenum(GL_READ_FRAMEBUFFER), renderFramebuffer)
    glBindFramebuffer(GLenum(GL_DRAW_FRAMEBUFFER), target.framebuffer)
    // Fila 0 abajo (GL) -> fila 0 arriba (lo que lee Flutter).
    glBlitFramebuffer(0, 0, GLint(width), GLint(height), 0, GLint(height), GLint(width), 0,
                      GLbitfield(GL_COLOR_BUFFER_BIT), GLenum(GL_NEAREST))
    glBindFramebuffer(GLenum(GL_FRAMEBUFFER), 0)
    glFlush()
    makeup_set_camera_texture(engine, 0)
    CVOpenGLESTextureCacheFlush(cache, 0)
    latestLock.sync { latest = target.buffer }
    let id = textureId
    DispatchQueue.main.async { [weak self] in
      guard let self = self, !self.released, id >= 0 else { return }
      self.registry.textureFrameAvailable(id)
    }
    if flags & EngineConst.frameFlagCropReady != 0 && !released { tracker.onCropReady() }
  }

  // MARK: - FlutterTexture

  func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
    guard let buffer = latestLock.sync({ latest }) else { return nil }
    return Unmanaged.passRetained(buffer)
  }

  // MARK: - Opciones (main)

  func setTint(r: Float, g: Float, b: Float, amount: Float) {
    if !released { makeup_set_tint(engine, r, g, b, amount) }
  }

  func setRecipe(_ recipe: [String: Any]?) {
    if released { return }
    RecipeParams.from(recipe).apply(to: engine)
  }

  func setRenderOptions(showLandmarks: Bool, region: Int32, lightAdaptation: Bool) {
    if released { return }
    makeup_set_render_options(engine, showLandmarks, region, lightAdaptation)
    let enabled = showLandmarks || region == EngineConst.regionMakeup
    if enabled && !trackerLoading {
      trackerLoading = true
      tracker.start()
    }
    tracker.setEnabled(enabled)
  }

  func resetStats() {
    if !released { makeup_reset_stats(engine) }
  }

  /// Mismas claves que EngineStats.fromMap en Dart (y que EngineSession.kt).
  func stats() -> [String: Any?] {
    if released { return ["error": "sesión cerrada"] }
    makeup_get_stats(engine, &statsBuffer, Int32(statsBuffer.count))
    makeup_get_tracker_stats(engine, &trackerStatsBuffer, Int32(trackerStatsBuffer.count))
    let t = trackerStatsBuffer.map { Double($0) }
    let s = statsBuffer.map { Double($0) }
    let trackerMap: [String: Any?] = [
      "state": Int(t[0]), "landmarkRuns": t[1], "detectorRuns": t[2], "losses": t[3],
      "intervalP50Ms": t[4], "intervalP95Ms": t[5], "landmarkP50Ms": t[6], "landmarkP95Ms": t[7],
      "detectorP50Ms": t[8], "jitterP50Px": t[9], "presence": t[10], "pitchDeg": t[11], "yawDeg": t[12],
      "rollDeg": t[13], "readbackMs": t[14], "cropFailures": t[15], "occlusionGate": t[16],
      "initMs": tracker.initMs, "backend": tracker.backend, "error": tracker.error,
    ]
    return [
      "frames": s[0], "intervalP50Ms": s[1], "intervalP95Ms": s[2], "cpuP50Ms": s[3], "cpuP95Ms": s[4],
      "cameraIntervalP50Ms": s[5], "cameraIntervalP95Ms": s[6],
      "previewWidth": startInfo?.previewWidth, "previewHeight": startInfo?.previewHeight,
      "error": lastError, "tracker": trackerMap,
    ]
  }

  // MARK: - Cierre

  /// Main. Idempotente. La textura se desregistra antes de volver (como el
  /// SurfaceProducer en Android); cámara, GL y tracker se liberan después y el
  /// núcleo se destruye cuando terminaron el render y el tracker.
  func release() {
    if released { return }
    stateLock.sync { releasedFlag = true }
    if textureId >= 0 {
      registry.unregisterTexture(textureId)
      textureId = -1
    }
    tracker.release { [weak self] in
      self?.trackerReleased = true
      self?.destroyNativeIfIdle()
    }
    cameraControlQueue.async {
      self.captureSession.stopRunning()
      self.renderQueue.async {
        if let context = self.context, EAGLContext.setCurrent(context) {
          makeup_release_gl(self.engine)
          for output in self.outputs {
            var framebuffer = output.framebuffer
            glDeleteFramebuffers(1, &framebuffer)
          }
          self.outputs.removeAll()
          glDeleteFramebuffers(1, &self.renderFramebuffer)
          glDeleteTextures(1, &self.renderTexture)
          EAGLContext.setCurrent(nil)
        }
        self.textureCache = nil
        self.context = nil
        self.latestLock.sync { self.latest = nil }
        DispatchQueue.main.async {
          self.renderReleased = true
          self.destroyNativeIfIdle()
        }
      }
    }
  }

  private func destroyNativeIfIdle() {
    if renderReleased && trackerReleased { makeup_destroy(engine) }
  }

  private func nativeError() -> String { text { makeup_last_error(engine, $0, $1) } }

  private func glInfoText() -> String { text { makeup_gl_info(engine, $0, $1) } }

  private func text(_ read: (UnsafeMutablePointer<CChar>, Int32) -> Int32) -> String {
    var buffer = [CChar](repeating: 0, count: 512)
    _ = buffer.withUnsafeMutableBufferPointer { read($0.baseAddress!, Int32($0.count)) }
    return String(cString: buffer)
  }
}

/// Port de CameraMath.displayMatrix (Kotlin): UV de salida -> UV de cámara,
/// con espejo horizontal opcional y rotación de múltiplos de 90°. Column-major.
enum CameraMath {
  static func displayMatrix(rotationDegrees: Int, mirror: Bool) -> [Float] {
    let (c, s): (Float, Float)
    switch ((rotationDegrees % 360) + 360) % 360 {
    case 90: (c, s) = (0, 1)
    case 180: (c, s) = (-1, 0)
    case 270: (c, s) = (0, -1)
    default: (c, s) = (1, 0)
    }
    let fx: Float = mirror ? -1 : 1
    var m = [Float](repeating: 0, count: 16)
    m[0] = c * fx
    m[1] = s * fx
    m[4] = -s
    m[5] = c
    m[10] = 1
    m[12] = 0.5 - 0.5 * (c * fx - s)
    m[13] = 0.5 - 0.5 * (s * fx + c)
    m[15] = 1
    return m
  }
}

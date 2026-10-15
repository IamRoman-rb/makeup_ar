import AVFoundation
import CoreVideo
import Flutter
import Foundation
import OpenGLES
import UIKit

/// Una sesión cámara -> OpenGL ES 3 -> Texture de Flutter: port de
/// EngineSession.kt para iOS (docs/ar_engine/IOS.md).
///
/// Colas:
///  - main: start/release/stats, el registro de la textura y el ciclo de vida
///    de la app (pausa en segundo plano).
///  - "makeup-render" (serie): dueña del EAGLContext. AVFoundation entrega
///    cada frame acá; se dibuja y se recorta la cara para el tracker.
///  - "makeup-tracker": inferencia (FaceTracker).
/// Dart no cruza por frame.
///
/// Salida: el núcleo dibuja en un FBO propio (como en Android, fila 0 abajo)
/// y se copia invertido con glBlitFramebuffer a uno de cuatro CVPixelBuffer
/// que lee Flutter (fila 0 arriba). Un buffer se publica recién cuando su
/// fence está señalada (un frame de latencia, sin esperas): Flutter nunca lee
/// uno a medio escribir. Así el núcleo y Dart son los mismos que en Android.
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

  private struct Output {
    let buffer: CVPixelBuffer
    let texture: CVOpenGLESTexture
    let framebuffer: GLuint
  }

  private static let outputBufferCount = 4
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
  private var outputs: [Output] = []
  private var nextOutput = 0
  private var pendingIndex = -1           // buffer escrito, esperando su fence
  private var pendingFence: GLsync?
  private var configuredTextures = Set<GLuint>()  // texturas de cámara con parámetros ya fijados
  private var width = 0
  private var height = 0
  private var lastTimestampNs: Int64 = .min

  // Último buffer terminado (copyPixelBuffer lo lee desde el hilo de Flutter).
  private let latestLock = NSLock()
  private var latest: CVPixelBuffer?
  private var latestIndex = -1

  // Solo main.
  private var trackerLoading = false
  private var trackingWanted = false
  private var renderReleased = false
  private var trackerReleased = false
  private var statsBuffer: [Float]
  private var trackerStatsBuffer: [Float]
  private var startInfo: StartInfo?
  private var observers: [NSObjectProtocol] = []

  // Compartido entre colas (stateLock): una toma por frame.
  private let stateLock = NSLock()
  private var releasedFlag = false
  private var pausedFlag = false
  private var textureIdValue: Int64 = -1
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

  private static let cancelled = EngineError(code: "cancelled", message: "La sesión se cerró durante el inicio")

  private func configureCamera(completion: @escaping (Result<StartInfo, EngineError>) -> Void) {
    // stop() mientras estaba el diálogo de permiso: el núcleo ya puede estar destruido.
    if released {
      completion(.failure(EngineSession.cancelled))
      return
    }
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

    // Encolado en main, antes que cualquier release() posterior (que también
    // corre en main y encola su limpieza detrás): la limpieza ve lo que se creó acá.
    renderQueue.async {
      let error = self.released ? "cancelada" : self.initGl(width: outputWidth, height: outputHeight)
      DispatchQueue.main.async {
        if self.released {
          // stop() llegó durante start(): se responde igual para no colgar el Future de Dart.
          completion(.failure(EngineSession.cancelled))
          return
        }
        if let error = error {
          completion(.failure(EngineError(code: "gl_init_failed", message: error)))
          return
        }
        let id = self.registry.register(self)
        self.stateLock.sync { self.textureIdValue = id }
        self.observeLifecycle()
        self.cameraControlQueue.async { self.captureSession.startRunning() }
        let info = StartInfo(textureId: id, width: outputWidth, height: outputHeight,
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

  /// Cola de render. nil si salió bien. Si falla a mitad, lo creado se libera
  /// en release() (teardownGl).
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
      outputs.append(Output(buffer: pixels, texture: texture, framebuffer: framebuffer))
      guard glCheckFramebufferStatus(GLenum(GL_FRAMEBUFFER)) == GLenum(GL_FRAMEBUFFER_COMPLETE) else {
        return "framebuffer de salida incompleto"
      }
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
    // Una sola toma del lock por frame. En segundo plano iOS mata la app si
    // se envía trabajo a la GPU: con la sesión pausada no se dibuja nada.
    let (stop, textureId) = stateLock.sync { (releasedFlag || pausedFlag, textureIdValue) }
    if stop { return }
    guard let context = context, EAGLContext.setCurrent(context), let cache = textureCache, !outputs.isEmpty,
          let pixels = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
    let frameStart = Int64(clock_gettime_nsec_np(CLOCK_MONOTONIC))
    let timestamp = Int64(CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sampleBuffer)) * 1e9)
    if timestamp == lastTimestampNs { return }
    lastTimestampNs = timestamp
    // El frame anterior: si la GPU ya lo terminó, recién ahí lo ve Flutter.
    publishPending(textureId)
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
    guard let target = chooseOutput() else { return }  // todos en uso: se descarta el frame
    // La textura de cámara tiene que vivir hasta que se envían los comandos que
    // la leen: si ARC la suelta antes, el nombre GL se recicla a mitad del frame.
    let flags: Int32 = withExtendedLifetime(cameraTexture) {
      let name = CVOpenGLESTextureGetName(cameraTexture)
      if configuredTextures.insert(name).inserted {
        // La caché reutiliza nombres por buffer de cámara: se configuran una vez.
        glBindTexture(GLenum(GL_TEXTURE_2D), name)
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MIN_FILTER), GL_LINEAR)
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MAG_FILTER), GL_LINEAR)
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_S), GL_CLAMP_TO_EDGE)
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_T), GL_CLAMP_TO_EDGE)
        glBindTexture(GLenum(GL_TEXTURE_2D), 0)
      }
      makeup_set_camera_texture(engine, name)
      let result = EngineSession.texMatrix.withUnsafeBufferPointer {
        makeup_draw_frame(engine, $0.baseAddress, Int32(width), Int32(height), frameStart, timestamp)
      }
      let output = outputs[target]
      glBindFramebuffer(GLenum(GL_READ_FRAMEBUFFER), renderFramebuffer)
      glBindFramebuffer(GLenum(GL_DRAW_FRAMEBUFFER), output.framebuffer)
      // Fila 0 abajo (GL) -> fila 0 arriba (lo que lee Flutter).
      glBlitFramebuffer(0, 0, GLint(width), GLint(height), 0, GLint(height), GLint(width), 0,
                        GLbitfield(GL_COLOR_BUFFER_BIT), GLenum(GL_NEAREST))
      glBindFramebuffer(GLenum(GL_FRAMEBUFFER), 0)
      pendingFence = glFenceSync(GLenum(GL_SYNC_GPU_COMMANDS_COMPLETE), 0)
      pendingIndex = target
      // Un solo flush por frame (el núcleo no hace el suyo en iOS).
      glFlush()
      makeup_set_camera_texture(engine, 0)
      return result
    }
    CVOpenGLESTextureCacheFlush(cache, 0)
    if flags & EngineConst.frameFlagCropReady != 0 { tracker.onCropReady() }
  }

  /// Siguiente buffer que no sea el publicado (Flutter lo puede estar leyendo)
  /// ni el pendiente, ni uno que otro proceso tenga tomado.
  private func chooseOutput() -> Int? {
    let published = latestLock.sync { latestIndex }
    for step in 0..<outputs.count {
      let index = (nextOutput + step) % outputs.count
      if index == published || index == pendingIndex { continue }
      if let surface = CVPixelBufferGetIOSurface(outputs[index].buffer)?.takeUnretainedValue(),
         IOSurfaceIsInUse(surface) {
        continue
      }
      nextOutput = (index + 1) % outputs.count
      return index
    }
    return nil
  }

  /// Publica el buffer pendiente si su fence ya está señalada (sin esperar).
  private func publishPending(_ textureId: Int64) {
    guard let fence = pendingFence, pendingIndex >= 0 else { return }
    let status = glClientWaitSync(fence, GLbitfield(GL_SYNC_FLUSH_COMMANDS_BIT), 0)
    guard status == GLenum(GL_ALREADY_SIGNALED) || status == GLenum(GL_CONDITION_SATISFIED) else {
      // Todavía no: se reintenta en el frame siguiente (si llega antes, se descarta este).
      return
    }
    glDeleteSync(fence)
    pendingFence = nil
    let index = pendingIndex
    pendingIndex = -1
    latestLock.sync {
      latest = outputs[index].buffer
      latestIndex = index
    }
    // Seguro desde cualquier hilo: sin closure ni salto a main por frame.
    if textureId >= 0 { registry.textureFrameAvailable(textureId) }
  }

  // MARK: - FlutterTexture

  func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
    guard let buffer = latestLock.sync({ latest }) else { return nil }
    return Unmanaged.passRetained(buffer)
  }

  // MARK: - Ciclo de vida de la app (main)

  private func observeLifecycle() {
    let center = NotificationCenter.default
    observers = [
      center.addObserver(forName: UIApplication.willResignActiveNotification, object: nil, queue: .main) {
        [weak self] _ in self?.pause()
      },
      center.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) {
        [weak self] _ in self?.resume()
      },
      center.addObserver(forName: .AVCaptureSessionWasInterrupted, object: captureSession, queue: .main) {
        [weak self] _ in self?.lastError = "cámara interrumpida (otra app o llamada)"
      },
      center.addObserver(forName: .AVCaptureSessionRuntimeError, object: captureSession, queue: .main) {
        [weak self] note in
        guard let self = self else { return }
        let error = note.userInfo?[AVCaptureSessionErrorKey] as? Error
        self.lastError = "error de cámara: \(error.map { "\($0)" } ?? "desconocido")"
        if !self.released, !self.stateLock.sync({ self.pausedFlag }) {
          self.cameraControlQueue.async { self.captureSession.startRunning() }
        }
      },
    ]
  }

  /// Al pasar a inactiva: nada más a la GPU (render ni tracker) hasta volver.
  private func pause() {
    if released { return }
    stateLock.sync { pausedFlag = true }
    tracker.setEnabled(false)
    // Espera el frame en curso y termina lo enviado antes de quedar en segundo plano.
    renderQueue.sync {
      if let context = context, EAGLContext.setCurrent(context) { glFinish() }
    }
    cameraControlQueue.async { self.captureSession.stopRunning() }
  }

  private func resume() {
    if released || !stateLock.sync({ pausedFlag }) { return }
    stateLock.sync { pausedFlag = false }
    tracker.setEnabled(trackingWanted)
    cameraControlQueue.async { self.captureSession.startRunning() }
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
    trackingWanted = showLandmarks || region == EngineConst.regionMakeup
    if trackingWanted && !trackerLoading {
      trackerLoading = true
      tracker.start()
    }
    if !stateLock.sync({ pausedFlag }) { tracker.setEnabled(trackingWanted) }
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
  /// núcleo se destruye cuando terminaron el render y el tracker. Toda limpieza
  /// de GL se encola detrás de lo que ya esté en la cola de render (también un
  /// initGl en curso), así que libera lo que se haya llegado a crear.
  func release() {
    let id: Int64? = stateLock.sync {
      if releasedFlag { return nil }
      releasedFlag = true
      let current = textureIdValue
      textureIdValue = -1
      return current
    }
    guard let textureId = id else { return }
    observers.forEach { NotificationCenter.default.removeObserver($0) }
    observers.removeAll()
    if textureId >= 0 { registry.unregisterTexture(textureId) }
    tracker.release { [weak self] in
      self?.trackerReleased = true
      self?.destroyNativeIfIdle()
    }
    cameraControlQueue.async {
      self.captureSession.stopRunning()
      self.renderQueue.async {
        self.teardownGl()
        DispatchQueue.main.async {
          self.renderReleased = true
          self.destroyNativeIfIdle()
        }
      }
    }
  }

  /// Cola de render: libera lo que initGl haya creado (aunque haya fallado a mitad).
  private func teardownGl() {
    if let context = context, EAGLContext.setCurrent(context) {
      if let fence = pendingFence { glDeleteSync(fence) }
      makeup_release_gl(engine)
      for output in outputs {
        var framebuffer = output.framebuffer
        glDeleteFramebuffers(1, &framebuffer)
      }
      if renderFramebuffer != 0 { glDeleteFramebuffers(1, &renderFramebuffer) }
      if renderTexture != 0 { glDeleteTextures(1, &renderTexture) }
      glFinish()
      EAGLContext.setCurrent(nil)
    }
    pendingFence = nil
    pendingIndex = -1
    outputs.removeAll()
    configuredTextures.removeAll()
    textureCache = nil
    context = nil
    latestLock.sync {
      latest = nil
      latestIndex = -1
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

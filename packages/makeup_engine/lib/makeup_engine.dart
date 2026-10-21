/// Motor AR nativo (Android): cámara -> OpenGL ES 3.0 -> `Texture` de Flutter.
///
/// Tinte OKLab (pantalla completa o solo labios) sobre la cámara y tracker
/// facial (FaceMesh-V2) en nativo, con métricas calculadas en nativo. Dart
/// nunca ve píxeles ni cruza por frame: inicia/detiene, cambia parámetros y lee
/// métricas.
library;

import 'package:flutter/services.dart';

import 'still_image_analysis.dart';

export 'still_image_analysis.dart';

/// Resultado de [MakeupEngine.start].
final class EngineStartInfo {
  const EngineStartInfo({
    required this.textureId,
    required this.width,
    required this.height,
    required this.previewWidth,
    required this.previewHeight,
    required this.sensorOrientation,
    required this.rotationDegrees,
    required this.fpsMin,
    required this.fpsMax,
    required this.glInfo,
  });

  factory EngineStartInfo.fromMap(Map<Object?, Object?> map) => EngineStartInfo(
        textureId: _int(map['textureId']) ?? -1,
        width: _int(map['width']) ?? 0,
        height: _int(map['height']) ?? 0,
        previewWidth: _int(map['previewWidth']) ?? 0,
        previewHeight: _int(map['previewHeight']) ?? 0,
        sensorOrientation: _int(map['sensorOrientation']) ?? 0,
        rotationDegrees: _int(map['rotationDegrees']) ?? 0,
        fpsMin: _int(map['fpsMin']),
        fpsMax: _int(map['fpsMax']),
        glInfo: map['glInfo'] as String? ?? '',
      );

  /// Id para el widget `Texture`.
  final int textureId;

  /// Tamaño de la textura de salida (ya rotada para la pantalla).
  final int width;
  final int height;

  /// Tamaño del stream de cámara, en la orientación del sensor.
  final int previewWidth;
  final int previewHeight;
  final int sensorOrientation;
  final int rotationDegrees;

  /// Rango de AE pedido a la cámara; null si la cámara no informa rangos.
  final int? fpsMin;
  final int? fpsMax;

  /// GL_VENDOR | GL_RENDERER | GL_VERSION | GLSL.
  final String glInfo;

  double get aspectRatio => height == 0 ? 1 : width / height;
}

/// Métricas de frame calculadas en nativo (ventana de las últimas ~256 muestras).
/// Los percentiles son null hasta que hay muestras.
final class EngineStats {
  const EngineStats({
    required this.frames,
    this.intervalP50Ms,
    this.intervalP95Ms,
    this.cpuP50Ms,
    this.cpuP95Ms,
    this.cameraIntervalP50Ms,
    this.cameraIntervalP95Ms,
    this.error,
    this.tracker = TrackerStats.empty,
  });

  factory EngineStats.fromMap(Map<Object?, Object?> map) {
    final tracker = map['tracker'];
    return EngineStats(
      frames: _double(map['frames'])?.round() ?? 0,
      intervalP50Ms: _double(map['intervalP50Ms']),
      intervalP95Ms: _double(map['intervalP95Ms']),
      cpuP50Ms: _double(map['cpuP50Ms']),
      cpuP95Ms: _double(map['cpuP95Ms']),
      cameraIntervalP50Ms: _double(map['cameraIntervalP50Ms']),
      cameraIntervalP95Ms: _double(map['cameraIntervalP95Ms']),
      error: map['error'] as String?,
      tracker: tracker is Map<Object?, Object?> ? TrackerStats.fromMap(tracker) : TrackerStats.empty,
    );
  }

  static const empty = EngineStats(frames: 0);

  /// Frames dibujados desde el inicio o el último [MakeupEngine.resetStats].
  final int frames;

  /// Intervalo entre frames dibujados (1000 / fps).
  final double? intervalP50Ms;
  final double? intervalP95Ms;

  /// Tiempo de CPU del hilo de render por frame: updateTexImage + draw + swap.
  final double? cpuP50Ms;
  final double? cpuP95Ms;

  /// Intervalo entre frames que entrega el sensor.
  final double? cameraIntervalP50Ms;
  final double? cameraIntervalP95Ms;

  /// Último error asíncrono (cámara desconectada, permiso, etc.).
  final String? error;

  /// Métricas del tracker facial.
  final TrackerStats tracker;

  double? get renderFps => _fps(intervalP50Ms);
  double? get cameraFps => _fps(cameraIntervalP50Ms);
}

/// Estado del tracker facial.
enum TrackerState {
  /// Apagado o cargando los modelos.
  off,

  /// Corriendo el detector: todavía no hay cara.
  searching,

  /// Siguiendo una cara con el modelo de landmarks.
  tracking,
}

/// Métricas del tracker (nativo, ventana de las últimas ~256 muestras).
final class TrackerStats {
  const TrackerStats({
    this.state = TrackerState.off,
    this.landmarkRuns = 0,
    this.detectorRuns = 0,
    this.losses = 0,
    this.intervalP50Ms,
    this.intervalP95Ms,
    this.landmarkP50Ms,
    this.landmarkP95Ms,
    this.detectorP50Ms,
    this.jitterP50Px,
    this.presence,
    this.pitchDeg,
    this.yawDeg,
    this.rollDeg,
    this.readbackMs,
    this.cropFailures = 0,
    this.occlusionGate,
    this.filterMinCutoff,
    this.filterBeta,
    this.initMs,
    this.backend,
    this.error,
  });

  factory TrackerStats.fromMap(Map<Object?, Object?> map) {
    final state = _int(map['state']) ?? 0;
    return TrackerStats(
      state: TrackerState.values[state.clamp(0, TrackerState.values.length - 1)],
      landmarkRuns: _double(map['landmarkRuns'])?.round() ?? 0,
      detectorRuns: _double(map['detectorRuns'])?.round() ?? 0,
      losses: _double(map['losses'])?.round() ?? 0,
      intervalP50Ms: _double(map['intervalP50Ms']),
      intervalP95Ms: _double(map['intervalP95Ms']),
      landmarkP50Ms: _double(map['landmarkP50Ms']),
      landmarkP95Ms: _double(map['landmarkP95Ms']),
      detectorP50Ms: _double(map['detectorP50Ms']),
      jitterP50Px: _double(map['jitterP50Px']),
      presence: _double(map['presence']),
      pitchDeg: _double(map['pitchDeg']),
      yawDeg: _double(map['yawDeg']),
      rollDeg: _double(map['rollDeg']),
      readbackMs: _double(map['readbackMs']),
      cropFailures: _double(map['cropFailures'])?.round() ?? 0,
      occlusionGate: _double(map['occlusionGate']),
      filterMinCutoff: _double(map['filterMinCutoff']),
      filterBeta: _double(map['filterBeta']),
      initMs: _double(map['initMs']),
      backend: map['backend'] as String?,
      error: map['error'] as String?,
    );
  }

  static const empty = TrackerStats();

  final TrackerState state;

  /// Inferencias desde el inicio o el último [MakeupEngine.resetStats].
  final int landmarkRuns;
  final int detectorRuns;

  /// Veces que se perdió la cara.
  final int losses;

  /// Intervalo entre resultados de landmarks (1000 / Hz del tracker).
  final double? intervalP50Ms;
  final double? intervalP95Ms;

  /// Landmarks: preparar entrada + inferencia + leer salidas.
  final double? landmarkP50Ms;
  final double? landmarkP95Ms;
  final double? detectorP50Ms;

  /// Movimiento medio de los puntos estables entre resultados (px de la
  /// imagen). Con la cara quieta es el temblor; objetivo < 0,5 px.
  final double? jitterP50Px;

  /// Puntaje de presencia del último resultado, [0, 1].
  final double? presence;

  /// Pose de la cabeza en grados.
  final double? pitchDeg;
  final double? yawDeg;
  final double? rollDeg;

  /// Último recorte: de pedirlo a la GPU a tenerlo en CPU.
  final double? readbackMs;

  /// Recortes descartados (fence fallido o la GPU no terminó a tiempo).
  final int cropFailures;

  /// Compuerta de oclusión del labial [0, 1]: 0 = nada tapa la boca.
  final double? occlusionGate;

  /// One Euro en uso (Hz y s): los de engine_config.h o los del ajuste en
  /// vivo ([MakeupEngine.setTrackerTuning]).
  final double? filterMinCutoff;
  final double? filterBeta;

  /// Carga de los modelos (la primera vez incluye compilar para la GPU).
  final double? initMs;

  /// Backends en uso, p. ej. `detector=gpu landmarks=gpu`.
  final String? backend;
  final String? error;

  double? get hz => _fps(intervalP50Ms);
}

/// Qué se pinta.
enum TintRegion {
  /// Tinte de toda la imagen con [MakeupEngine.setTint] (no necesita tracker;
  /// pantalla del spike).
  full,

  /// Maquillaje de la receta ([MakeupEngine.setRecipe]) sobre la cara (prende
  /// el tracker).
  makeup,
}

/// Latencia de un modelo del tracker con un backend de LiteRT (ver
/// ModelBenchmark.kt). Tiempos en ms; null si el backend falló.
final class ModelBenchmarkResult {
  const ModelBenchmarkResult({
    required this.model,
    required this.backend,
    required this.iterations,
    this.initMs,
    this.runP50Ms,
    this.runP95Ms,
    this.totalP50Ms,
    this.totalP95Ms,
    this.error,
  });

  factory ModelBenchmarkResult.fromMap(Map<Object?, Object?> map) => ModelBenchmarkResult(
        model: map['model'] as String? ?? '?',
        backend: map['backend'] as String? ?? '?',
        iterations: _int(map['iterations']) ?? 0,
        initMs: _double(map['initMs']),
        runP50Ms: _double(map['runP50Ms']),
        runP95Ms: _double(map['runP95Ms']),
        totalP50Ms: _double(map['totalP50Ms']),
        totalP95Ms: _double(map['totalP95Ms']),
        error: map['error'] as String?,
      );

  final String model;

  /// `gpu`, `gpu_opengl`, `cpu_1t`, `cpu_2t`, `cpu_4t`.
  final String backend;
  final int iterations;

  /// Compilar el modelo y crear buffers (una vez).
  final double? initMs;

  /// Solo la inferencia.
  final double? runP50Ms;
  final double? runP95Ms;

  /// Escribir entrada + inferencia + leer salidas.
  final double? totalP50Ms;
  final double? totalP95Ms;
  final String? error;
}

/// Error de [MakeupEngine.start]. [code]: `no_front_camera`,
/// `camera_unavailable`, `gl_init_failed`, `already_started`, `not_attached`.
/// De [MakeupEngine.analyzeFaceImage] y [MakeupEngine.extractPalette]:
/// `bad_image` (no se pudo leer la foto), `analysis_failed`, `bad_response`.
final class MakeupEngineException implements Exception {
  const MakeupEngineException(this.code, this.message);

  final String code;
  final String? message;

  @override
  String toString() => 'MakeupEngineException($code): $message';
}

/// Fachada del canal `makeup_engine`. Una sola sesión a la vez.
final class MakeupEngine {
  MakeupEngine({MethodChannel? channel}) : _channel = channel ?? const MethodChannel('makeup_engine');

  final MethodChannel _channel;

  /// Abre cámara frontal + GL. El permiso de cámara se pide ANTES de llamar
  /// a esto. [rotationDegrees] fuerza la rotación (0/90/180/270) si la
  /// automática sale mal en un dispositivo.
  Future<EngineStartInfo> start({int? rotationDegrees}) async {
    try {
      final result = await _channel.invokeMapMethod<Object?, Object?>('start', {
        'rotationDegrees': ?rotationDegrees,
      });
      if (result == null) throw const MakeupEngineException('start_failed', 'respuesta vacía');
      return EngineStartInfo.fromMap(result);
    } on PlatformException catch (e) {
      throw MakeupEngineException(e.code, e.message);
    }
  }

  Future<void> stop() => _channel.invokeMethod<void>('stop');

  /// Color sRGB en [0, 1] e intensidad en [0, 1]. Intensidad 0 = paso directo.
  Future<void> setTint({required double r, required double g, required double b, required double amount}) =>
      _channel.invokeMethod<void>('setTint', {
        'r': r.clamp(0.0, 1.0),
        'g': g.clamp(0.0, 1.0),
        'b': b.clamp(0.0, 1.0),
        'amount': amount.clamp(0.0, 1.0),
      });

  /// Receta `makeup-recipe/2` ya validada (RecipeValidator en la app; p. ej.
  /// `recipe.toJson()`). Con [TintRegion.makeup] el motor dibuja labios,
  /// rubor, piel (base, contorno, iluminador), ojos (sombras, delineado,
  /// pestañas) y efectos. Del lado nativo los valores se vuelven a
  /// recortar a rango y cada región inválida o ausente se apaga. La receta se
  /// aplica entera en el mismo frame.
  Future<void> setRecipe(Map<String, Object?> recipe) =>
      _channel.invokeMethod<void>('setRecipe', {'recipe': recipe});

  /// [showLandmarks] dibuja los puntos del tracker (depuración); [region]
  /// elige qué se pinta. El tracker se prende si alguno lo necesita: la primera
  /// vez carga los modelos (segundos) y mientras tanto no hay cara.
  /// [lightAdaptation] adapta los colores de la receta al color de la luz de
  /// la escena (docs/ar_engine/FACE.md §11); apagada, solo para comparar.
  Future<void> setRenderOptions({
    bool showLandmarks = false,
    TintRegion region = TintRegion.full,
    bool lightAdaptation = true,
  }) =>
      _channel.invokeMethod<void>('setRenderOptions', {
        'showLandmarks': showLandmarks,
        'region': region.index,
        'lightAdaptation': lightAdaptation,
      });

  /// Arnés (docs/ar_engine/TRACKER.md §9): ajuste en vivo del filtro One
  /// Euro del tracker ([minCutoff] en Hz, [beta] en s; se recortan a rango del
  /// lado nativo) y [smoothMesh], la malla subdividida suave en lugar de los
  /// triángulos de los 468 landmarks. Para medir en el E20 y después fijar los
  /// valores en engine_config.h.
  Future<void> setTrackerTuning({required double minCutoff, required double beta, required bool smoothMesh}) =>
      _channel.invokeMethod<void>('setTrackerTuning', {
        'minCutoff': minCutoff,
        'beta': beta,
        'smoothMesh': smoothMesh,
      });

  /// Leer a ~2 Hz como máximo: es para el overlay y el arnés, no por frame.
  Future<EngineStats> getStats() async {
    final result = await _channel.invokeMapMethod<Object?, Object?>('getStats');
    return result == null ? EngineStats.empty : EngineStats.fromMap(result);
  }

  Future<void> resetStats() => _channel.invokeMethod<void>('resetStats');

  /// Studio (F4): mide el maquillaje de una foto de referencia (bytes JPEG o
  /// PNG). Corre en el teléfono, en un hilo propio, con los modelos del
  /// tracker en CPU (puede convivir con una sesión de cámara); la foto no se
  /// guarda. Unos cientos de ms en el E20 (a medir).
  Future<FaceImageAnalysis> analyzeFaceImage(Uint8List bytes) async {
    final values = await _stillValues('analyzeFaceImage', bytes);
    final analysis = FaceImageAnalysis.fromValues(values);
    if (analysis == null) throw const MakeupEngineException('bad_response', 'medidas incompletas');
    return analysis;
  }

  /// Guía de maquillaje (docs/ar_engine/COACH.md): mide la cara de la sesión
  /// en vivo como [analyzeFaceImage], con los landmarks del tracker (sin
  /// correr los modelos otra vez). El render recorta la cara a 512 px en el
  /// próximo frame con cara; la medición corre en un hilo de fondo. null sin
  /// sesión o si en ~1,5 s no hubo cara. El recorte no se guarda.
  Future<FaceImageAnalysis?> sampleLiveLook() async {
    try {
      final result = await _channel.invokeListMethod<Object?>('sampleLiveLook');
      if (result == null) return null;
      final values = [for (final value in result) value is num ? value.toDouble() : double.nan];
      final analysis = FaceImageAnalysis.fromValues(values);
      if (analysis == null) throw const MakeupEngineException('bad_response', 'medidas incompletas');
      return analysis;
    } on PlatformException catch (e) {
      throw MakeupEngineException(e.code, e.message);
    } on MissingPluginException {
      return null;  // plataforma sin la guía todavía (iOS: IOS.md)
    }
  }

  /// Guía de maquillaje: dice [text] en voz alta con el TextToSpeech de
  /// Android (corta lo anterior). [locale]: es, en, pt o fr. false si el
  /// sistema no tiene voz para ese idioma (queda solo el texto).
  Future<bool> coachSpeak(String text, {required String locale}) async {
    try {
      return await _channel.invokeMethod<bool>('coachSpeak', {'text': text, 'locale': locale}) ?? false;
    } on MissingPluginException {
      return false;  // sin voz en esta plataforma: queda el texto
    }
  }

  /// Calla la voz de la guía.
  Future<void> coachStop() => _optional('coachStop');

  /// Libera el motor de voz (al salir de la guía).
  Future<void> coachRelease() => _optional('coachRelease');

  Future<void> _optional(String method) async {
    try {
      await _channel.invokeMethod<void>(method);
    } on MissingPluginException {
      // Plataforma sin la guía: no hay nada que callar ni liberar.
    }
  }

  /// Studio (F4): colores de una foto de producto o paleta, de mayor a menor
  /// área (sin el fondo ni los blancos). Vacía si no hay colores útiles.
  Future<List<PaletteSwatch>> extractPalette(Uint8List bytes) async =>
      PaletteSwatch.fromValues(await _stillValues('extractPalette', bytes));

  Future<List<double>> _stillValues(String method, Uint8List bytes) async {
    try {
      final result = await _channel.invokeListMethod<Object?>(method, {'bytes': bytes});
      return [for (final value in result ?? const <Object?>[]) value is num ? value.toDouble() : double.nan];
    } on PlatformException catch (e) {
      throw MakeupEngineException(e.code, e.message);
    }
  }

  /// Benchmark de los modelos del tracker (unos minutos; imagen sintética, sin
  /// cámara). No llamar con una sesión de cámara activa: compiten por la GPU.
  Future<List<ModelBenchmarkResult>> runBenchmark() async {
    final result = await _channel.invokeListMethod<Object?>('runBenchmark');
    return [
      for (final item in result ?? const <Object?>[])
        if (item is Map<Object?, Object?>) ModelBenchmarkResult.fromMap(item),
    ];
  }
}

int? _int(Object? value) => value is num && value.isFinite ? value.toInt() : null;

double? _fps(double? intervalMs) => intervalMs == null || intervalMs <= 0 ? null : 1000 / intervalMs;

/// NaN (ventana vacía en nativo) se convierte en null.
double? _double(Object? value) {
  if (value is! num) return null;
  final asDouble = value.toDouble();
  return asDouble.isFinite ? asDouble : null;
}

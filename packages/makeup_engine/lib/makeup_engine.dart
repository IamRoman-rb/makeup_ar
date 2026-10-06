/// Motor AR nativo (Android): cámara -> OpenGL ES 3.0 -> `Texture` de Flutter.
///
/// Fase P1 (spike): paso directo y tinte OKLab de pantalla completa, con
/// métricas de frame calculadas en nativo. Dart nunca ve píxeles ni cruza por
/// frame: inicia/detiene, cambia parámetros y lee métricas.
library;

import 'package:flutter/services.dart';

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
  });

  factory EngineStats.fromMap(Map<Object?, Object?> map) => EngineStats(
        frames: _double(map['frames'])?.round() ?? 0,
        intervalP50Ms: _double(map['intervalP50Ms']),
        intervalP95Ms: _double(map['intervalP95Ms']),
        cpuP50Ms: _double(map['cpuP50Ms']),
        cpuP95Ms: _double(map['cpuP95Ms']),
        cameraIntervalP50Ms: _double(map['cameraIntervalP50Ms']),
        cameraIntervalP95Ms: _double(map['cameraIntervalP95Ms']),
        error: map['error'] as String?,
      );

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

  double? get renderFps => _fps(intervalP50Ms);
  double? get cameraFps => _fps(cameraIntervalP50Ms);

  static double? _fps(double? intervalMs) =>
      intervalMs == null || intervalMs <= 0 ? null : 1000 / intervalMs;
}

/// Error de [MakeupEngine.start]. [code]: `no_front_camera`,
/// `camera_unavailable`, `gl_init_failed`, `already_started`, `not_attached`.
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

  /// Leer a ~2 Hz como máximo: es para el overlay y el arnés, no por frame.
  Future<EngineStats> getStats() async {
    final result = await _channel.invokeMapMethod<Object?, Object?>('getStats');
    return result == null ? EngineStats.empty : EngineStats.fromMap(result);
  }

  Future<void> resetStats() => _channel.invokeMethod<void>('resetStats');
}

int? _int(Object? value) => value is num ? value.toInt() : null;

/// NaN (ventana vacía en nativo) se convierte en null.
double? _double(Object? value) {
  if (value is! num) return null;
  final asDouble = value.toDouble();
  return asDouble.isFinite ? asDouble : null;
}

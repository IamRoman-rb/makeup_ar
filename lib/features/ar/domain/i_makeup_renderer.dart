import 'makeup_recipe.dart';

/// Superficie de video con el maquillaje: el id de textura de Flutter y su
/// tamaño en px (la vista la muestra con un `Texture`).
final class MakeupSurface {
  const MakeupSurface({required this.textureId, required this.width, required this.height});

  final int textureId;
  final int width;
  final int height;
}

/// Estado del seguimiento de la cara.
enum FaceTrackingState {
  /// Apagado (ninguna opción lo necesita) o todavía sin modelos.
  off,

  /// Cargando o compilando los modelos (la primera vez tarda unos segundos).
  loading,
  searching,
  tracking,
}

/// Métricas para el indicador de depuración. null = todavía sin dato.
final class MakeupRendererStats {
  const MakeupRendererStats({
    this.renderFps,
    this.tracking = FaceTrackingState.off,
    this.trackerHz,
    this.landmarkMs,
    this.error,
  });

  static const MakeupRendererStats empty = MakeupRendererStats();

  final double? renderFps;
  final FaceTrackingState tracking;
  final double? trackerHz;
  final double? landmarkMs;

  /// Error asíncrono del motor o del tracker.
  final String? error;
}

/// Contrato del motor de maquillaje en vivo (informe §4): la vista no sabe si
/// dibuja la GPU nativa o el respaldo. Implementaciones en `data/`; se elige
/// con `--dart-define=AR_RENDERER=native|painter`.
///
/// Uso: [start] una vez, después [applyRecipe] cada vez que cambia el look, y
/// [stop] al salir. Los pedidos no se encolan del lado del motor: llamar de
/// nuevo con el estado completo.
abstract interface class IMakeupRenderer {
  /// Abre la cámara y empieza a dibujar. null si este renderer no puede
  /// mostrar maquillaje en este equipo; el motivo queda en [unavailableReason].
  Future<MakeupSurface?> start();

  /// Por qué [start] devolvió null (texto de depuración, no se traduce).
  String? get unavailableReason;

  /// Receta a dibujar (ya validada); null = sin maquillaje.
  Future<void> applyRecipe(MakeupRecipe? recipe);

  /// Puntos de la malla encima de la imagen (depuración).
  Future<void> setShowLandmarks(bool show);

  /// Adaptar los colores de la receta al color de la luz de la escena (por
  /// defecto sí). Apagada solo para comparar en el arnés.
  Future<void> setLightAdaptation(bool enabled);

  Future<MakeupRendererStats> stats();

  /// Libera cámara y GPU. Seguro de llamar más de una vez.
  Future<void> stop();
}

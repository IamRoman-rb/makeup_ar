import '../domain/i_makeup_renderer.dart';
import '../domain/makeup_recipe.dart';

/// Respaldo (`AR_RENDERER=painter`): no dibuja maquillaje. La app muestra el
/// espejo normal con un aviso. No usa cámara ni GPU.
final class MirrorFallbackRenderer implements IMakeupRenderer {
  const MirrorFallbackRenderer();

  @override
  String? get unavailableReason => 'AR_RENDERER=painter';

  @override
  Future<MakeupSurface?> start() async => null;

  @override
  Future<void> applyRecipe(MakeupRecipe? recipe) async {}

  @override
  Future<void> setShowLandmarks(bool show) async {}

  @override
  Future<void> setLightAdaptation(bool enabled) async {}

  @override
  Future<MakeupRendererStats> stats() async => MakeupRendererStats.empty;

  @override
  Future<void> stop() async {}
}

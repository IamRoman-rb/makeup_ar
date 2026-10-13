import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:makeup_engine/makeup_engine.dart';

import '../domain/i_makeup_renderer.dart';
import '../domain/makeup_recipe.dart';

/// Motor nativo (C++/GLES, `packages/makeup_engine`): cámara → GPU → tracker →
/// capas de la receta → `Texture`.
///
/// Si el motor no puede iniciar (sin GLES 3, sin cámara), [start] devuelve
/// null y la app usa el respaldo. Los pedidos posteriores que el motor
/// rechace (p. ej. porque ya se detuvo con un pedido en vuelo) se descartan:
/// el próximo pedido manda el estado completo.
final class NativeGpuMakeupRenderer implements IMakeupRenderer {
  NativeGpuMakeupRenderer({MakeupEngine? engine}) : _engine = engine ?? MakeupEngine();

  final MakeupEngine _engine;
  bool _showLandmarks = false;
  bool _lightAdaptation = true;
  String? _unavailableReason;

  @override
  String? get unavailableReason => _unavailableReason;

  @override
  Future<MakeupSurface?> start() async {
    try {
      final info = await _engine.start();
      await _applyRenderOptions();
      return MakeupSurface(textureId: info.textureId, width: info.width, height: info.height);
    } on MakeupEngineException catch (e) {
      _unavailableReason = '${e.code}: ${e.message ?? ''}';
      return null;
    }
  }

  @override
  Future<void> applyRecipe(MakeupRecipe? recipe) async {
    try {
      await _engine.setRecipe(recipe?.toJson() ?? const {'schema': kMakeupRecipeSchemaV2, 'name': 'none'});
    } on PlatformException catch (e) {
      _discarded('applyRecipe', e);
    }
  }

  @override
  Future<void> setShowLandmarks(bool show) async {
    _showLandmarks = show;
    await _applyRenderOptions();
  }

  @override
  Future<void> setLightAdaptation(bool enabled) async {
    _lightAdaptation = enabled;
    await _applyRenderOptions();
  }

  @override
  Future<MakeupRendererStats> stats() async {
    try {
      return toRendererStats(await _engine.getStats());
    } on PlatformException catch (e) {
      _discarded('stats', e);
      return MakeupRendererStats.empty;
    }
  }

  @override
  Future<void> stop() => _engine.stop();

  Future<void> _applyRenderOptions() async {
    try {
      // El maquillaje de la receta siempre va sobre la malla tracked.
      await _engine.setRenderOptions(
        showLandmarks: _showLandmarks,
        region: TintRegion.makeup,
        lightAdaptation: _lightAdaptation,
      );
    } on PlatformException catch (e) {
      _discarded('renderOptions', e);
    }
  }

  void _discarded(String what, PlatformException e) {
    debugPrint('NativeGpuMakeupRenderer: $what descartado (${e.code}: ${e.message})');
  }
}

/// Métricas del plugin -> métricas del dominio.
@visibleForTesting
MakeupRendererStats toRendererStats(EngineStats stats) {
  final tracker = stats.tracker;
  final tracking = switch (tracker.state) {
    TrackerState.off => tracker.backend == null ? FaceTrackingState.loading : FaceTrackingState.off,
    TrackerState.searching => FaceTrackingState.searching,
    TrackerState.tracking => FaceTrackingState.tracking,
  };
  return MakeupRendererStats(
    renderFps: stats.renderFps,
    tracking: tracking,
    trackerHz: tracker.hz,
    landmarkMs: tracker.landmarkP50Ms,
    error: stats.error ?? tracker.error,
  );
}

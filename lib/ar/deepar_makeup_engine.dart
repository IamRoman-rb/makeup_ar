import 'package:deepar_flutter/deepar_flutter.dart';
import 'package:flutter/widgets.dart';
import 'package:vector_math/vector_math_64.dart';

import 'ar_engine_config.dart';
import 'ar_makeup_engine.dart';
import 'deepar_node_mapping.dart';

/// Motor AR sobre el SDK nativo de DeepAR. Carga un único efecto
/// paramétrico (`ArEngineConfig.baseEffectAssetPath`) y traduce la receta de
/// maquillaje (la misma que ya genera el prompt de IA) a llamadas
/// `changeParameter` en vivo, en vez de dibujar un overlay con Canvas.
class DeepArMakeupEngine extends ArMakeupEngine {
  DeepArMakeupEngine({DeepArController? controller}) : _controller = controller ?? DeepArController();

  final DeepArController _controller;

  Map<String, dynamic> _lastRecipe = const {};
  bool _isReady = false;
  bool _isEffectOn = true;

  @override
  bool get isReady => _isReady;

  @override
  Future<void> initialize() async {
    final ok = await _controller.initialize(
      androidLicenseKey: ArEngineConfig.deepArAndroidLicenseKey,
      iosLicenseKey: ArEngineConfig.deepArIosLicenseKey,
      resolution: Resolution.high,
    );

    if (!ok) {
      debugPrint('DeepAR no pudo inicializarse (permisos denegados o license key inválida).');
      return;
    }

    await _controller.switchEffect(ArEngineConfig.baseEffectAssetPath);
    _isReady = true;
    notifyListeners();
  }

  @override
  Widget buildPreview() => _controller.buildPreview();

  @override
  Future<void> setEffectEnabled(bool enabled) async {
    _isEffectOn = enabled;
    await _controller.switchEffect(enabled ? ArEngineConfig.baseEffectAssetPath : null);
    if (enabled && _lastRecipe.isNotEmpty) {
      await applyRecipe(_lastRecipe);
    }
  }

  @override
  Future<void> applyRecipe(Map<String, dynamic> recipe) async {
    _lastRecipe = recipe;
    if (!_isReady || !_isEffectOn) return;

    await _applyColorFeature(recipe['lips'], DeepArMakeupNodes.lips);
    await _applyColorFeature(recipe['blush'], DeepArMakeupNodes.blush);

    final eyes = recipe['eyes'];
    if (eyes is Map) {
      await _applyColorFeature(eyes['eyeshadow'], DeepArMakeupNodes.eyeshadow);
      await _applyColorFeature(eyes['eyeliner'], DeepArMakeupNodes.eyeliner);
      await _applyOpacityFeature(eyes['eyelashes'], DeepArMakeupNodes.eyelashes);
    }
  }

  Future<void> _applyColorFeature(dynamic featureData, String gameObject) async {
    if (featureData is! Map || featureData['enabled'] != true) return;

    final opacity = (featureData['opacity'] as num?)?.toDouble() ?? 0.5;
    final color = _hexToVector4(featureData['color'] as String?, opacity);

    await _controller.changeParameter(
      gameObject: gameObject,
      component: DeepArMakeupNodes.colorComponent,
      parameter: DeepArMakeupNodes.colorParameter,
      newParameter: color,
    );
  }

  /// Para features sin color propio (pestañas), solo ajusta una intensidad.
  Future<void> _applyOpacityFeature(dynamic featureData, String gameObject) async {
    if (featureData is! Map || featureData['enabled'] != true) return;

    final density = (featureData['density'] as num?)?.toDouble() ?? 0.65;

    await _controller.changeParameter(
      gameObject: gameObject,
      component: DeepArMakeupNodes.colorComponent,
      parameter: DeepArMakeupNodes.opacityParameter,
      newParameter: density,
    );
  }

  Vector4 _hexToVector4(String? hex, double opacity) {
    final fallback = Vector4(0.8, 0.2, 0.3, opacity);
    final value = hex?.replaceAll('#', '') ?? '';
    if (value.length != 6) return fallback;

    try {
      final r = int.parse(value.substring(0, 2), radix: 16) / 255;
      final g = int.parse(value.substring(2, 4), radix: 16) / 255;
      final b = int.parse(value.substring(4, 6), radix: 16) / 255;
      return Vector4(r, g, b, opacity);
    } on FormatException {
      return fallback;
    }
  }

  @override
  void dispose() {
    _controller.destroy();
    super.dispose();
  }
}

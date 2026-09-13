import 'deepar_keys.dart';

/// Punto único para elegir el motor de renderizado AR y para la
/// configuración de DeepAR que ese motor necesita.
///
/// Las license keys viven en `deepar_keys.dart` (ignorado por git, ver
/// `deepar_keys.example.dart`), no acá, para no commitear secretos.
class ArEngineConfig {
  const ArEngineConfig._();

  /// Poné esto en `true` recién cuando exista
  /// `assets/ar_effects/makeup_base.deepar` (ver el README en esa carpeta).
  /// Hasta entonces DeepAR no tiene qué efecto cargar, así que la app usa el
  /// motor legacy (ML Kit + CustomPainter).
  static const bool useDeepAr = false;

  static const String deepArAndroidLicenseKey = DeepArKeys.android;

  static const String deepArIosLicenseKey = DeepArKeys.ios;

  static const String baseEffectAssetPath = 'assets/ar_effects/makeup_base.deepar';
}

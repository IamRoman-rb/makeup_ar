/// Nombres de los game objects/parámetros que [DeepArMakeupEngine] espera
/// encontrar en `assets/ar_effects/makeup_base.deepar`.
///
/// Estos son placeholders: tienen que coincidir exactamente con cómo se
/// llamen los nodos cuando armes el efecto en DeepAR Studio. Si les ponés
/// otros nombres allá, este es el único archivo que hay que actualizar.
class DeepArMakeupNodes {
  const DeepArMakeupNodes._();

  static const String lips = 'Lips';
  static const String blush = 'Blush';
  static const String eyeshadow = 'Eyeshadow';
  static const String eyeliner = 'Eyeliner';
  static const String eyelashes = 'Eyelashes';

  /// Componente y parámetros que se ajustan sobre cada game object de
  /// arriba. Asume un material con un color RGBA ajustable; si el efecto
  /// expone otra cosa (por ejemplo un slider de intensidad separado en vez
  /// de alpha), ajustar `_applyFeature` en deepar_makeup_engine.dart.
  static const String colorComponent = 'material';
  static const String colorParameter = 'color';
  static const String opacityParameter = 'opacity';
}

/// Nombres de los game objects/parámetros que [DeepArMakeupEngine] espera
/// encontrar en `assets/ar_effects/makeup_base.deepar`.
///
/// `lips`/`blush`/etc. son placeholders: tienen que coincidir exactamente
/// con cómo se llamen los nodos cuando armes el efecto en DeepAR Studio.
///
/// `colorComponent`/`colorParameter` en cambio son la convención real de
/// DeepAR para tocar un color en runtime (confirmado contra
/// docs.deepar.ai/deepar-sdk/tutorials/change-parameter/): el componente
/// siempre es `"MeshRenderer"`, y el parámetro es el nombre del uniform que
/// use el shader del material asignado a ese nodo (se ve en el panel de
/// Materials de Studio, o en el .json del shader dentro de
/// Contents/Resources/shaders). `u_color` es el uniform típico de los
/// shaders básicos de DeepAR, pero hay que confirmarlo contra el material
/// real que le asignes a cada nodo — si usa otro shader, el nombre puede
/// ser distinto.
class DeepArMakeupNodes {
  const DeepArMakeupNodes._();

  static const String lips = 'Lips';
  static const String blush = 'Blush';
  static const String eyeshadow = 'Eyeshadow';
  static const String eyeliner = 'Eyeliner';
  static const String eyelashes = 'Eyelashes';

  static const String colorComponent = 'MeshRenderer';
  static const String colorParameter = 'u_color';

  /// Para pestañas (sin color propio): mismo mecanismo, pero apuntando al
  /// uniform de intensidad/densidad que exponga el shader que le asignes.
  /// Nombre también a confirmar contra el shader real.
  static const String opacityParameter = 'u_opacity';
}

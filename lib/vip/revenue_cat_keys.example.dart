/// Plantilla para tus claves de RevenueCat.
///
/// Copiá este archivo como `revenue_cat_keys.dart` (mismo directorio) y
/// completá con los valores reales de tu proyecto en
/// https://app.revenuecat.com. `revenue_cat_keys.dart` está en
/// `.gitignore` — nunca se sube al repo, así que cada máquina/CI necesita
/// su propia copia local.
class RevenueCatKeys {
  const RevenueCatKeys._();

  static const String android = 'TU_API_KEY_PUBLICA_DE_GOOGLE_PLAY';
  static const String ios = 'TU_API_KEY_PUBLICA_DE_APP_STORE';

  /// El identifier del entitlement que desbloquea los tutoriales VIP, tal
  /// como lo hayas llamado en el dashboard de RevenueCat (pestaña
  /// Entitlements). Si en tu proyecto se llama distinto, cambialo acá.
  static const String entitlementId = 'vip';
}

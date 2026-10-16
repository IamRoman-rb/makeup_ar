/// Configuración de RevenueCat por `--dart-define` (AUDIT.md §5.3): las keys
/// públicas (`goog_...`, `appl_...`) entran al compilar desde un JSON local
/// fuera de git, así un clon limpio compila sin archivos ignorados:
///
///     flutter run --dart-define-from-file=env/revenuecat.json
///
/// Plantilla en `env/revenuecat.example.json`. Sin key, el VIP queda
/// desactivado (VipService.isAvailable == false) y la app sigue andando.
abstract final class RevenueCatConfig {
  static const String androidKey = String.fromEnvironment('RC_ANDROID_KEY');
  static const String iosKey = String.fromEnvironment('RC_IOS_KEY');

  /// Identifier del entitlement VIP en RevenueCat. Tiene que coincidir con el
  /// parámetro VIP_ENTITLEMENT del webhook (functions/src/index.ts).
  static const String entitlementId = String.fromEnvironment('RC_ENTITLEMENT', defaultValue: 'vip');

  static String keyFor({required bool apple}) => apple ? iosKey : androidKey;
}

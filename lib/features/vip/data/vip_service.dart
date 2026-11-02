import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'package:ar_makeup_app/features/vip/data/revenue_cat_config.dart';

/// Wrapper sobre el SDK de RevenueCat para la suscripción VIP que
/// desbloquea los videos de los tutoriales.
///
/// Sin servidor no hay webhook: el vencimiento del entitlement lo informa el
/// SDK en el teléfono ([purchase], [restore], [activeUntil]) y la app lo
/// guarda en el usuario local (IAuthRepository.setPremiumUntil). Cuando haya
/// servidor, el webhook vuelve a ser la fuente (docs/ar_engine/LOCAL_DB.md).
///
/// Sin key de RevenueCat (ver [RevenueCatConfig]) el SDK no se configura:
/// [isAvailable] es false y ninguna operación lo toca.
class VipService {
  const VipService._();

  static bool _configured = false;
  static bool _available = false;

  /// true si el SDK quedó configurado con una key.
  static bool get isAvailable => _available;

  /// Llamar una sola vez al arrancar la app (ver main.dart).
  static Future<void> configure() async {
    if (_configured) return;

    final apiKey = RevenueCatConfig.keyFor(apple: Platform.isIOS || Platform.isMacOS);
    if (apiKey.isEmpty) {
      _configured = true;
      debugPrint('VipService: sin key de RevenueCat (--dart-define-from-file=env/revenuecat.json); VIP desactivado.');
      return;
    }
    // Se marca recién si sale bien: si tira, el "Reintentar" del splash
    // (AppServices.retry) vuelve a intentarlo.
    await Purchases.configure(PurchasesConfiguration(apiKey));
    _configured = true;
    _available = true;
  }

  /// Ata las compras al usuario local [userId], para que la suscripción se
  /// reconozca en otro dispositivo con la misma cuenta.
  static Future<void> loginUser(String userId) async {
    if (!_available) return;
    try {
      await Purchases.logIn(userId);
    } catch (e) {
      // Sin el detalle: el mensaje del SDK puede incluir el id del usuario.
      debugPrint('VipService: Purchases.logIn falló (${e.runtimeType})');
    }
  }

  /// Desata el SDK del usuario local (al borrar la cuenta): RevenueCat pasa a
  /// un id anónimo nuevo y deja de asociar este teléfono con esa cuenta. Los
  /// registros que RevenueCat ya tiene de ese id se borran del lado del
  /// servidor (API REST con la secret key; pendiente, ver
  /// docs/compliance/DATA_INVENTORY.md). No tira: un fallo de red no puede
  /// frenar el borrado de la cuenta.
  static Future<bool> logOutUser() async {
    if (!_available) return true;
    try {
      if (await Purchases.isAnonymous) return true;
      await Purchases.logOut();
      return true;
    } catch (e) {
      debugPrint('VipService: logOut falló (${e.runtimeType})');
      return false;
    }
  }

  /// Enlace de la tienda para gestionar o cancelar la suscripción, si
  /// RevenueCat lo informa; null sin RevenueCat, sin suscripción o sin red.
  static Future<String?> managementUrl() async {
    if (!_available) return null;
    try {
      return (await Purchases.getCustomerInfo()).managementURL;
    } catch (e) {
      debugPrint('VipService: sin managementURL (${e.runtimeType})');
      return null;
    }
  }

  /// null sin RevenueCat configurado.
  static Future<Offering?> fetchCurrentOffering() async {
    if (!_available) return null;
    final offerings = await Purchases.getOfferings();
    return offerings.current;
  }

  /// Compra el paquete. Devuelve el vencimiento del VIP si RevenueCat
  /// confirma el entitlement; null si no quedó activo.
  static Future<DateTime?> purchase(Package package) async {
    if (!_available) throw StateError('RevenueCat no está configurado.');
    final result = await Purchases.purchase(PurchaseParams.package(package));
    return _until(result.customerInfo);
  }

  /// Restaura compras previas (requisito de las tiendas). Devuelve el
  /// vencimiento del VIP si lo encontró activo; null si no, o sin RevenueCat.
  static Future<DateTime?> restore() async {
    if (!_available) return null;
    return _until(await Purchases.restorePurchases());
  }

  /// Vencimiento del VIP según RevenueCat ahora; null si no está activo o
  /// sin RevenueCat. Hace una consulta de red: no llamar en el arranque con
  /// await.
  static Future<DateTime?> activeUntil() async {
    if (!_available) return null;
    return _until(await Purchases.getCustomerInfo());
  }

  static DateTime? _until(CustomerInfo info) {
    final entitlement = info.entitlements.all[RevenueCatConfig.entitlementId];
    return untilFrom(isActive: entitlement?.isActive ?? false, expirationDate: entitlement?.expirationDate);
  }

  /// Vencimiento de un entitlement: null si no está activo; sin fecha
  /// (compra de por vida) o con fecha ilegible pero activo, [lifetime].
  @visibleForTesting
  static DateTime? untilFrom({required bool isActive, String? expirationDate}) {
    if (!isActive) return null;
    final parsed = expirationDate == null ? null : DateTime.tryParse(expirationDate);
    return parsed ?? lifetime;
  }

  /// Vencimiento de un VIP sin fecha de fin.
  static final DateTime lifetime = DateTime.utc(9999);
}

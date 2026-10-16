import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'revenue_cat_config.dart';

/// Wrapper sobre el SDK de RevenueCat para la suscripción VIP que
/// desbloquea los videos de los tutoriales.
///
/// El cliente no escribe el estado VIP (firestore.rules lo prohíbe): lo pone
/// el webhook de RevenueCat en `users/{uid}.premium_until` segundos después de
/// la compra (functions/src/revenueCatWebhook.ts, AUDIT.md §5.2).
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
    _configured = true;

    final apiKey = RevenueCatConfig.keyFor(apple: Platform.isIOS || Platform.isMacOS);
    if (apiKey.isEmpty) {
      debugPrint('VipService: sin key de RevenueCat (--dart-define-from-file=env/revenuecat.json); VIP desactivado.');
      return;
    }
    await Purchases.configure(PurchasesConfiguration(apiKey));
    _available = true;
  }

  /// Ata las compras al usuario logueado de Firebase, para que la
  /// suscripción se reconozca aunque cambie de dispositivo.
  static Future<void> loginCurrentUser() async {
    if (!_available) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await Purchases.logIn(uid);
    } catch (e) {
      debugPrint('Error en Purchases.logIn: $e');
    }
  }

  /// null sin RevenueCat configurado.
  static Future<Offering?> fetchCurrentOffering() async {
    if (!_available) return null;
    final offerings = await Purchases.getOfferings();
    return offerings.current;
  }

  /// Compra el paquete. Devuelve true si RevenueCat confirma el entitlement
  /// VIP; el acceso a los videos llega con el webhook.
  static Future<bool> purchase(Package package) async {
    if (!_available) throw StateError('RevenueCat no está configurado.');
    final result = await Purchases.purchase(PurchaseParams.package(package));
    return result.customerInfo.entitlements.all[RevenueCatConfig.entitlementId]?.isActive ?? false;
  }

  /// Restaura compras previas (requisito de las tiendas). Devuelve true si
  /// encontró el entitlement VIP activo; false sin RevenueCat configurado.
  static Future<bool> restore() async {
    if (!_available) return false;
    final customerInfo = await Purchases.restorePurchases();
    return customerInfo.entitlements.all[RevenueCatConfig.entitlementId]?.isActive ?? false;
  }
}

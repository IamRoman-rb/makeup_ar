import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'revenue_cat_keys.dart';

/// Wrapper sobre el SDK de RevenueCat para la suscripción VIP que
/// desbloquea los videos de los tutoriales.
///
/// El cliente no escribe el estado VIP (firestore.rules lo prohíbe): lo pone
/// el webhook de RevenueCat en `users/{uid}.premium_until` segundos después de
/// la compra (functions/src/revenueCatWebhook.ts, AUDIT.md §5.2).
class VipService {
  const VipService._();

  static bool _configured = false;

  /// Llamar una sola vez al arrancar la app (ver main.dart).
  static Future<void> configure() async {
    if (_configured) return;
    _configured = true;

    final apiKey = Platform.isIOS || Platform.isMacOS ? RevenueCatKeys.ios : RevenueCatKeys.android;
    await Purchases.configure(PurchasesConfiguration(apiKey));
  }

  /// Ata las compras al usuario logueado de Firebase, para que la
  /// suscripción se reconozca aunque cambie de dispositivo.
  static Future<void> loginCurrentUser() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await Purchases.logIn(uid);
    } catch (e) {
      debugPrint('Error en Purchases.logIn: $e');
    }
  }

  static Future<Offering?> fetchCurrentOffering() async {
    final offerings = await Purchases.getOfferings();
    return offerings.current;
  }

  /// Compra el paquete. Devuelve true si RevenueCat confirma el entitlement
  /// VIP; el acceso a los videos llega con el webhook.
  static Future<bool> purchase(Package package) async {
    final result = await Purchases.purchase(PurchaseParams.package(package));
    return result.customerInfo.entitlements.all[RevenueCatKeys.entitlementId]?.isActive ?? false;
  }

  /// Restaura compras previas (requisito de las tiendas). Devuelve true si
  /// encontró el entitlement VIP activo.
  static Future<bool> restore() async {
    final customerInfo = await Purchases.restorePurchases();
    return customerInfo.entitlements.all[RevenueCatKeys.entitlementId]?.isActive ?? false;
  }
}

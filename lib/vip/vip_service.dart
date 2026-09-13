import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'revenue_cat_keys.dart';

/// Wrapper sobre el SDK de RevenueCat para la suscripción VIP que
/// desbloquea los videos de los tutoriales.
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

  /// Compra el paquete. Devuelve true si terminó con el entitlement VIP
  /// activo (y en ese caso ya sincronizó `users/{uid}.is_premium`).
  static Future<bool> purchase(Package package) async {
    final result = await Purchases.purchase(PurchaseParams.package(package));
    final isVip = result.customerInfo.entitlements.all[RevenueCatKeys.entitlementId]?.isActive ?? false;
    if (isVip) await _syncPremiumFlag(true);
    return isVip;
  }

  /// Restaura compras previas (requisito de las tiendas). Devuelve true si
  /// encontró el entitlement VIP activo.
  static Future<bool> restore() async {
    final customerInfo = await Purchases.restorePurchases();
    final isVip = customerInfo.entitlements.all[RevenueCatKeys.entitlementId]?.isActive ?? false;
    await _syncPremiumFlag(isVip);
    return isVip;
  }

  static Future<void> _syncPremiumFlag(bool isPremium) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await FirebaseFirestore.instance.collection('users').doc(uid).set(
      {'is_premium': isPremium},
      SetOptions(merge: true),
    );
  }
}

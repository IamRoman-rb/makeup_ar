import 'package:flutter/foundation.dart';

import '../domain/app_user.dart';
import 'profile_photo_store.dart';

enum AccountDeletionResult {
  /// Se borró todo lo que la app guarda.
  deleted,

  /// La cuenta y la base se borraron, pero quedó algún archivo de foto.
  deletedWithLeftovers,

  /// No se borró nada (la transacción de la base falló): se puede reintentar.
  failed,
  notSignedIn,
}

/// Borrado de la cuenta en todo lo que la app alcanza (Ley 25.326 art. 16;
/// App Store 5.1.1(v); política de borrado de cuentas de Google Play):
///
/// 1. La base, en una transacción ([IAuthRepository.deleteAccount]): si
///    falla, no se borró nada y se puede reintentar.
/// 2. Las fotos de perfil del usuario (todas, también restos de cambios
///    anteriores).
/// 3. RevenueCat deja de asociar el teléfono con esa cuenta (logOut). Los
///    registros que RevenueCat ya guardó se borran desde el servidor (API
///    REST con la secret key): pendiente, docs/compliance/DATA_INVENTORY.md.
///
/// La suscripción de la tienda no se cancela: eso lo hace la persona en la
/// tienda, y el diálogo de borrado lo avisa.
final class AccountDeletion {
  AccountDeletion({required this.auth, required this.photos, required this.logOutPurchases});

  final IAuthRepository auth;
  final ProfilePhotoStore photos;

  /// true si RevenueCat quedó desatado (o no estaba configurado).
  final Future<bool> Function() logOutPurchases;

  Future<AccountDeletionResult> run() async {
    final user = auth.currentUser;
    if (user == null) return AccountDeletionResult.notSignedIn;
    try {
      await auth.deleteAccount();
    } catch (e) {
      debugPrint('Borrado de cuenta falló (${e.runtimeType})');
      return AccountDeletionResult.failed;
    }

    var leftovers = false;
    try {
      await photos.deleteAllFor(user.id);
    } catch (e) {
      debugPrint('Fotos de perfil sin borrar (${e.runtimeType})');
      leftovers = true;
    }
    // No cambia lo que se ve: el id de RevenueCat es aleatorio y la próxima
    // cuenta hace logIn con el suyo. Queda en el log para diagnosticar.
    if (!await logOutPurchases()) debugPrint('RevenueCat sigue con el id de la cuenta borrada');
    return leftovers ? AccountDeletionResult.deletedWithLeftovers : AccountDeletionResult.deleted;
  }
}

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:ar_makeup_app/features/auth/data/drift_auth_repository.dart';
import 'package:ar_makeup_app/features/auth/data/profile_photo_store.dart';
import 'package:ar_makeup_app/features/auth/domain/app_user.dart';
import 'package:ar_makeup_app/features/catalog/data/catalog_seed.dart';
import 'package:ar_makeup_app/features/catalog/data/drift_catalog_repository.dart';
import 'package:ar_makeup_app/features/catalog/domain/catalog_look.dart';
import 'package:ar_makeup_app/features/my_looks/data/drift_ai_look_repository.dart';
import 'package:ar_makeup_app/features/my_looks/domain/ai_look.dart';
import 'package:ar_makeup_app/features/studio/data/drift_look_repository.dart';
import 'package:ar_makeup_app/features/studio/data/local_recipe_generator.dart';
import 'package:ar_makeup_app/features/studio/domain/recipe_generator.dart';
import 'package:ar_makeup_app/features/studio/domain/studio_look.dart';
import 'package:ar_makeup_app/features/vip/data/vip_service.dart';
import 'package:ar_makeup_app/shared/data/local_db/app_database.dart';
import 'package:ar_makeup_app/startup_trace.dart';

/// Servicios de la app: la base local, los repositorios y RevenueCat.
///
/// Arrancan después de runApp, en paralelo con el splash (docs/ar_engine/
/// STARTUP.md). La base se abre en un isolate de fondo (drift_flutter) y la
/// primera consulta (la sesión guardada) espera a que esté lista.
abstract final class AppServices {
  static Future<void>? _ready;
  static AppDatabase? _database;
  static IAuthRepository? _auth;
  static ICatalogRepository? _catalog;
  static ISavedLooksRepository? _savedLooks;
  static ProfilePhotoStore? _photos;
  static IRecipeGenerator _generator = const LocalRecipeGenerator();

  /// Completa cuando todo está listo; si falla, el splash ofrece [retry].
  static Future<void> get ready => _ready ??= _init();

  /// Vuelve a intentar después de un error.
  static Future<void> retry() {
    _ready = null;
    return ready;
  }

  static Future<void> _init() async {
    // Un reintento no abre la base dos veces si la primera vez llegó a hacerlo.
    final database = _database ??= AppDatabase.open(seed: CatalogSeed.insertPresets);
    final auth = _auth ??= DriftAuthRepository(database);
    final user = await auth.restoreSession();
    StartupTrace.mark('db');
    await VipService.configure();
    StartupTrace.mark('revenuecat');
    if (user != null) unawaited(refreshVip(user.id));
  }

  static AppDatabase get database => _database ?? (throw StateError('AppServices.ready todavía no terminó'));

  static IAuthRepository get auth => _auth ?? (throw StateError('AppServices.ready todavía no terminó'));

  static ICatalogRepository get catalog => _catalog ??= DriftCatalogRepository(database);

  static ISavedLooksRepository get savedLooks => _savedLooks ??= DriftSavedLooksRepository(database);

  static ProfilePhotoStore get photos => _photos ??= ProfilePhotoStore();

  /// Sin servidor, el generador local (sin IA).
  static IRecipeGenerator get recipeGenerator => _generator;

  /// Borradores y publicación del Studio, a nombre del admin [uid].
  static ILookRepository studioLooks(String uid) => DriftLookRepository(database, uid: uid);

  /// "Mis looks" de [userId].
  static IAiLookRepository aiLooks(String userId) => DriftAiLookRepository(database, userId: userId);

  /// Después de abrir sesión: ata RevenueCat al usuario y trae su VIP.
  static Future<void> afterSignIn(String userId) => refreshVip(userId);

  /// Trae de RevenueCat el vencimiento del VIP y lo guarda en el usuario.
  /// Sin red o sin key, no cambia nada.
  static Future<void> refreshVip(String userId) async {
    if (!VipService.isAvailable) return;
    try {
      await VipService.loginUser(userId);
      final until = await VipService.activeUntil();
      if (auth.currentUser?.id == userId) await auth.setPremiumUntil(until);
    } catch (e) {
      debugPrint('VIP sin actualizar: $e');
    }
  }

  /// Tests: base en memoria y repositorios a medida, sin [ready].
  @visibleForTesting
  static void useForTesting({
    required AppDatabase database,
    required IAuthRepository auth,
    ICatalogRepository? catalog,
    ISavedLooksRepository? savedLooks,
    ProfilePhotoStore? photos,
    IRecipeGenerator? generator,
  }) {
    _ready = Future<void>.value();
    _database = database;
    _auth = auth;
    _catalog = catalog;
    _savedLooks = savedLooks;
    _photos = photos;
    _generator = generator ?? const LocalRecipeGenerator();
  }
}

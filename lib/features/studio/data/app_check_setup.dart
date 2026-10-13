import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

/// Proveedor de App Check según `--dart-define=APP_CHECK=debug|playIntegrity`.
/// Por defecto: Play Integrity en release y debug en el resto (profile en el
/// E20 incluido). En modo debug el SDK escribe un token en logcat
/// ("DebugAppCheckProvider") que se registra una vez en la consola de
/// Firebase (App Check -> Apps -> Administrar tokens de debug). No se guarda
/// ningún token en el código.
AndroidAppCheckProvider appCheckProvider({String? mode, bool? release}) {
  final selected = mode ?? const String.fromEnvironment('APP_CHECK');
  final isRelease = release ?? kReleaseMode;
  return switch (selected) {
    'debug' => const AndroidDebugProvider(),
    'playIntegrity' => const AndroidPlayIntegrityProvider(),
    _ => isRelease ? const AndroidPlayIntegrityProvider() : const AndroidDebugProvider(),
  };
}

/// Activa App Check (antes de cualquier llamada a Cloud Functions). Si falla
/// (sin Play Services, por ejemplo), la app sigue: las callables con
/// enforceAppCheck van a responder failed-precondition.
Future<void> activateAppCheck() async {
  try {
    await FirebaseAppCheck.instance.activate(providerAndroid: appCheckProvider());
  } catch (e) {
    debugPrint('App Check no se pudo activar: $e');
  }
}

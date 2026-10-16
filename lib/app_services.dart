import 'package:firebase_core/firebase_core.dart';

import 'package:ar_makeup_app/features/studio/data/app_check_setup.dart';
import 'package:ar_makeup_app/features/vip/data/vip_service.dart';
import 'package:ar_makeup_app/firebase_options.dart';
import 'package:ar_makeup_app/startup_trace.dart';

/// Servicios que la app necesita antes de salir del splash: Firebase, App
/// Check (antes de cualquier Cloud Function) y RevenueCat.
///
/// Arrancan después de runApp, en paralelo con el splash (docs/ar_engine/
/// STARTUP.md): en el E20 Firebase.initializeApp tardaba 666 ms con el hilo
/// principal ocupado y sin ningún frame en pantalla.
abstract final class AppServices {
  static Future<void>? _ready;

  /// Completa cuando todo está listo; si falla, el splash ofrece [retry].
  static Future<void> get ready => _ready ??= _init();

  /// Vuelve a intentar después de un error (sin red, por ejemplo).
  static Future<void> retry() {
    _ready = null;
    return ready;
  }

  static Future<void> _init() async {
    // Un reintento no inicializa dos veces si la primera vez llegó a hacerlo.
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    }
    StartupTrace.mark('firebase');
    await activateAppCheck();
    StartupTrace.mark('app_check');
    await VipService.configure();
    StartupTrace.mark('revenuecat');
  }
}

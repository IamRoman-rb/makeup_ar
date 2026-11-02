import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_services.dart';
import 'l10n/app_localizations.dart';
import 'package:ar_makeup_app/features/auth/presentation/splash_screen.dart';
import 'startup_trace.dart';

void main() {
  // En release no se escribe nada en logcat/consola: los mensajes de error
  // pueden traer ids o rutas internas. Profile y debug siguen logueando
  // (STARTUP, COACH, TRACK: protocolos de medición del E20).
  if (kReleaseMode) debugPrint = _silentDebugPrint;
  StartupTrace.start();
  final binding = WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(_thirdPartyLicenses);
  // La base local y RevenueCat arrancan en paralelo con el splash, que los
  // espera (AppServices.ready) antes de navegar: el primer frame no espera a
  // la base (docs/ar_engine/STARTUP.md).
  runApp(const ARMakeupApp());
  unawaited(AppServices.ready.catchError((Object _) {}));
  binding.waitUntilFirstFrameRasterized.then((_) => StartupTrace.mark('first_frame'));
}

void _silentDebugPrint(String? message, {int? wrapWidth}) {}

/// Licencias que no vienen de un paquete de pub (las de los paquetes las
/// junta Flutter solo): los modelos y la malla de MediaPipe que van dentro
/// del motor (packages/makeup_engine/third_party). Se ven en Perfil >
/// Privacidad y datos > Licencias de terceros.
Stream<LicenseEntry> _thirdPartyLicenses() async* {
  final apache = await rootBundle.loadString('assets/legal/apache-2.0.txt');
  yield LicenseEntryWithLineBreaks(const ['MediaPipe (Face Landmarker, Face Geometry)'], apache);
}

class ARMakeupApp extends StatefulWidget {
  const ARMakeupApp({super.key});

  static void setLocale(BuildContext context, Locale newLocale) {
    _ARMakeupAppState? state = context.findAncestorStateOfType<_ARMakeupAppState>();
    state?.setLocale(newLocale);
  }

  @override
  State<ARMakeupApp> createState() => _ARMakeupAppState();
}

class _ARMakeupAppState extends State<ARMakeupApp> {
  Locale? _locale;

  void setLocale(Locale locale) {
    setState(() {
      _locale = locale;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
      debugShowCheckedModeBanner: false,
      locale: _locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(
        primaryColor: const Color(0xFFD4AF37), // Dorado
      ),
      home: const SplashScreen(),
    );
  }
}
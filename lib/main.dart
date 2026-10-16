import 'dart:async';

import 'package:flutter/material.dart';
import 'app_services.dart';
import 'l10n/app_localizations.dart';
import 'package:ar_makeup_app/features/auth/presentation/splash_screen.dart';
import 'startup_trace.dart';

void main() {
  StartupTrace.start();
  final binding = WidgetsFlutterBinding.ensureInitialized();
  // Firebase, App Check y RevenueCat arrancan en paralelo con el splash, que
  // los espera (AppServices.ready) antes de navegar: el primer frame no
  // espera a Firebase (docs/ar_engine/STARTUP.md).
  runApp(const ARMakeupApp());
  unawaited(AppServices.ready.catchError((Object _) {}));
  binding.waitUntilFirstFrameRasterized.then((_) => StartupTrace.mark('first_frame'));
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
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'features/studio/data/app_check_setup.dart';
import 'firebase_options.dart';
import 'l10n/app_localizations.dart';
import 'package:ar_makeup_app/features/auth/presentation/splash_screen.dart';
import 'startup_trace.dart';
import 'package:ar_makeup_app/features/vip/data/vip_service.dart';

void main() async {
  StartupTrace.start();
  final binding = WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  StartupTrace.mark('firebase');
  // Antes de cualquier Cloud Function (generateRecipe exige App Check).
  await activateAppCheck();
  StartupTrace.mark('app_check');
  await VipService.configure();
  StartupTrace.mark('revenuecat');
  runApp(const ARMakeupApp());
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
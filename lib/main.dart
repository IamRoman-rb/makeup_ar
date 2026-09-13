import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'l10n/app_localizations.dart';
import 'splash_screen.dart';
import 'login_screen.dart';
import 'vip/vip_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await VipService.configure();
  runApp(const ARMakeupApp());
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
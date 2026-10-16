import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ar_makeup_app/features/auth/presentation/login_screen.dart';
import 'package:ar_makeup_app/features/catalog/presentation/catalog_screen.dart';
import 'package:ar_makeup_app/app_services.dart';
import 'package:ar_makeup_app/l10n/app_localizations.dart';
import 'package:ar_makeup_app/startup_trace.dart';

/// Tiempo mínimo con el logo en pantalla. Antes eran 3 s fijos: en el E20 el
/// splash era el 65 % del arranque (docs/ar_engine/STARTUP.md).
const Duration kMinSplashDuration = Duration(milliseconds: 800);

/// Completa cuando [ready] terminó y pasó [minimum], lo que ocurra último.
/// Si [ready] falla, falla igual.
Future<void> splashGate(Future<void> ready, {Duration minimum = kMinSplashDuration}) async {
  await Future.wait<void>([ready, Future<void>.delayed(minimum)]);
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    // El logo termina de aparecer antes del mínimo del splash.
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_animationController);

    _animationController.forward();
    _navigateToNext();
  }

  Future<void> _navigateToNext({bool retry = false}) async {
    if (_failed) setState(() => _failed = false);
    try {
      await splashGate(retry ? AppServices.retry() : AppServices.ready);
    } catch (e) {
      debugPrint('No se pudieron iniciar los servicios: $e');
      if (mounted) setState(() => _failed = true);
      return;
    }

    if (!mounted) return;

    // Magia de Firebase: Verificamos si ya hay una sesión activa
    final user = FirebaseAuth.instance.currentUser;
    StartupTrace.mark(user != null ? 'splash_done_catalog' : 'splash_done_login');

    // Navegación con transición suave (Fade)
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
        user != null ? const CatalogScreen() : const LoginScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 800),
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A), // Fondo negro premium
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Cuando tengas tu logo, puedes cambiar este Icon por un Image.asset
              const Icon(Icons.auto_awesome, color: Color(0xFFD4AF37), size: 60),
              const SizedBox(height: 20),
              Text(
                'GLAMOUR',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFD4AF37),
                  letterSpacing: 4.0,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Lumière Beauty',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.white70,
                  letterSpacing: 2.0,
                ),
              ),
              if (_failed) ...[
                const SizedBox(height: 30),
                Text(
                  AppLocalizations.of(context)!.startupError,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(color: Colors.white70, fontSize: 13),
                ),
                TextButton(
                  onPressed: () => _navigateToNext(retry: true),
                  child: Text(AppLocalizations.of(context)!.commonRetry,
                      style: const TextStyle(color: Color(0xFFD4AF37))),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
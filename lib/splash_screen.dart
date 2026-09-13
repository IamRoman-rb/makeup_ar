import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_screen.dart';
import 'catalog_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    // Configuramos una animación de 2 segundos
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_animationController);

    _animationController.forward();
    _navigateToNext();
  }

  Future<void> _navigateToNext() async {
    // Simulamos un tiempo de carga para que el usuario aprecie el logo
    await Future.delayed(const Duration(seconds: 3));

    if (!mounted) return;

    // Magia de Firebase: Verificamos si ya hay una sesión activa
    final user = FirebaseAuth.instance.currentUser;

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
            ],
          ),
        ),
      ),
    );
  }
}
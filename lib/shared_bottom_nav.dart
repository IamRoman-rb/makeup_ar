import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'camera_screen.dart';
import 'catalog_screen.dart';
import 'profile_screen.dart';
import 'l10n/app_localizations.dart'; // <-- 1. Importación del traductor

class SharedBottomNav extends StatelessWidget {
  final int currentIndex;

  const SharedBottomNav({super.key, required this.currentIndex});

  void _onItemTapped(BuildContext context, int index) {
    if (index == currentIndex) return;

    Widget nextScreen;
    switch (index) {
      case 0:
        nextScreen = const CatalogScreen();
        break;
      case 1:
        nextScreen = const ProfileScreen();
        break;
      case 2:
        nextScreen = const CameraScreen();
        break;
      default:
        return;
    }

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation1, animation2) => nextScreen,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!; // <-- 2. Instancia del traductor

    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      backgroundColor: const Color(0xFFFDF7F8),
      selectedItemColor: const Color(0xFFE91E63),
      unselectedItemColor: Colors.grey,
      selectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12),
      unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.normal, fontSize: 12),
      currentIndex: currentIndex,
      onTap: (index) => _onItemTapped(context, index),
      items: [
        BottomNavigationBarItem(icon: const Icon(Icons.grid_view), label: l10n.explore), // <-- Traducido
        BottomNavigationBarItem(icon: const Icon(Icons.person_outline), label: l10n.profile), // <-- Traducido
        BottomNavigationBarItem(icon: const Icon(Icons.camera_front_outlined), label: l10n.mirror),
      ],
    );
  }
}
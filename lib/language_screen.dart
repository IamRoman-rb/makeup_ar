import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'main.dart'; // Necesario para acceder a ARMakeupApp.setLocale
import 'l10n/app_localizations.dart'; // <-- 1. Importación del traductor

class LanguageScreen extends StatelessWidget {
  const LanguageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Obtenemos el idioma actual para saber cuál botón resaltar
    final currentLocaleCode = Localizations.localeOf(context).languageCode;
    final l10n = AppLocalizations.of(context)!; // <-- 2. Instancia del traductor

    return Scaffold(
      backgroundColor: const Color(0xFFFDF7F8),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1A1A1A)),
        title: Text(
          l10n.selectLanguageTitle, // <-- Traducido
          style: GoogleFonts.playfairDisplay(color: const Color(0xFF1A1A1A), fontWeight: FontWeight.bold),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Text(
              l10n.selectLanguageDesc, // <-- Traducido
              style: GoogleFonts.inter(color: Colors.grey.shade700, fontSize: 16),
            ),
            const SizedBox(height: 30),

            // Opción: INGLÉS (Se deja en inglés intencionalmente)
            _buildLanguageOption(
              context,
              title: 'English',
              localeCode: 'en',
              flag: '🇺🇸',
              isSelected: currentLocaleCode == 'en',
            ),

            const SizedBox(height: 15),

            // Opción: ESPAÑOL (Se deja en español intencionalmente)
            _buildLanguageOption(
              context,
              title: 'Español',
              localeCode: 'es',
              flag: '🇪🇸',
              isSelected: currentLocaleCode == 'es',
            ),

            const SizedBox(height: 15),

            // Opción: PORTUGUÉS
            _buildLanguageOption(
              context,
              title: 'Português',
              localeCode: 'pt',
              flag: '🇧🇷', // O puedes usar 🇵🇹
              isSelected: currentLocaleCode == 'pt',
            ),

            const SizedBox(height: 15),

            // Opción: FRANCÉS
            _buildLanguageOption(
              context,
              title: 'Français',
              localeCode: 'fr',
              flag: '🇫🇷',
              isSelected: currentLocaleCode == 'fr',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageOption(BuildContext context, {required String title, required String localeCode, required String flag, required bool isSelected}) {
    return InkWell(
      onTap: () {
        // ¡Aquí ocurre la magia! Cambiamos el idioma global de la app
        ARMakeupApp.setLocale(context, Locale(localeCode));
      },
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: isSelected ? const Color(0xFFD4AF37) : Colors.transparent, // Borde dorado si está seleccionado
            width: 2,
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))
          ],
        ),
        child: Row(
          children: [
            Text(flag, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 15),
            Text(
              title,
              style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: const Color(0xFF1A1A1A)
              ),
            ),
            const Spacer(),
            if (isSelected)
              const Icon(Icons.check_circle, color: Color(0xFFD4AF37)), // Check dorado
          ],
        ),
      ),
    );
  }
}
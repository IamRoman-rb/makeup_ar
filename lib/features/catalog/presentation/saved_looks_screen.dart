import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ar_makeup_app/app_services.dart';
import 'package:ar_makeup_app/features/auth/domain/app_user.dart';
import 'package:ar_makeup_app/features/catalog/domain/catalog_look.dart';
import 'package:ar_makeup_app/features/catalog/presentation/step_by_step_screen.dart';
import 'package:ar_makeup_app/l10n/app_localizations.dart'; // <-- 1. Importación del traductor
import 'package:ar_makeup_app/features/catalog/presentation/catalog_labels.dart';

class SavedLooksScreen extends StatefulWidget {
  const SavedLooksScreen({super.key});

  @override
  State<SavedLooksScreen> createState() => _SavedLooksScreenState();
}

class _SavedLooksScreenState extends State<SavedLooksScreen> {
  // Una vez: creados en build, quitar un favorito volvía a pedir todo el
  // catálogo y mostraba el spinner.
  final AppUser? _user = AppServices.auth.currentUser;
  late final Stream<Set<String>> _savedStream = AppServices.savedLooks.watchSavedIds(_user?.id ?? '');
  late final Stream<List<CatalogLook>> _looksStream = AppServices.catalog.watchLooks();

  Widget _buildSafeImage(String imageUrl) {
    // Si la URL está vacía, mostramos un fondo elegante con un ícono
    if (imageUrl.trim().isEmpty) {
      return Container(
        height: 350,
        width: double.infinity,
        color: const Color(0xFFF5F5F5),
        child: const Center(
          child: Icon(Icons.auto_awesome, color: Color(0xFFD4AF37), size: 40),
        ),
      );
    }

    // Si es una imagen de la web
    if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
      return Image.network(
        imageUrl,
        height: 350,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildSafeImage(''), // Si falla, muestra el fondo
      );
    }

    // Si es un archivo local (assets)
    return Image.asset(
      imageUrl,
      height: 350,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => _buildSafeImage(''),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    final l10n = AppLocalizations.of(context)!; // <-- 2. Instancia del traductor

    if (user == null) return Scaffold(body: Center(child: Text(l10n.loginFirst)));

    return Scaffold(
      backgroundColor: const Color(0xFFFDF7F8),
      appBar: AppBar(
        title: Text(l10n.mySavedLooks, style: GoogleFonts.playfairDisplay(color: const Color(0xFF1A1A1A), fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1A1A1A)),
        centerTitle: true,
      ),
      body: StreamBuilder<Set<String>>(
        stream: _savedStream,
        builder: (context, savedSnapshot) {
          if (savedSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37)));
          }

          final savedLooks = savedSnapshot.data ?? const <String>{};

          if (savedLooks.isEmpty) {
            return Center(
              child: Text(
                l10n.noSavedLooks, // <-- Mensaje de vacío traducido
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(color: Colors.grey, fontSize: 14, height: 1.5),
              ),
            );
          }

          return StreamBuilder<List<CatalogLook>>(
            stream: _looksStream,
            builder: (context, looksSnapshot) {
              if (looksSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37)));
              }
              final allLooks = looksSnapshot.data;
              if (looksSnapshot.hasError || allLooks == null) {
                return Center(child: Text(l10n.catalogLoadError('${looksSnapshot.error ?? ''}')));
              }

              // Solo los guardados (y que sigan en el catálogo).
              final filteredLooks = allLooks.where((look) => savedLooks.contains(look.id)).toList();

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                itemCount: filteredLooks.length,
                itemBuilder: (context, index) {
                  final look = filteredLooks[index];
                  final name = look.name.isEmpty ? l10n.unknownLook : look.name; // <-- Traducido
                  final category = look.category; // (Esto viene de DB, se mantiene intacto)
                  final image = look.image ?? '';

                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => StepByStepScreen(lookId: look.id)),
                      );
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 30),
                      child: Column(
                        children: [
                          Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(15),
                                child: _buildSafeImage(image),
                              ),
                              Positioned(
                                top: 15,
                                right: 15,
                                child: GestureDetector(
                                  onTap: () => AppServices.savedLooks.toggle(userId: user.id, lookId: look.id),
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.9), shape: BoxShape.circle),
                                    child: const Icon(Icons.favorite, color: Color(0xFFE91E63), size: 20),
                                  ),
                                ),
                              )
                            ],
                          ),
                          const SizedBox(height: 15),
                          Text(name, style: GoogleFonts.playfairDisplay(fontSize: 24, fontWeight: FontWeight.bold, color: const Color(0xFF1A1A1A))),
                          const SizedBox(height: 5),
                          Text(lookCategoryLabel(l10n, category), style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFFD4AF37), letterSpacing: 1.2)),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
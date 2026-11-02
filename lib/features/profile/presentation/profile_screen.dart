import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ar_makeup_app/app_services.dart';
import 'package:ar_makeup_app/features/auth/domain/app_user.dart';
import 'package:ar_makeup_app/shared/widgets/shared_bottom_nav.dart';
import 'package:ar_makeup_app/features/profile/presentation/edit_profile_screen.dart';
import 'package:ar_makeup_app/features/auth/presentation/login_screen.dart';
import 'package:ar_makeup_app/features/catalog/presentation/saved_looks_screen.dart';
import 'package:ar_makeup_app/features/profile/presentation/account_settings_screen.dart';
import 'package:ar_makeup_app/features/profile/presentation/language_screen.dart';
import 'package:ar_makeup_app/features/ar/presentation/camera_screen.dart';
import 'package:ar_makeup_app/features/ar/presentation/test_filter_view.dart';
import 'package:ar_makeup_app/features/coach/presentation/coach_screen.dart';
import 'package:ar_makeup_app/features/my_looks/presentation/my_looks_screen.dart';
import 'package:ar_makeup_app/features/legal/presentation/privacy_center_screen.dart';
import 'package:ar_makeup_app/l10n/app_localizations.dart'; // <-- 1. Importación del traductor
import 'package:ar_makeup_app/features/profile/presentation/profile_labels.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Una vez: creados en build, cada redibujo se volvía a suscribir.
  late final Stream<AppUser?> _userStream = AppServices.auth.watchCurrentUser();
  final String? _userId = AppServices.auth.currentUser?.id;
  late final Stream<Set<String>> _savedStream = AppServices.savedLooks.watchSavedIds(_userId ?? '');

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!; // <-- 2. Instancia del traductor

    if (_userId == null) return Scaffold(body: Center(child: Text(l10n.loginFirst)));

    return Scaffold(
      backgroundColor: const Color(0xFFFDF7F8),
      body: SafeArea(
        child: StreamBuilder<AppUser?>(
            stream: _userStream,
            initialData: AppServices.auth.currentUser,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text(l10n.profileLoadError('${snapshot.error}')));
              }

              final user = snapshot.data;
              if (user == null) {
                return Center(child: Text(l10n.profileNoData));
              }

              final profile = user.profile;
              final nombre = profile.name.isEmpty ? 'Beauty Lover' : profile.name;
              final tipoPiel = profile.skinType;
              final tonoPiel = profile.skinTone;
              final photoPath = profile.photoPath;
              final hasPhoto = photoPath != null && photoPath.isNotEmpty;

              final rawPrefs = profile.preferences;
              String descripcion = rawPrefs.isNotEmpty
                  ? l10n.profilePreferences(rawPrefs.map((p) => preferenceLabel(l10n, p)).join(' | '))
                  : l10n.profileDefaultBio;

              return SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: 40),

                    Center(
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundColor: Colors.grey.shade300,
                            // Sin foto, un ícono local (antes una foto de Unsplash en cada apertura).
                            // Decodificada al tamaño del círculo, no a la de la foto.
                            backgroundImage: hasPhoto ? ResizeImage(FileImage(File(photoPath)), width: 300) : null,
                            child: hasPhoto ? null : Icon(Icons.person, size: 56, color: Colors.grey.shade600),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Semantics(
                              button: true,
                              label: l10n.editProfile,
                              child: GestureDetector(
                                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const EditProfileScreen())),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFD4AF37),
                                    shape: BoxShape.circle,
                                    boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
                                  ),
                                  child: const Icon(Icons.edit, color: Colors.white, size: 16),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(nombre, style: GoogleFonts.playfairDisplay(fontSize: 28, fontWeight: FontWeight.bold, color: const Color(0xFF1A1A1A))),
                    const SizedBox(height: 5),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Text(descripcion, textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 14, color: Colors.grey.shade600, height: 1.5)),
                    ),
                    const SizedBox(height: 25),

                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(color: const Color(0xFFF5EFE6), borderRadius: BorderRadius.circular(25)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Column(
                            children: [
                              Text(l10n.skinTypeLabel, style: GoogleFonts.inter(fontSize: 10, color: Colors.grey)), // <-- Traducido
                              Text(skinTypeLabel(l10n, tipoPiel), style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFFD4AF37))),
                            ],
                          ),
                          const SizedBox(width: 20),
                          Container(height: 20, width: 1, color: Colors.grey.shade300),
                          const SizedBox(width: 20),
                          Column(
                            children: [
                              Text(l10n.toneLabel, style: GoogleFonts.inter(fontSize: 10, color: Colors.grey)), // <-- Traducido
                              Text(skinToneLabel(l10n, tonoPiel), style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFFD4AF37))),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          StreamBuilder<Set<String>>(
                            stream: _savedStream,
                            builder: (context, saved) => _buildStatCard('${saved.data?.length ?? 0}', l10n.savedLooks),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 35),

                    // Botón "View All >"
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(l10n.mySavedLooks, style: GoogleFonts.playfairDisplay(fontSize: 22, fontWeight: FontWeight.bold, color: const Color(0xFF1A1A1A))), // <-- Traducido
                          GestureDetector(
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SavedLooksScreen())),
                            child: Text(l10n.viewAll, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFFD4AF37), fontWeight: FontWeight.w600)), // <-- Traducido
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 15),

                    // Imágenes decorativas (preview visual)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          // Locales: sin pedirle fotos a un servicio externo en cada apertura.
                          Expanded(child: _decorativeTile(const [Color(0xFFE8B4B8), Color(0xFFB3122D)], Icons.brush_outlined)),
                          const SizedBox(width: 15),
                          Expanded(child: _decorativeTile(const [Color(0xFFF5EFE6), Color(0xFFD4AF37)], Icons.auto_awesome)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Looks del usuario ("Mis looks"), guardados en la base local.
                    Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.auto_awesome, color: Color(0xFFD4AF37)),
                          label: Text(l10n.myAiLooksTitle, style: GoogleFonts.inter(color: const Color(0xFF1A1A1A), fontWeight: FontWeight.w600)),
                          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                          onPressed: () => Navigator.push(context, MaterialPageRoute(
                            builder: (_) => MyLooksScreen(
                              repository: AppServices.aiLooks(user.id),
                              generator: AppServices.recipeGenerator,
                              onTryOn: (recipe) {
                                final look = TestFilterOption(id: 'ai-${recipe.name.hashCode}', label: recipe.name, recipe: recipe);
                                Navigator.push(context, MaterialPageRoute(
                                  builder: (camera) => CameraScreen(
                                    initialLook: look,
                                    // La guía reemplaza a la cámara; al salir vuelve a "Mis looks".
                                    onOpenCoach: () => Navigator.of(camera).pushReplacement(
                                      MaterialPageRoute<void>(builder: (_) => CoachScreen(look: look)),
                                    ),
                                  ),
                                ));
                              },
                            ),
                          )),
                        ),
                      ),
                    const SizedBox(height: 35),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(l10n.settings, style: GoogleFonts.playfairDisplay(fontSize: 22, fontWeight: FontWeight.bold, color: const Color(0xFF1A1A1A))), // <-- Traducido
                      ),
                    ),
                    const SizedBox(height: 10),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        children: [
                          _buildListTile(
                            Icons.person_outline,
                            l10n.accountSettings,
                            () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AccountSettingsScreen())),
                          ),
                          _buildListTile(
                            Icons.privacy_tip_outlined,
                            l10n.privacyCenterTitle,
                            () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PrivacyCenterScreen())),
                          ),
                          _buildListTile(
                            Icons.language,
                            l10n.appLanguage,
                            () => Navigator.push(context, MaterialPageRoute(builder: (context) => const LanguageScreen())),
                          ),

                          GestureDetector(
                            onTap: () async {
                              await AppServices.auth.signOut();
                              if (context.mounted) {
                                Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const LoginScreen()), (route) => false);
                              }
                            },
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                              decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(15)),
                              child: Row(
                                children: [
                                  Icon(Icons.logout, color: Colors.red.shade400, size: 22),
                                  const SizedBox(width: 15),
                                  Text(l10n.logOut, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.red.shade400)), // <-- Traducido
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              );
            }
        ),
      ),
      bottomNavigationBar: const SharedBottomNav(currentIndex: 1),
    );
  }

  Widget _buildStatCard(String number, String label) {
    return Container(
      width: 100,
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Column(
        children: [
          Text(number, style: GoogleFonts.playfairDisplay(fontSize: 24, fontWeight: FontWeight.bold, color: const Color(0xFF1A1A1A))),
          const SizedBox(height: 5),
          Text(label, textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade600)),
        ],
      ),
    );
  }

  /// Fila de ajustes: botón real (foco, lector de pantalla, área táctil).
  Widget _buildListTile(IconData icon, String title, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            child: Row(
              children: [
                Icon(icon, color: Colors.grey.shade700, size: 22),
                const SizedBox(width: 15),
                Expanded(
                  child: Text(title, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: const Color(0xFF1A1A1A))),
                ),
                const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Las imágenes decorativas son links externos a Unsplash: si el link
  // vence o cambia (ya pasó), esto evita que la app tire una excepción sin
  // manejar en vez de simplemente mostrar el espacio vacío.
  Widget _decorativeTile(List<Color> colors, IconData icon) {
    return Container(
      height: 180,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors),
      ),
      child: Icon(icon, size: 44, color: Colors.white.withValues(alpha: 0.9)),
    );
  }
}
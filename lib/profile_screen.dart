import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'shared_bottom_nav.dart';
import 'edit_profile_screen.dart';
import 'login_screen.dart';
import 'saved_looks_screen.dart';
import 'account_settings_screen.dart';
import 'language_screen.dart';
import 'l10n/app_localizations.dart'; // <-- 1. Importación del traductor

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final l10n = AppLocalizations.of(context)!; // <-- 2. Instancia del traductor

    if (user == null) return Scaffold(body: Center(child: Text(l10n.loginFirst)));

    return Scaffold(
      backgroundColor: const Color(0xFFFDF7F8),
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37)));
              }

              if (snapshot.hasError) {
                return Center(child: Text('Error cargando el perfil: ${snapshot.error}'));
              }

              if (!snapshot.hasData || !snapshot.data!.exists) {
                return const Center(child: Text('Error loading user data'));
              }

              final data = snapshot.data!.data() as Map<String, dynamic>;
              final nombre = data['nombre'] ?? 'Beauty Lover';
              final tipoPiel = data['tipo_piel'] ?? '-';
              final tonoPiel = data['tono_piel'] ?? '-';

              // Lógica de favoritos
              final savedLooks = List<String>.from(data['saved_looks'] ?? []);
              final savedCount = savedLooks.length.toString();

              List<dynamic> rawPrefs = data['gustos_personales'] ?? [];
              String descripcion = rawPrefs.isNotEmpty
                  ? 'Preferences: ${rawPrefs.join(' | ')}'
                  : 'Exploring elegant, minimalist aesthetics.';

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
                            backgroundImage: (data['foto_perfil'] != null && data['foto_perfil'].toString().isNotEmpty)
                                ? NetworkImage(data['foto_perfil']) as ImageProvider
                                : const NetworkImage('https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?q=80&w=800&auto=format&fit=crop'),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
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
                              Text(tipoPiel, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFFD4AF37))),
                            ],
                          ),
                          const SizedBox(width: 20),
                          Container(height: 20, width: 1, color: Colors.grey.shade300),
                          const SizedBox(width: 20),
                          Column(
                            children: [
                              Text(l10n.toneLabel, style: GoogleFonts.inter(fontSize: 10, color: Colors.grey)), // <-- Traducido
                              Text(tonoPiel, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFFD4AF37))),
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
                          _buildStatCard(savedCount, l10n.savedLooks), // <-- Traducido
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
                          Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(15), child: Image.network('https://images.unsplash.com/photo-1580481072645-022f9a6d4df8?q=80&w=400&auto=format&fit=crop', height: 180, fit: BoxFit.cover, errorBuilder: _decorativeImageFallback))),
                          const SizedBox(width: 15),
                          Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(15), child: Image.network('https://images.unsplash.com/photo-1531746020798-e6953c6e8e04?q=80&w=400&auto=format&fit=crop', height: 180, fit: BoxFit.cover, errorBuilder: _decorativeImageFallback))),
                        ],
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
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const AccountSettingsScreen()),
                              );
                            },
                            child: _buildListTile(Icons.person_outline, l10n.accountSettings), // <-- Traducido
                          ),

                          // Convertí el botón de idioma en una lista para que el diseño sea perfecto
                          GestureDetector(
                            onTap: () {
                              Navigator.push(context, MaterialPageRoute(builder: (context) => const LanguageScreen()));
                            },
                            child: _buildListTile(Icons.language, l10n.appLanguage), // <-- Traducido
                          ),

                          GestureDetector(
                            onTap: () async {
                              await FirebaseAuth.instance.signOut();
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
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 5))],
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

  Widget _buildListTile(IconData icon, String title) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey.shade700, size: 22),
          const SizedBox(width: 15),
          Text(title, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: const Color(0xFF1A1A1A))),
          const Spacer(),
          const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
        ],
      ),
    );
  }

  // Las imágenes decorativas son links externos a Unsplash: si el link
  // vence o cambia (ya pasó), esto evita que la app tire una excepción sin
  // manejar en vez de simplemente mostrar el espacio vacío.
  Widget _decorativeImageFallback(BuildContext context, Object error, StackTrace? stackTrace) {
    return Container(
      height: 180,
      color: Colors.grey.shade200,
      child: Icon(Icons.image_not_supported_outlined, color: Colors.grey.shade400),
    );
  }
}
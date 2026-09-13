import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'camera_screen.dart';
import 'l10n/app_localizations.dart'; // <-- 1. Importación del traductor

class SavedLooksScreen extends StatelessWidget {
  const SavedLooksScreen({super.key});

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

    // Si es una imagen de la web (Firebase Storage)
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
    final user = FirebaseAuth.instance.currentUser;
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
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
        builder: (context, userSnapshot) {
          if (userSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37)));
          }

          final userData = userSnapshot.data?.data() as Map<String, dynamic>? ?? {};
          final savedLooks = List<String>.from(userData['saved_looks'] ?? []);

          if (savedLooks.isEmpty) {
            return Center(
              child: Text(
                l10n.noSavedLooks, // <-- Mensaje de vacío traducido
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(color: Colors.grey, fontSize: 14, height: 1.5),
              ),
            );
          }

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('looks').snapshots(),
            builder: (context, looksSnapshot) {
              if (looksSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37)));
              }

              final allLooks = looksSnapshot.data!.docs;
              // Filtramos localmente para solo mostrar los que están en nuestro arreglo de guardados
              final filteredLooks = allLooks.where((doc) => savedLooks.contains(doc.id)).toList();

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                itemCount: filteredLooks.length,
                itemBuilder: (context, index) {
                  final doc = filteredLooks[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final name = data['name'] ?? l10n.unknownLook; // <-- Traducido
                  final category = data['category'] ?? 'COMPLEXION & LIPS'; // (Esto viene de DB, se mantiene intacto)
                  final image = data['image'] ?? '';
                  final path = data['path'] ?? '';

                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => CameraScreen(filterPath: path, lookId: doc.id)),
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
                                  onTap: () async {
                                    await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
                                      'saved_looks': FieldValue.arrayRemove([doc.id])
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), shape: BoxShape.circle),
                                    child: const Icon(Icons.favorite, color: Color(0xFFE91E63), size: 20),
                                  ),
                                ),
                              )
                            ],
                          ),
                          const SizedBox(height: 15),
                          Text(name, style: GoogleFonts.playfairDisplay(fontSize: 24, fontWeight: FontWeight.bold, color: const Color(0xFF1A1A1A))),
                          const SizedBox(height: 5),
                          Text(category, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFFD4AF37), letterSpacing: 1.2)),
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
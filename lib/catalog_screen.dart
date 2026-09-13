import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'camera_screen.dart';
import 'filter_editor_screen.dart';
import 'shared_bottom_nav.dart';
import 'l10n/app_localizations.dart'; // <-- 1. Importamos el traductor

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key});

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  // Claves internas para buscar en Firebase (Nunca se traducen)
  final List<String> internalCategories = ['All', 'Lips', 'Eyes', 'Complexion'];
  int selectedCategoryIndex = 0;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final String defaultImage = 'https://images.unsplash.com/photo-1515377905703-c4788e51af15?q=80&w=800&auto=format&fit=crop';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() { _searchQuery = _searchController.text.toLowerCase(); });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final l10n = AppLocalizations.of(context)!; // <-- 2. Instanciamos el traductor

    if (user == null) return const Scaffold(body: Center(child: Text('Inicia sesión')));

    // 3. Categorías visuales (Traducidas según el idioma seleccionado)
    final List<String> displayCategories = [
      l10n.categoryAll,
      l10n.categoryLips,
      l10n.categoryEyes,
      l10n.categoryComplexion,
    ];

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
      builder: (context, userSnapshot) {
        final userData = userSnapshot.data?.data() as Map<String, dynamic>? ?? {};
        final savedLooks = List<String>.from(userData['saved_looks'] ?? []);
        final isAdmin = userData['is_admin'] == true;

        return Scaffold(
      backgroundColor: const Color(0xFFFDF7F8),
      floatingActionButton: isAdmin
          ? FloatingActionButton(
              backgroundColor: const Color(0xFF1A1A1A),
              tooltip: 'Crear filtro (admin)',
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FilterEditorScreen())),
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 20),
                // Título traducido
                Text(l10n.discoverLooks, style: GoogleFonts.playfairDisplay(fontSize: 32, fontWeight: FontWeight.bold, color: const Color(0xFF1A1A1A))),
                const SizedBox(height: 20),

                // BARRA DE BÚSQUEDA
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))],
                  ),
                  child: TextField(
                    controller: _searchController,
                    style: GoogleFonts.inter(color: const Color(0xFF1A1A1A)),
                    decoration: InputDecoration(
                      icon: const Icon(Icons.search, color: Colors.grey),
                      hintText: l10n.searchHint, // Placeholder traducido
                      hintStyle: GoogleFonts.inter(color: Colors.grey, fontSize: 14),
                      border: InputBorder.none,
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(icon: const Icon(Icons.clear, color: Colors.grey, size: 18), onPressed: () => _searchController.clear())
                          : null,
                    ),
                  ),
                ),
                const SizedBox(height: 25),

                // BOTONES DE CATEGORÍAS (Usan displayCategories)
                SizedBox(
                  height: 40,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: displayCategories.length,
                    itemBuilder: (context, index) {
                      final isSelected = selectedCategoryIndex == index;
                      return GestureDetector(
                        onTap: () => setState(() => selectedCategoryIndex = index),
                        child: Container(
                          margin: const EdgeInsets.only(right: 10),
                          padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFF1A1A1A) : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: isSelected ? const Color(0xFF1A1A1A) : Colors.grey.shade300),
                          ),
                          child: Text(
                            displayCategories[index], // Muestra el texto en el idioma actual
                            style: GoogleFonts.inter(
                              color: isSelected ? Colors.white : const Color(0xFF1A1A1A),
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 30),

                // LISTA DE FILTROS
                StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance.collection('looks').orderBy('order').snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37)));

                          if (snapshot.hasError) {
                            return Padding(padding: const EdgeInsets.all(40.0), child: Text('Error cargando los looks: ${snapshot.error}'));
                          }

                          // Caso de base de datos vacía general
                          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                            return Padding(padding: const EdgeInsets.all(40.0), child: Text(l10n.noLooksFound(l10n.categoryAll)));
                          }

                          final allLooks = snapshot.data!.docs;

                          // LÓGICA DE DOBLE FILTRADO
                          final filteredLooks = allLooks.where((doc) {
                            final data = doc.data() as Map<String, dynamic>;

                            // 1. Validar barra de búsqueda
                            final name = (data['name'] ?? '').toString().toLowerCase();
                            final matchesSearch = name.contains(_searchQuery);

                            // 2. Validar categoría de Firebase (Usa la categoría interna en inglés)
                            final dbCategory = (data['category'] ?? '').toString().toLowerCase();
                            final internalSelectedCategory = internalCategories[selectedCategoryIndex].toLowerCase();

                            final matchesCategory = selectedCategoryIndex == 0 || dbCategory.contains(internalSelectedCategory);

                            return matchesSearch && matchesCategory;
                          }).toList();

                          // Mensajes de vacío dinámicos (Usan métodos de traducción con variables)
                          if (filteredLooks.isEmpty) {
                            return Padding(
                                padding: const EdgeInsets.all(40.0),
                                child: Text(
                                  _searchQuery.isNotEmpty
                                      ? l10n.noResultsFor(_searchQuery, displayCategories[selectedCategoryIndex])
                                      : l10n.noLooksFound(displayCategories[selectedCategoryIndex]),
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(color: Colors.grey),
                                )
                            );
                          }

                          return ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: filteredLooks.length,
                            itemBuilder: (context, index) {
                              final doc = filteredLooks[index];
                              final data = doc.data() as Map<String, dynamic>;
                              final name = data['name'] ?? 'Unknown Look';
                              final category = data['category'] ?? 'COMPLEXION & LIPS';
                              final image = data['image'] ?? defaultImage;
                              final path = data['path'] ?? '';

                              final isSaved = savedLooks.contains(doc.id);

                              return GestureDetector(
                                onTap: () {
                                  Navigator.push(context, MaterialPageRoute(
                                    builder: (context) => CameraScreen(filterPath: path, lookId: doc.id),
                                  ));
                                },
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 30),
                                  child: Column(
                                    children: [
                                      Stack(
                                        children: [
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(15),
                                            child: Image.network(image, height: 350, width: double.infinity, fit: BoxFit.cover),
                                          ),
                                          Positioned(
                                            top: 15,
                                            right: 15,
                                            child: GestureDetector(
                                              onTap: () async {
                                                final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
                                                if (isSaved) {
                                                  await userRef.update({'saved_looks': FieldValue.arrayRemove([doc.id])});
                                                } else {
                                                  await userRef.update({'saved_looks': FieldValue.arrayUnion([doc.id])});
                                                }
                                              },
                                              child: Container(
                                                padding: const EdgeInsets.all(8),
                                                decoration: BoxDecoration(
                                                  color: Colors.white.withOpacity(0.9),
                                                  shape: BoxShape.circle,
                                                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                                                ),
                                                child: Icon(
                                                  isSaved ? Icons.favorite : Icons.favorite_border,
                                                  color: isSaved ? const Color(0xFFE91E63) : Colors.grey,
                                                  size: 20,
                                                ),
                                              ),
                                            ),
                                          ),
                                          if (isAdmin)
                                            Positioned(
                                              top: 15,
                                              left: 15,
                                              child: GestureDetector(
                                                onTap: () => Navigator.push(context, MaterialPageRoute(
                                                  builder: (_) => FilterEditorScreen(lookId: doc.id),
                                                )),
                                                child: Container(
                                                  padding: const EdgeInsets.all(8),
                                                  decoration: BoxDecoration(
                                                    color: Colors.white.withOpacity(0.9),
                                                    shape: BoxShape.circle,
                                                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                                                  ),
                                                  child: const Icon(Icons.edit_outlined, color: Color(0xFF1A1A1A), size: 20),
                                                ),
                                              ),
                                            ),
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
                      ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: const SharedBottomNav(currentIndex: 0),
    );
      },
    );
  }
}
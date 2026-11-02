import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ar_makeup_app/app_services.dart';
import 'package:ar_makeup_app/features/auth/domain/app_user.dart';
import 'package:ar_makeup_app/features/ar/domain/makeup_recipe.dart';
import 'package:ar_makeup_app/features/ar/presentation/camera_screen.dart';
import 'package:ar_makeup_app/features/catalog/domain/catalog_look.dart';
import 'package:ar_makeup_app/features/coach/presentation/coach_screen.dart';
import 'package:ar_makeup_app/features/ar/presentation/test_filter_view.dart';
import 'package:ar_makeup_app/features/studio/data/engine_image_analyzer.dart';
import 'package:ar_makeup_app/features/studio/presentation/studio_screen.dart';
import 'package:ar_makeup_app/features/catalog/presentation/filter_editor_screen.dart';
import 'package:ar_makeup_app/features/catalog/presentation/step_by_step_screen.dart';
import 'package:ar_makeup_app/shared/widgets/shared_bottom_nav.dart';
import 'package:ar_makeup_app/l10n/app_localizations.dart'; // <-- 1. Importamos el traductor
import 'package:ar_makeup_app/features/catalog/presentation/catalog_labels.dart';
import 'package:ar_makeup_app/features/catalog/presentation/look_cover.dart';

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key});

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  // Claves internas de categoría guardadas en la base (Nunca se traducen)
  final List<String> internalCategories = ['All', 'Lips', 'Eyes', 'Complexion'];
  int selectedCategoryIndex = 0;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Una vez: creados en build, cada tecla de la búsqueda o cada categoría se
  // resuscribía y la lista pasaba por el spinner.
  final AppUser? _user = AppServices.auth.currentUser;
  late final Stream<AppUser?> _userStream = AppServices.auth.watchCurrentUser();
  late final Stream<Set<String>> _savedStream = AppServices.savedLooks.watchSavedIds(_user?.id ?? '');
  // Ya ordenado por el repositorio (catalog_order).
  late final Stream<List<CatalogLook>> _looksStream = AppServices.catalog.watchLooks();

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

  /// Tocar un look: con receta, el espejo con ese look puesto y el botón
  /// "Ver tutorial"; sin receta (looks viejos), el tutorial directo.
  void _openLook(BuildContext context, String lookId, MakeupRecipe? recipe) {
    final navigator = Navigator.of(context);
    if (recipe == null) {
      navigator.push(MaterialPageRoute<void>(builder: (_) => StepByStepScreen(lookId: lookId)));
      return;
    }
    final look = TestFilterOption(id: 'look-$lookId', label: recipe.name, recipe: recipe);
    navigator.push(MaterialPageRoute<void>(
      builder: (camera) => CameraScreen(
        initialLook: look,
        // Reemplaza la cámara: se cierra antes de que arranque el video del
        // tutorial (cámara, motor y video juntos no entran en el E20).
        onOpenTutorial: () => Navigator.of(camera).pushReplacement(
          MaterialPageRoute<void>(builder: (_) => StepByStepScreen(lookId: lookId)),
        ),
        // La guía abre su propia sesión de cámara: reemplaza a esta.
        onOpenCoach: () => Navigator.of(camera).pushReplacement(
          MaterialPageRoute<void>(builder: (_) => CoachScreen(look: look)),
        ),
      ),
    ));
  }

  /// Admin: crear un look con IA (Studio) o editar los pasos de un tutorial.
  Future<void> _openAdminMenu(BuildContext context, String uid) async {
    final l10n = AppLocalizations.of(context)!;
    final navigator = Navigator.of(context);
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.auto_awesome),
              title: Text(l10n.studioMenuStudio),
              onTap: () => Navigator.pop(sheet, 'studio'),
            ),
            ListTile(
              leading: const Icon(Icons.list_alt),
              title: Text(l10n.studioMenuSteps),
              onTap: () => Navigator.pop(sheet, 'steps'),
            ),
          ],
        ),
      ),
    );
    if (choice == 'studio') {
      await navigator.push(MaterialPageRoute<void>(
        builder: (_) => StudioScreen(
          generator: AppServices.recipeGenerator,
          repository: AppServices.studioLooks(uid),
          imageAnalyzer: EngineImageAnalyzer(),
        ),
      ));
    } else if (choice == 'steps') {
      await navigator.push(MaterialPageRoute<void>(builder: (_) => const FilterEditorScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    final l10n = AppLocalizations.of(context)!; // <-- 2. Instanciamos el traductor

    if (user == null) return Scaffold(body: Center(child: Text(l10n.loginFirst)));

    // 3. Categorías visuales (Traducidas según el idioma seleccionado)
    final List<String> displayCategories = [
      l10n.categoryAll,
      l10n.categoryLips,
      l10n.categoryEyes,
      l10n.categoryComplexion,
    ];

    return StreamBuilder<AppUser?>(
      stream: _userStream,
      initialData: user,
      builder: (context, userSnapshot) {
        final isAdmin = userSnapshot.data?.isAdmin ?? false;

        return StreamBuilder<Set<String>>(
          stream: _savedStream,
          builder: (context, savedSnapshot) {
        final savedLooks = savedSnapshot.data ?? const <String>{};

        return Scaffold(
      backgroundColor: const Color(0xFFFDF7F8),
      floatingActionButton: isAdmin
          ? FloatingActionButton(
              backgroundColor: const Color(0xFF1A1A1A),
              tooltip: l10n.catalogCreateLookTooltip,
              onPressed: () => _openAdminMenu(context, user.id),
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
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 5))],
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
                StreamBuilder<List<CatalogLook>>(
                        stream: _looksStream,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37)));

                          if (snapshot.hasError) {
                            return Padding(padding: const EdgeInsets.all(40.0), child: Text(l10n.catalogLoadError('${snapshot.error}')));
                          }

                          // Caso de base de datos vacía general
                          final allLooks = snapshot.data ?? const <CatalogLook>[];
                          if (allLooks.isEmpty) {
                            return Padding(padding: const EdgeInsets.all(40.0), child: Text(l10n.noLooksFound(l10n.categoryAll)));
                          }

                          // LÓGICA DE DOBLE FILTRADO
                          final filteredLooks = allLooks.where((look) {
                            // 1. Validar barra de búsqueda
                            final name = look.name.toLowerCase();
                            final matchesSearch = name.contains(_searchQuery);

                            // 2. Validar categoría (Usa la categoría interna en inglés)
                            final dbCategory = look.category.toLowerCase();
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
                              final look = filteredLooks[index];
                              final name = look.name.isEmpty ? l10n.unknownLook : look.name;
                              final category = look.category;
                              final image = look.image;

                              final isSaved = savedLooks.contains(look.id);
                              // Looks del Studio: receta válida para este motor.
                              final recipe = look.recipe;

                              return GestureDetector(
                                onTap: () => _openLook(context, look.id, recipe),
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 30),
                                  child: Column(
                                    children: [
                                      Stack(
                                        children: [
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(15),
                                            child: LookCover(imageUrl: image, recipe: recipe),
                                          ),
                                          Positioned(
                                            top: 15,
                                            right: 15,
                                            child: GestureDetector(
                                              onTap: () => AppServices.savedLooks.toggle(userId: user.id, lookId: look.id),
                                              child: Container(
                                                padding: const EdgeInsets.all(8),
                                                decoration: BoxDecoration(
                                                  color: Colors.white.withValues(alpha: 0.9),
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
                                                  builder: (_) => FilterEditorScreen(lookId: look.id),
                                                )),
                                                child: Container(
                                                  padding: const EdgeInsets.all(8),
                                                  decoration: BoxDecoration(
                                                    color: Colors.white.withValues(alpha: 0.9),
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
                                      Text(lookCategoryLabel(l10n, category), style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFFD4AF37), letterSpacing: 1.2)),
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
      },
    );
  }
}
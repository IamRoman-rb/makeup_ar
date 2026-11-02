/// Catálogo de looks y tutoriales, y looks guardados por usuario. Dominio
/// puro: sin Flutter ni base de datos.
library;

import '../../ar/domain/makeup_recipe.dart';

/// Un paso del tutorial.
final class TutorialStep {
  const TutorialStep({this.title = '', this.image = '', this.description = ''});

  final String title;

  /// URL de la imagen del paso; vacía sin imagen.
  final String image;
  final String description;

  bool get isEmpty => title.trim().isEmpty && image.trim().isEmpty && description.trim().isEmpty;

  Map<String, String> toJson() => {'title': title, 'image': image, 'description': description};

  /// null si no es un mapa.
  static TutorialStep? fromJson(Object? raw) {
    if (raw is! Map) return null;
    String text(Object? value) => value is String ? value : '';
    return TutorialStep(title: text(raw['title']), image: text(raw['image']), description: text(raw['description']));
  }
}

final class CatalogLook {
  const CatalogLook({
    required this.id,
    required this.name,
    required this.category,
    required this.sortKey,
    this.image,
    this.steps = const [],
    this.recipe,
  });

  final String id;
  final String name;

  /// LookCategory.wireName ('Lips', 'Eyes', 'Complexion'); texto libre en
  /// looks viejos.
  final String category;

  /// catalogSortKey: menor primero.
  final int sortKey;

  /// URL de la portada; null usa la portada generada desde la receta.
  final String? image;
  final List<TutorialStep> steps;

  /// Receta para "Probar en AR"; null en looks solo de tutorial o si la
  /// receta no valida o es de un motor más nuevo.
  final MakeupRecipe? recipe;
}

/// Lo que guarda el editor de tutoriales (admin). La receta del look, si
/// tiene, no se toca.
final class TutorialEdit {
  const TutorialEdit({
    required this.name,
    required this.category,
    this.image,
    this.videoUrl,
    this.steps = const [],
  });

  final String name;
  final String category;
  final String? image;

  /// Video del tutorial (contenido VIP); null o vacío lo quita.
  final String? videoUrl;
  final List<TutorialStep> steps;
}

abstract interface class ICatalogRepository {
  /// Looks del catálogo, ya ordenados (catalog_order.dart).
  Stream<List<CatalogLook>> watchLooks();

  /// Un look; null si no existe o se borró.
  Stream<CatalogLook?> watchLook(String id);

  Future<CatalogLook?> look(String id);

  /// Crea ([id] null) o actualiza un tutorial. Devuelve el id.
  Future<String> saveTutorial(TutorialEdit edit, {String? id, required String userId});

  Future<void> deleteLook(String id);

  /// Video del tutorial (contenido VIP); null si no tiene. Quien llama
  /// decide si el usuario lo puede ver (AppUser.canSeePremiumAt).
  Future<String?> videoUrl(String id);
}

abstract interface class ISavedLooksRepository {
  /// Ids de los looks que guardó [userId].
  Stream<Set<String>> watchSavedIds(String userId);

  /// Guarda el look si no estaba guardado; si estaba, lo quita.
  Future<void> toggle({required String userId, required String lookId});
}

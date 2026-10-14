/// Looks del Studio (F3): borradores y publicados, sin Flutter ni Firebase.
///
/// Firestore (docs/ar_engine/motor_ar_propio.md §10.12):
///   look_drafts/{id}  borradores, solo admins (firestore.rules)
///   looks/{id}        catálogo, lectura pública; los nuevos traen `recipe`,
///                     `recipeSchema`, `minEngine` y `source`
library;

import '../../ar/domain/makeup_recipe.dart';
import '../../ar/domain/recipe_validator.dart';

/// Categoría del catálogo (valor guardado en `looks.category`).
enum LookCategory {
  lips('Lips'),
  eyes('Eyes'),
  complexion('Complexion');

  const LookCategory(this.wireName);

  final String wireName;

  static LookCategory? fromWire(Object? raw) {
    for (final value in values) {
      if (value.wireName == raw) return value;
    }
    return null;
  }

  /// Categoría por defecto según las regiones de la receta: labios, si no
  /// ojos, si no piel/rubor.
  static LookCategory of(MakeupRecipe recipe) {
    if (recipe.lips != null) return lips;
    if (recipe.eyes != null) return eyes;
    return complexion;
  }
}

/// De dónde salió la receta.
enum LookSourceType {
  prompt('prompt'),
  remix('remix'),
  // Foto de referencia analizada en el teléfono (F4): sin prompt ni modelo.
  image('image'),
  manual('manual');

  const LookSourceType(this.wireName);

  final String wireName;

  static LookSourceType fromWire(Object? raw) =>
      values.firstWhere((value) => value.wireName == raw, orElse: () => manual);
}

final class StudioLook {
  const StudioLook({
    this.id,
    required this.recipe,
    required this.category,
    this.sourceType = LookSourceType.manual,
    this.sourcePrompt,
    this.model,
    this.image,
  });

  /// null = todavía no se guardó.
  final String? id;
  final MakeupRecipe recipe;
  final LookCategory category;
  final LookSourceType sourceType;

  /// Pedido original (solo el texto del admin; nunca datos de usuarios).
  final String? sourcePrompt;
  final String? model;

  /// URL de la imagen del catálogo (opcional: sin ella, la por defecto).
  final String? image;

  String get name => recipe.name;

  StudioLook copyWith({String? id, MakeupRecipe? recipe, LookCategory? category, String? image}) => StudioLook(
        id: id ?? this.id,
        recipe: recipe ?? this.recipe,
        category: category ?? this.category,
        sourceType: sourceType,
        sourcePrompt: sourcePrompt,
        model: model,
        image: image ?? this.image,
      );

  /// Campos comunes de borrador y look publicado.
  Map<String, Object?> toFirestore() => {
        'name': recipe.name,
        'category': category.wireName,
        'recipe': recipe.toJson(),
        'recipeSchema': kMakeupRecipeSchemaV2,
        'minEngine': kMakeupEngineVersion,
        'source': {
          'type': sourceType.wireName,
          if (sourcePrompt != null) 'prompt': sourcePrompt,
          if (model != null) 'model': model,
        },
        if (image != null && image?.isNotEmpty == true) 'image': image,
      };

  /// Un borrador guardado; null si su receta no valida.
  static StudioLook? fromFirestore(String id, Map<String, Object?> data) {
    final recipe = lookRecipe(data);
    if (recipe == null) return null;
    final source = data['source'];
    final sourceMap = source is Map ? source : const {};
    final prompt = sourceMap['prompt'];
    final model = sourceMap['model'];
    final image = data['image'];
    return StudioLook(
      id: id,
      recipe: recipe,
      category: LookCategory.fromWire(data['category']) ?? LookCategory.of(recipe),
      sourceType: LookSourceType.fromWire(sourceMap['type']),
      sourcePrompt: prompt is String ? prompt : null,
      model: model is String ? model : null,
      image: image is String ? image : null,
    );
  }
}

/// Receta de un documento de `looks` o `look_drafts`, solo si valida y el
/// motor instalado la puede dibujar (`minEngine` <= [kMakeupEngineVersion]).
/// Los looks viejos (sin `recipe`) devuelven null: no tienen "Probar en AR".
MakeupRecipe? lookRecipe(Map<String, Object?> data) {
  final raw = data['recipe'];
  if (raw == null) return null;
  final minEngine = data['minEngine'];
  if (minEngine is num && minEngine > kMakeupEngineVersion) return null;
  return const RecipeValidator().validate(raw).recipe;
}

abstract interface class ILookRepository {
  /// Crea o actualiza el borrador ([look.id] null = nuevo). Devuelve su id.
  Future<String> saveDraft(StudioLook look);

  /// Borradores, el más reciente primero.
  Future<List<StudioLook>> drafts();

  Future<void> deleteDraft(String id);

  /// Publica en el catálogo (un look nuevo) y borra el borrador si había.
  /// Devuelve el id del look publicado.
  Future<String> publish(StudioLook look);
}

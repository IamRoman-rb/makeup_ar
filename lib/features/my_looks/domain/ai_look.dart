/// Looks generados con IA por usuarios finales ("Mis looks", §10.13 del
/// informe): prompt -> 3 variantes -> probar -> guardar. Dominio puro.
///
/// Se guardan en `users/{uid}/ai_looks`: el cliente solo los lee
/// (firestore.rules); guardar y borrar pasan por las callables `saveAiLook` y
/// `deleteAiLook` (functions/src/aiLooks.ts), que validan la receta y ponen
/// el tope.
library;

import '../../ar/domain/makeup_recipe.dart';
import '../../ar/domain/recipe_validator.dart';

/// Límites que impone el servidor (functions/src/generateRecipe.ts y
/// aiLooks.ts); acá solo se muestran.
abstract final class AiLookLimits {
  /// Generaciones por día de un usuario final (USER_DAILY_QUOTA).
  static const int dailyGenerations = 5;

  /// Looks guardados por usuario (MAX_AI_LOOKS).
  static const int maxSaved = 30;

  /// Largo máximo del pedido (MAX_PROMPT_LENGTH).
  static const int maxPromptLength = 300;
}

final class AiLook {
  const AiLook({required this.id, required this.recipe, this.createdAt});

  final String id;
  final MakeupRecipe recipe;
  final DateTime? createdAt;

  /// null si la receta no valida (rota o de un esquema más nuevo): se omite.
  static AiLook? fromMap(String id, Map<String, Object?> data, {DateTime? createdAt}) {
    final recipe = const RecipeValidator().validate(data['recipe']).recipe;
    if (recipe == null) return null;
    return AiLook(id: id, recipe: recipe, createdAt: createdAt);
  }
}

/// Por qué no se pudo guardar o borrar.
enum AiLookFailure {
  unauthenticated,

  /// Ya hay [AiLookLimits.maxSaved] looks guardados.
  full,

  /// El servidor rechazó la receta.
  invalid,

  /// El look ya no existe.
  notFound,

  /// App Check rechazó la app.
  appCheck,

  /// Sin red o el servidor no respondió.
  unavailable,
  unknown;

  /// Códigos de HttpsError de functions/src/aiLooks.ts.
  static AiLookFailure fromCode(String code) => switch (code) {
        'unauthenticated' => unauthenticated,
        'resource-exhausted' => full,
        'invalid-argument' => invalid,
        'not-found' => notFound,
        'failed-precondition' => appCheck,
        'unavailable' || 'deadline-exceeded' => unavailable,
        _ => unknown,
      };
}

/// De dónde vino la receta que se guarda (source.type en el servidor).
enum AiLookSource {
  prompt('prompt'),
  remix('remix');

  const AiLookSource(this.wireName);
  final String wireName;
}

abstract interface class IAiLookRepository {
  /// Los looks del usuario, del más nuevo al más viejo.
  Stream<List<AiLook>> watch();

  /// null si se guardó.
  Future<AiLookFailure?> save(MakeupRecipe recipe, {AiLookSource source = AiLookSource.prompt});

  /// null si se borró.
  Future<AiLookFailure?> delete(String id);
}

/// Colores de muestra de una receta (labios, rubor, primera sombra, iris), sin repetir.
List<RecipeColor> swatchesOf(MakeupRecipe recipe) {
  final colors = <RecipeColor>[
    ?recipe.lips?.color,
    ?recipe.cheeks?.color,
    ?recipe.eyes?.shadow?.firstOrNull?.color,
    ?recipe.eyes?.liner?.color,
    ?recipe.eyes?.iris?.color,
    ?recipe.skin?.foundation?.color,
  ];
  final seen = <int>{};
  return [for (final c in colors) if (seen.add(c.toHex().hashCode)) c];
}

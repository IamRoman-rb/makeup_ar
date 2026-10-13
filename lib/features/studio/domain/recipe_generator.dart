/// Generación de recetas con IA (F2): contrato del dominio, sin Flutter ni
/// Firebase. La implementación llama a la Cloud Function `generateRecipe`
/// (functions/src/generateRecipe.ts) y vuelve a validar cada variante.
library;

import '../../ar/domain/makeup_recipe.dart';

/// Por qué no hubo variantes de la IA.
enum GenerationFailure {
  /// Sin sesión iniciada.
  unauthenticated,

  /// El usuario no es admin.
  notAdmin,

  /// Texto vacío, demasiado largo o receta base inválida.
  invalidInput,

  /// Se agotó la cuota diaria.
  quotaExhausted,

  /// El modelo o la red no respondieron.
  unavailable,

  /// App Check rechazó la app (token de debug sin registrar, por ejemplo).
  appCheck,

  /// El modelo respondió, pero ninguna variante validó.
  noValidVariants,

  /// Cualquier otro error.
  unknown,
}

final class GenerationResult {
  GenerationResult({
    required List<MakeupRecipe> variants,
    this.failure,
    this.fallback,
    this.discarded = 0,
    this.model,
    this.requestId,
  }) : variants = List.unmodifiable(variants);

  /// Variantes de la IA ya validadas en la app (0 a 3).
  final List<MakeupRecipe> variants;

  /// Motivo, si no hubo variantes.
  final GenerationFailure? failure;

  /// Preset local más cercano al pedido, cuando no hubo variantes de la IA
  /// (y el pedido era un prompt).
  final MakeupRecipe? fallback;

  /// Variantes que mandó el servidor y la app descartó por no validar.
  final int discarded;
  final String? model;
  final String? requestId;

  bool get hasVariants => variants.isNotEmpty;
}

abstract interface class IRecipeGenerator {
  /// Tres variantes (fiel, más intensa, más sutil) para [prompt] (1..300
  /// caracteres) en [locale] (es, en, pt o fr).
  Future<GenerationResult> generate({required String prompt, required String locale});

  /// La receta [base] con la [instruction] aplicada ("más natural", "sin
  /// sombra"...), en tres intensidades.
  Future<GenerationResult> remix({required MakeupRecipe base, required String instruction, required String locale});
}

import '../../ar/domain/makeup_recipe.dart';
import '../../my_looks/domain/ai_look.dart';
import '../domain/prompt_fallback.dart';
import '../domain/recipe_generator.dart';

/// [IRecipeGenerator] sin IA, mientras no haya servidor: un pedido devuelve el
/// respaldo local ([PromptFallback]: el preset más parecido con los colores
/// que pide el texto) y la falla [GenerationFailure.localOnly], para que la
/// pantalla avise que la IA no está conectada. Sin red ni keys.
final class LocalRecipeGenerator implements IRecipeGenerator {
  const LocalRecipeGenerator();

  @override
  Future<GenerationResult> generate({required String prompt, required String locale}) async {
    final text = prompt.trim();
    if (text.isEmpty || text.length > AiLookLimits.maxPromptLength) {
      return GenerationResult(variants: const [], failure: GenerationFailure.invalidInput);
    }
    return GenerationResult(
      variants: const [],
      failure: GenerationFailure.localOnly,
      fallback: PromptFallback.recipeFor(text),
    );
  }

  /// Sin IA no hay remix: la receta base sigue en pantalla y se edita a mano.
  @override
  Future<GenerationResult> remix({required MakeupRecipe base, required String instruction, required String locale}) async =>
      GenerationResult(variants: const [], failure: GenerationFailure.localOnly);
}

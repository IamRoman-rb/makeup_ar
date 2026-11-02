import 'package:ar_makeup_app/features/ar/domain/recipe_presets.dart';
import 'package:ar_makeup_app/features/my_looks/domain/ai_look.dart';
import 'package:ar_makeup_app/features/studio/data/local_recipe_generator.dart';
import 'package:ar_makeup_app/features/studio/domain/prompt_fallback.dart';
import 'package:ar_makeup_app/features/studio/domain/recipe_generator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const generator = LocalRecipeGenerator();

  test('un pedido da el respaldo local y avisa que no hay IA', () async {
    final result = await generator.generate(prompt: 'labios azules', locale: 'es');
    expect(result.hasVariants, isFalse);
    expect(result.failure, GenerationFailure.localOnly);
    expect(result.fallback?.toJson(), PromptFallback.recipeFor('labios azules').toJson());
  });

  test('pedido vacío o demasiado largo: entrada inválida, sin respaldo', () async {
    for (final prompt in ['   ', 'a' * (AiLookLimits.maxPromptLength + 1)]) {
      final result = await generator.generate(prompt: prompt, locale: 'es');
      expect(result.failure, GenerationFailure.invalidInput);
      expect(result.fallback, isNull);
    }
  });

  test('remix sin IA: avisa y no cambia la receta', () async {
    final result = await generator.remix(
      base: RecipePresets.byId('natural').recipe,
      instruction: 'más intenso',
      locale: 'es',
    );
    expect(result.failure, GenerationFailure.localOnly);
    expect(result.hasVariants, isFalse);
    expect(result.fallback, isNull);
  });
}

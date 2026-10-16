import 'package:ar_makeup_app/features/ar/domain/makeup_recipe.dart';
import 'package:ar_makeup_app/features/ar/domain/recipe_presets.dart';
import 'package:ar_makeup_app/features/ar/domain/recipe_validator.dart';
import 'package:ar_makeup_app/features/studio/domain/prompt_fallback.dart';
import 'package:flutter_test/flutter_test.dart';

const blue = RecipeColor(0x1F4FB0);
const red = RecipeColor(0xB3122D);
const gold = RecipeColor(0xC9A13B);
const coral = RecipeColor(0xE8705A);
const green = RecipeColor(0x2E7D4F);
const purple = RecipeColor(0x6B2E8C);

void main() {
  test('labios azules: labios azules con el texto como nombre', () {
    final recipe = PromptFallback.recipeFor('labios azules');
    expect(recipe.lips?.color, blue);
    expect(recipe.lips?.opacity, greaterThanOrEqualTo(PromptFallback.minLipsOpacity));
    expect(recipe.name, 'Labios azules');
  });

  test('cada color va a la zona más cercana, en cualquier orden', () {
    for (final prompt in ['sombra dorada y labios rojos', 'labios rojos con sombra dorada']) {
      final recipe = PromptFallback.recipeFor(prompt);
      expect(recipe.lips?.color, red, reason: prompt);
      expect(recipe.eyes?.shadow?.first.color, gold, reason: prompt);
      expect(recipe.eyes?.shadow?.first.opacity, greaterThanOrEqualTo(PromptFallback.minShadowOpacity));
    }
  });

  test('inglés, portugués y francés', () {
    final english = PromptFallback.recipeFor('blue lips with gold eyeshadow');
    expect(english.lips?.color, blue);
    expect(english.eyes?.shadow?.first.color, gold);
    expect(PromptFallback.recipeFor('batom roxo').lips?.color, purple);
    expect(PromptFallback.recipeFor('lèvres violettes').lips?.color, purple);
  });

  test('mejillas, iris y dos sombras', () {
    final cheeks = PromptFallback.recipeFor('rubor coral');
    expect(cheeks.cheeks?.color, coral);
    expect(cheeks.cheeks?.opacity, greaterThanOrEqualTo(PromptFallback.minCheeksOpacity));
    expect(PromptFallback.recipeFor('lentes de contacto verdes').eyes?.iris?.color, green);
    final two = PromptFallback.recipeFor('sombra violeta y dorada');
    expect(two.eyes?.shadow?.map((s) => s.color).take(2), [purple, gold]);
  });

  test('"ojos azules" es sombra, no iris; "lentejuelas" no son lentes', () {
    final eyes = PromptFallback.recipeFor('ojos azules');
    expect(eyes.eyes?.shadow?.first.color, blue);
    expect(eyes.eyes?.iris, isNull);
    expect(PromptFallback.recipeFor('labios rojos con lentejuelas').eyes?.iris, isNull);
  });

  test('acabado de labios', () {
    final recipe = PromptFallback.recipeFor('labios rojos mate');
    expect(recipe.lips?.color, red);
    expect(recipe.lips?.finish, LipFinish.matte);
  });

  test('sin colores ni acabados: el preset más cercano tal cual', () {
    for (final prompt in ['look gótico', 'un look redondo', 'qwerty', '']) {
      final preset = RecipePresets.closestTo(prompt).recipe;
      final recipe = PromptFallback.recipeFor(prompt);
      expect(recipe.name, preset.name, reason: prompt);
      expect(recipe.toJson(), preset.toJson(), reason: prompt);
    }
  });

  test('el nombre no pasa de 60 caracteres', () {
    final recipe = PromptFallback.recipeFor('labios azules ${'muy ' * 70}'.trim());
    expect(recipe.name.length, lessThanOrEqualTo(60));
    expect(recipe.lips?.color, blue);
  });

  test('todo lo que genera valida con el validador estricto', () {
    const prompts = [
      'labios azules', 'sombra dorada y labios rojos', 'blue lips with gold eyeshadow', 'rubor coral',
      'lentes de contacto verdes', 'ojos azules', 'labios rojos mate', 'delineado plateado',
      'batom vermelho brilhante', 'ombre à paupières verte et lèvres roses', 'look gótico con labios negros',
      'pink glossy lips and purple shadow', 'mejillas rosadas, labios nude y sombra marrón',
      'glam dorado con glitter', 'sombra celeste, turquesa, azul y violeta', 'iris violeta',
      'labios bordó #unavailable', 'black eyeliner and red lips', 'olhos dourados', 'rubor terracota',
    ];
    for (final prompt in prompts) {
      final json = PromptFallback.recipeFor(prompt).toJson();
      final result = const RecipeValidator().validate(json);
      expect(result.recipe, isNotNull, reason: '$prompt: ${result.errors}');
    }
  });
}

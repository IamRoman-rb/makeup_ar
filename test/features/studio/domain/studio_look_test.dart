import 'package:ar_makeup_app/features/ar/domain/makeup_recipe.dart';
import 'package:ar_makeup_app/features/ar/domain/recipe_presets.dart';
import 'package:ar_makeup_app/features/studio/domain/studio_look.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final red = RecipePresets.byId('classic_red').recipe;

  test('ida y vuelta por Firestore', () {
    final look = StudioLook(
      recipe: red,
      category: LookCategory.lips,
      sourceType: LookSourceType.prompt,
      sourcePrompt: 'labios rojos',
      model: 'gemini-3.5-flash',
      image: 'https://example.com/a.jpg',
    );
    final data = look.toFirestore();
    expect(data['recipeSchema'], kMakeupRecipeSchemaV2);
    expect(data['minEngine'], kMakeupEngineVersion);
    expect(data['category'], 'Lips');
    final back = StudioLook.fromFirestore('d1', data);
    expect(back?.id, 'd1');
    expect(back?.name, red.name);
    expect(back?.sourceType, LookSourceType.prompt);
    expect(back?.sourcePrompt, 'labios rojos');
    expect(back?.model, 'gemini-3.5-flash');
    expect(back?.image, 'https://example.com/a.jpg');
    expect(StudioLook(recipe: red, category: LookCategory.lips).toFirestore().containsKey('image'), isFalse);
  });

  test('lookRecipe: solo recetas válidas para este motor', () {
    expect(lookRecipe({'name': 'Viejo'}), isNull);  // look sin receta
    expect(lookRecipe({'recipe': red.toJson()})?.name, red.name);
    expect(lookRecipe({'recipe': red.toJson(), 'minEngine': kMakeupEngineVersion})?.name, red.name);
    expect(lookRecipe({'recipe': red.toJson(), 'minEngine': kMakeupEngineVersion + 1}), isNull);
    expect(lookRecipe({'recipe': {...red.toJson(), 'shader': 'x'}}), isNull);
    expect(StudioLook.fromFirestore('x', {'recipe': 'roto'}), isNull);
  });

  test('categoría por defecto según las regiones', () {
    expect(LookCategory.of(red), LookCategory.lips);
    expect(LookCategory.of(MakeupRecipe(name: 'Piel')), LookCategory.complexion);
    expect(LookCategory.fromWire('Eyes'), LookCategory.eyes);
    expect(LookCategory.fromWire('otra'), isNull);
  });
}

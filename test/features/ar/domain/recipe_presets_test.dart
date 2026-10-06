import 'package:ar_makeup_app/features/ar/domain/recipe_presets.dart';
import 'package:ar_makeup_app/features/ar/domain/recipe_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('hay 5 presets con ids y nombres únicos', () {
    expect(RecipePresets.all, hasLength(5));
    expect(RecipePresets.all.map((p) => p.id).toSet(), hasLength(5));
    expect(RecipePresets.all.map((p) => p.recipe.name).toSet(), hasLength(5));
  });

  test('cada preset valida contra el esquema y sobrevive ida y vuelta', () {
    for (final preset in RecipePresets.all) {
      final json = preset.recipe.toJson();
      final result = const RecipeValidator().validate(json);
      expect(result.isValid, isTrue, reason: '${preset.id}: ${result.errors.join('; ')}');
      expect(result.recipe?.toJson(), json);
    }
  });

  test('existe el preset de respaldo', () {
    expect(RecipePresets.byId(RecipePresets.fallbackId).id, RecipePresets.fallbackId);
    expect(RecipePresets.byId('no-existe').id, RecipePresets.fallbackId);
  });

  group('closestTo', () {
    final expectations = {
      'labios góticos y rubor naranja': 'gothic',
      'Gothic dark lips': 'gothic',
      'un rojo clásico para la noche': 'classic_red',
      'batom vermelho': 'classic_red',
      'algo natural para el día': 'natural',
      'maquillage léger et naturel': 'natural',
      'glam dorado con glitter para fiesta': 'golden_glam',
      'rosa fresco y glossy': 'fresh_pink',
      'ROSADO PRIMAVERA': 'fresh_pink',
    };
    expectations.forEach((prompt, expectedId) {
      test('"$prompt" → $expectedId', () {
        expect(RecipePresets.closestTo(prompt).id, expectedId);
      });
    });

    test('sin coincidencias devuelve el respaldo', () {
      expect(RecipePresets.closestTo('qwerty asdf').id, RecipePresets.fallbackId);
      expect(RecipePresets.closestTo('').id, RecipePresets.fallbackId);
    });

    test('no confunde subcadenas dentro de otras palabras', () {
      // "red" no debe coincidir dentro de "bored", ni "rose" dentro de "prose".
      expect(RecipePresets.closestTo('bored prose').id, RecipePresets.fallbackId);
    });
  });
}

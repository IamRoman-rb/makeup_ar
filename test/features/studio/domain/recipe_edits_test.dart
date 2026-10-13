import 'package:ar_makeup_app/features/ar/domain/makeup_recipe.dart';
import 'package:ar_makeup_app/features/ar/domain/recipe_presets.dart';
import 'package:ar_makeup_app/features/ar/domain/recipe_validator.dart';
import 'package:ar_makeup_app/features/studio/domain/recipe_edits.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final red = RecipePresets.byId('classic_red').recipe;
  final valid = const RecipeValidator();

  test('lista las capas presentes con su valor', () {
    final layers = RecipeEdits.layersOf(red);
    expect(layers, contains(RecipeLayer.lips));
    expect(layers, contains(RecipeLayer.eyeLiner));
    final lips = RecipeEdits.valueOf(red, RecipeLayer.lips);
    expect(lips?.color?.toHex(), '#B3122D');
    expect(lips?.amount, red.lips?.opacity);
    expect(RecipeEdits.valueOf(red, RecipeLayer.lipLiner), isNull);
  });

  test('cambia color y cantidad y la receta sigue validando', () {
    final color = RecipeColor.tryParse('#6E0A1A');
    expect(color, isNotNull);
    if (color == null) return;
    var edited = RecipeEdits.withColor(red, RecipeLayer.lips, color);
    edited = RecipeEdits.withAmount(edited, RecipeLayer.lips, 0.4);
    expect(edited.lips?.color.toHex(), '#6E0A1A');
    expect(edited.lips?.opacity, 0.4);
    expect(valid.validate(edited.toJson()).isValid, isTrue);
    // Fuera de rango se recorta.
    expect(RecipeEdits.withAmount(red, RecipeLayer.lips, 3).lips?.opacity, 1.0);
    // La base usa coverage.
    final natural = RecipePresets.byId('natural').recipe;
    if (RecipeEdits.valueOf(natural, RecipeLayer.foundation) != null) {
      expect(RecipeEdits.withAmount(natural, RecipeLayer.foundation, 0.2).skin?.foundation?.coverage, 0.2);
    }
  });

  test('las pestañas no tienen color', () {
    final lashes = RecipeEdits.layersOf(red).contains(RecipeLayer.lashes);
    if (!lashes) return;
    expect(RecipeEdits.valueOf(red, RecipeLayer.lashes)?.color, isNull);
    final color = RecipeColor.tryParse('#FF0000');
    if (color == null) return;
    expect(identical(RecipeEdits.withColor(red, RecipeLayer.lashes, color), red), isTrue);
  });

  test('quitar capas: la región vacía desaparece', () {
    final noLips = RecipeEdits.without(red, RecipeLayer.lips);
    expect(noLips.lips, isNull);
    expect(noLips.eyes, isNotNull);
    var noEyes = red;
    for (final layer in RecipeEdits.layersOf(red).where((l) => l.path.first == 'eyes').toList().reversed) {
      noEyes = RecipeEdits.without(noEyes, layer);
    }
    expect(noEyes.eyes, isNull);
    expect(valid.validate(noEyes.toJson()).isValid, isTrue);
  });

  test('acabado y nombre', () {
    final matte = RecipeEdits.withLipFinish(red, LipFinish.matte);
    expect(matte.lips?.finish, LipFinish.matte);
    expect(matte.lips?.gloss, 0.0);
    final gloss = RecipeEdits.withLipFinish(matte, LipFinish.gloss);
    expect(gloss.lips?.gloss, greaterThanOrEqualTo(0.5));
    expect(RecipeEdits.withName(red, '  Rojo noche  ').name, 'Rojo noche');
    expect(RecipeEdits.withName(red, '   ').name, red.name);
    expect(RecipeEdits.withName(red, 'x' * 80).name.length, RecipeLimits.nameMaxLength);
  });
}

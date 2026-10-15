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

  test('color de la paleta: cambia la capa o la agrega', () {
    final color = RecipeColor.tryParse('#7A3E8C');
    expect(color, isNotNull);
    if (color == null) return;
    // Existente: igual que withColor.
    expect(RecipeEdits.withColorOrAdd(red, RecipeLayer.lips, color).lips?.color, color);
    // Rubor nuevo con valores por defecto.
    final noCheeks = RecipeEdits.without(red, RecipeLayer.cheeks);
    final cheeks = RecipeEdits.withColorOrAdd(noCheeks, RecipeLayer.cheeks, color).cheeks;
    expect(cheeks?.color, color);
    expect(cheeks?.opacity, 0.35);
    // Sombra nueva: la siguiente libre, en una región sin usar.
    final next = RecipeEdits.nextShadow(red);
    expect(next, isNotNull);
    if (next == null) return;
    final withShadow = RecipeEdits.withColorOrAdd(red, next, color);
    final before = red.eyes?.shadow?.length ?? 0;
    expect(withShadow.eyes?.shadow, hasLength(before + 1));
    final regions = withShadow.eyes?.shadow?.map((s) => s.region).toSet();
    expect(regions, hasLength(before + 1));
    expect(valid.validate(withShadow.toJson()).isValid, isTrue);
    // Saltear una sombra o pintar pestañas no cambia nada.
    if (next != RecipeLayer.shadow3) {
      final skipped = RecipeLayer.values[next.index + 1];
      expect(identical(RecipeEdits.withColorOrAdd(red, skipped, color), red), isTrue);
    }
    expect(identical(RecipeEdits.withColorOrAdd(red, RecipeLayer.lashes, color), red), isTrue);
    // Delineado de labios sin labial: no se puede.
    final noLips = RecipeEdits.without(red, RecipeLayer.lips);
    expect(RecipeEdits.withColorOrAdd(noLips, RecipeLayer.lipLiner, color).lips, isNull);
    // Receta sin ojos: delineado nuevo.
    final liner = RecipeEdits.withColorOrAdd(MakeupRecipe(name: 'x'), RecipeLayer.eyeLiner, color);
    expect(liner.eyes?.liner?.color, color);
  });

  test('iris: se agrega, se edita y se quita', () {
    const blue = RecipeColor(0x3A7BD5);
    final base = MakeupRecipe(name: 'x');
    final withIris = RecipeEdits.withColorOrAdd(base, RecipeLayer.iris, blue);
    expect(withIris.eyes?.iris?.color, blue);
    expect(withIris.eyes?.iris?.opacity, 0.6);
    expect(RecipeEdits.layersOf(withIris), [RecipeLayer.iris]);
    final softer = RecipeEdits.withAmount(withIris, RecipeLayer.iris, 0.3);
    expect(softer.eyes?.iris?.opacity, 0.3);
    final removed = RecipeEdits.without(softer, RecipeLayer.iris);
    expect(removed.eyes, isNull);
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

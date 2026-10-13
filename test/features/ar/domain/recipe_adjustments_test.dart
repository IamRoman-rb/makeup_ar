import 'package:ar_makeup_app/features/ar/domain/makeup_recipe.dart';
import 'package:ar_makeup_app/features/ar/domain/recipe_adjustments.dart';
import 'package:ar_makeup_app/features/ar/domain/recipe_presets.dart';
import 'package:ar_makeup_app/features/ar/domain/recipe_validator.dart';
import 'package:flutter_test/flutter_test.dart';

MakeupRecipe preset(String id) => RecipePresets.all.firstWhere((p) => p.id == id).recipe;

void main() {
  test('sin cambios devuelve la misma receta', () {
    final glam = preset('golden_glam');
    expect(adjustRecipe(glam).toJson(), glam.toJson());
  });

  test('cada zona deja solo sus regiones', () {
    final glam = preset('golden_glam');
    final lips = adjustRecipe(glam, zone: MakeupZone.lips);
    expect(lips.lips, isNotNull);
    expect([lips.cheeks, lips.eyes, lips.skin], everyElement(isNull));
    final eyes = adjustRecipe(glam, zone: MakeupZone.eyes);
    expect(eyes.eyes?.shadow?.length, 3);
    expect([eyes.lips, eyes.cheeks, eyes.skin], everyElement(isNull));
    final cheeks = adjustRecipe(glam, zone: MakeupZone.cheeks);
    expect(cheeks.cheeks?.placement, CheekPlacement.high);
    expect([cheeks.lips, cheeks.eyes, cheeks.skin], everyElement(isNull));
    final skin = adjustRecipe(glam, zone: MakeupZone.skin);
    expect(skin.skin?.highlight, isNotNull);
    expect([skin.lips, skin.eyes, skin.cheeks], everyElement(isNull));
    expect(adjustRecipe(glam).effects, isNotNull);
    expect(skin.name, glam.name);
    // El glitter de Glam dorado es de los ojos: sale con "Ojos", no con "Labios".
    expect(eyes.effects?.single.type, EffectType.glitter);
    expect(lips.effects, isEmpty);
  });

  test('la intensidad escala todas las opacidades y se recorta a 1', () {
    final red = preset('classic_red');
    final half = adjustRecipe(red, intensity: 0.5);
    expect(half.lips?.opacity, closeTo(0.425, 1e-9));
    expect(half.cheeks?.opacity, closeTo(0.125, 1e-9));
    expect(half.eyes?.liner?.opacity, closeTo(0.45, 1e-9));
    expect(half.eyes?.lashes?.opacity, closeTo(0.4, 1e-9));
    // Lo que no es opacidad no cambia.
    expect(half.eyes?.liner?.wing, red.eyes?.liner?.wing);
    expect(half.lips?.lumaFollow, red.lips?.lumaFollow);
    final strong = adjustRecipe(red, intensity: 3);
    expect(strong.lips?.opacity, 1.0);  // 0,85 · 1,5 recortado
    expect(strong.cheeks?.opacity, closeTo(0.375, 1e-9));
    expect(adjustRecipe(red, intensity: -1).lips?.opacity, 0.0);

    final gothic = preset('gothic');
    expect(adjustRecipe(gothic, intensity: 0.5).skin?.contour?.opacity, closeTo(0.15, 1e-9));
  });

  test('zona de cada efecto según su región o su tipo', () {
    expect(effectZone(const MakeupEffect(type: EffectType.sheen, intensity: 0.2, region: EffectRegion.cheeksNose)),
        MakeupZone.cheeks);
    expect(effectZone(const MakeupEffect(type: EffectType.glitter, intensity: 0.2, region: EffectRegion.lips)),
        MakeupZone.lips);
    expect(effectZone(const MakeupEffect(type: EffectType.freckles, intensity: 0.2, region: EffectRegion.fullFace)),
        MakeupZone.skin);
    expect(effectZone(const MakeupEffect(type: EffectType.glitter, intensity: 0.2)), MakeupZone.eyes);
    expect(effectZone(const MakeupEffect(type: EffectType.freckles, intensity: 0.2)), MakeupZone.cheeks);
    final pink = preset('fresh_pink');
    expect(adjustRecipe(pink, zone: MakeupZone.cheeks).effects?.single.type, EffectType.sheen);
    expect(adjustRecipe(pink, zone: MakeupZone.eyes).effects, isEmpty);
  });

  test('cambia el acabado del labial', () {
    final red = preset('classic_red');
    expect(adjustRecipe(red, lipFinish: LipFinish.matte).lips?.finish, LipFinish.matte);
    expect(adjustRecipe(red).lips?.finish, red.lips?.finish);
  });

  test('el resultado sigue siendo una receta válida', () {
    for (final p in RecipePresets.all) {
      for (final zone in MakeupZone.values) {
        final json = adjustRecipe(p.recipe, zone: zone, intensity: 1.3, lipFinish: LipFinish.shimmer).toJson();
        expect(const RecipeValidator().validate(json).isValid, isTrue, reason: '${p.id} $zone');
      }
    }
  });
}

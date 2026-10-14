import 'package:ar_makeup_app/features/ar/domain/makeup_recipe.dart';
import 'package:ar_makeup_app/features/ar/domain/recipe_validator.dart';
import 'package:ar_makeup_app/features/studio/domain/image_look.dart';
import 'package:ar_makeup_app/features/studio/domain/image_recipe.dart';
import 'package:ar_makeup_app/features/studio/domain/oklab.dart';
import 'package:ar_makeup_app/features/studio/domain/recipe_edits.dart';
import 'package:flutter_test/flutter_test.dart';

/// Lo que el motor pinta sobre [base] con ([target], [w]): mismo modelo que
/// ImageRecipeBuilder.fitError (sirve para fabricar observaciones).
Oklab render(Oklab base, Oklab target, double w, {double lumaFollow = 1}) => Oklab(
  base.l + (target.l - base.l) * w * lumaFollow,
  base.a + (target.a - base.a) * w,
  base.b + (target.b - base.b) * w,
);

LookRegion region(Oklab color, {double gloss = 0, double coverage = 1}) =>
    LookRegion(valid: true, color: color, gloss: gloss, coverage: coverage);

void main() {
  // La piel y el labio del script de referencia (sample_region_reference.py).
  final skin = Oklab.fromSrgb(0.80, 0.62, 0.52);
  final red = Oklab.fromSrgb(0.90, 0.35, 0.40);
  const valid = RecipeValidator();

  test('OKLab: ida y vuelta y HEX', () {
    final color = RecipeColor.tryParse('#B3122D');
    expect(color, isNotNull);
    if (color == null) return;
    expect(Oklab.fromColor(color).toRecipeColor(), color);
    expect(const Oklab(0.5, 0.4, 0.4).inGamut, isFalse);
    expect(skin.inGamut, isTrue);
  });

  test('identificabilidad: con cualquier política el render es el mismo', () {
    // Como el script: color verdadero con opacidad 0,3; con las políticas
    // 0,35, 0,6 y 0,85 el par cambia pero el error de render es ~0.
    final observed = render(skin, red, 0.3);
    final opacities = <double>[];
    for (final policy in [0.35, 0.6, 0.85]) {
      final solved = ImageRecipeBuilder.solve(skin, observed, policy);
      expect(solved.fitError, lessThan(1e-6), reason: 'política $policy');
      expect(solved.color.inGamut, isTrue);
      opacities.add(solved.opacity);
    }
    expect(opacities.first, closeTo(0.35, 1e-9));
    expect(opacities.last, closeTo(0.85, 1e-9));
  });

  test('fuera de gamut sube la opacidad', () {
    // Muy saturado y con opacidad baja: el color despejado no entra con 0,35.
    final vivid = Oklab.fromSrgb(0.95, 0.05, 0.10);
    final observed = render(skin, vivid, 0.9);
    final solved = ImageRecipeBuilder.solve(skin, observed, 0.35);
    expect(solved.opacity, greaterThan(0.35));
    expect(solved.color.inGamut, isTrue);
    expect(solved.fitError, lessThan(ImageRecipePolicy.maxFitError));
  });

  test('look completo: labios, rubor, sombra y delineado con wing', () {
    final lip = Oklab.fromSrgb(0.70, 0.10, 0.20);
    final purple = Oklab.fromSrgb(0.55, 0.35, 0.60);
    final measurements = LookMeasurements(
      status: PhotoLookStatus.ok,
      skin: region(skin),
      lips: region(render(skin, lip, 0.85, lumaFollow: 0.8), gloss: 0.8),
      lipInterior: region(lip),
      lipLiner: region(lip),
      cheeks: region(render(skin, red, 0.5), coverage: 0.9),
      cheekPlacement: CheekPlacement.high,
      eyeRegions: [
        region(render(skin, purple, 0.75), gloss: 0.6), // párpado shimmer
        region(render(skin, purple, 0.75)), // pliegue: igual, se une
        region(skin), // V externa: nada
        region(skin),
        region(skin),
      ],
      liner: region(Oklab.fromSrgb(0.05, 0.05, 0.05)),
      linerExtent: 0.35,
      wingExtent: 0.6,
    );
    final result = ImageRecipeBuilder.build(measurements, name: 'Desde foto');
    final recipe = result.recipe;
    expect(recipe, isNotNull);
    if (recipe == null) return;
    expect(valid.validate(recipe.toJson()).isValid, isTrue);
    expect(recipe.name, 'Desde foto');

    expect(recipe.lips?.finish, LipFinish.gloss);
    expect(recipe.lips?.gloss, closeTo(0.8, 1e-9));
    expect(recipe.lips?.liner, isNull); // anillo igual al centro: sin delineado
    expect(recipe.cheeks?.placement, CheekPlacement.high);
    expect(recipe.cheeks?.opacity, closeTo(0.5, 1e-9));

    final shadows = recipe.eyes?.shadow ?? const [];
    expect(shadows, hasLength(1));
    expect(shadows.single.region, ShadowRegion.lid);
    expect(shadows.single.finish, ShadowFinish.shimmer);
    expect(recipe.eyes?.liner?.wing, closeTo(0.6, 1e-9));
    // 0,35 medido -> (0,35 - 0,04 - 0,12) / 0,48.
    expect(recipe.eyes?.liner?.thickness, closeTo(0.396, 1e-3));
    expect(recipe.eyes?.lashes, isNotNull);

    expect(result.regions.map((r) => r.layer), [
      RecipeLayer.lips,
      RecipeLayer.cheeks,
      RecipeLayer.shadow0,
      RecipeLayer.eyeLiner,
    ]);
    expect(result.worstFitError, lessThan(ImageRecipePolicy.maxFitError));
    // El color del labial reproduce lo observado sobre la piel de la foto.
    final lips = recipe.lips;
    if (lips == null) return;
    final rendered = render(skin, Oklab.fromColor(lips.color), lips.opacity, lumaFollow: 0.8);
    expect(rendered.distanceTo(measurements.lips.color), lessThan(0.01));
  });

  // P10: la foto de medio rostro del E20 (colores del log PHOTO). La piel
  // general (frente con brillo, #F5D2BE) es mucho más clara que la de la
  // mejilla y la ojera: con ella el párpado salía casi negro y el rubor
  // ladrillo. Con la piel local, no.
  test('foto de estudio: piel local, sombra y rubor no se oscurecen', () {
    Oklab hex(int rgb) => Oklab.fromColor(RecipeColor(rgb));
    final measurements = LookMeasurements(
      status: PhotoLookStatus.ok,
      skin: region(hex(0xF5D2BE)),
      cheekSkin: region(hex(0xE2B29A)),
      eyeSkin: region(hex(0xD6AA94)),
      lips: region(hex(0xB43F6F)),
      cheeks: region(hex(0xCA826A)),
      eyeRegions: [
        region(hex(0x67545A)),
        region(hex(0x645051)),
        region(hex(0x2A2431)),
        region(hex(0xCA9E84)),
        region(hex(0xA27153)),
      ],
      liner: region(hex(0x0C0B09)),
      linerExtent: 0.2,
      wingExtent: 0.2,
    );
    final recipe = ImageRecipeBuilder.build(measurements, name: 'Medio rostro').recipe;
    expect(recipe, isNotNull);
    if (recipe == null) return;
    final shadows = recipe.eyes?.shadow ?? const [];
    expect(shadows, isNotEmpty);
    // El párpado malva (unido al pliegue, casi del mismo color) sigue siendo
    // malva oscuro, no negro. La V externa sí es casi negra en la foto.
    final lid = shadows.firstWhere((s) => s.region == ShadowRegion.lid || s.region == ShadowRegion.crease);
    expect(Oklab.fromColor(lid.color).l, greaterThan(0.25));
    // El rubor durazno no se vuelve ladrillo.
    final cheeks = recipe.cheeks;
    expect(cheeks, isNotNull);
    if (cheeks != null) expect(Oklab.fromColor(cheeks.color).l, greaterThan(0.5));
    // Sin wing por las pestañas (0,2 < wingMin).
    expect(recipe.eyes?.liner?.wing ?? 0, 0);
  });

  test('sin maquillaje: solo los labios, sin ojos ni rubor', () {
    final measurements = LookMeasurements(
      status: PhotoLookStatus.ok,
      skin: region(skin),
      lips: region(Oklab.fromSrgb(0.75, 0.45, 0.45)),
      cheeks: region(skin),
      eyeRegions: [for (var i = 0; i < 5; i++) region(skin)],
      linerExtent: 0.1, // pestañas naturales: no alcanza
    );
    final recipe = ImageRecipeBuilder.build(measurements, name: 'Natural').recipe;
    expect(recipe?.lips, isNotNull);
    expect(recipe?.lips?.finish, LipFinish.matte);
    expect(recipe?.cheeks, isNull);
    expect(recipe?.eyes, isNull);
  });

  test('delineado de labios más oscuro que el centro', () {
    final lip = Oklab.fromSrgb(0.80, 0.35, 0.40);
    final ring = Oklab.fromSrgb(0.45, 0.12, 0.15);
    final measurements = LookMeasurements(
      status: PhotoLookStatus.ok,
      skin: region(skin),
      lips: region(lip),
      lipInterior: region(lip),
      lipLiner: region(ring),
    );
    final recipe = ImageRecipeBuilder.build(measurements, name: 'Con delineado').recipe;
    expect(recipe?.lips?.liner, isNotNull);
    expect(recipe?.lips?.liner?.opacity, greaterThanOrEqualTo(0.9));
  });

  test('cejas en el hueso de la ceja no son sombra; baja cobertura se descarta', () {
    final measurements = LookMeasurements(
      status: PhotoLookStatus.ok,
      skin: region(skin),
      lips: region(Oklab.fromSrgb(0.7, 0.3, 0.3), coverage: 0.2),
      eyeRegions: [
        region(skin),
        region(skin),
        region(skin),
        region(skin),
        region(Oklab.fromSrgb(0.3, 0.22, 0.18)), // oscuro: cejas
      ],
    );
    final result = ImageRecipeBuilder.build(measurements, name: 'x');
    expect(result.recipe, isNull);
    expect(result.status, PhotoLookStatus.badImage);
  });

  test('rechazos de la foto se propagan', () {
    final result = ImageRecipeBuilder.build(const LookMeasurements(status: PhotoLookStatus.profile), name: 'x');
    expect(result.recipe, isNull);
    expect(result.status, PhotoLookStatus.profile);
    expect(
      ImageRecipeBuilder.build(const LookMeasurements(status: PhotoLookStatus.ok), name: 'x').status,
      PhotoLookStatus.badImage,
    );
  });

  test('perfil marcado baja la confianza', () {
    final lips = region(Oklab.fromSrgb(0.7, 0.2, 0.3));
    final frontal = ImageRecipeBuilder.build(
      LookMeasurements(status: PhotoLookStatus.ok, skin: region(skin), lips: lips),
      name: 'x',
    );
    final turned = ImageRecipeBuilder.build(
      LookMeasurements(status: PhotoLookStatus.ok, skin: region(skin), lips: lips, yawRatio: 0.2),
      name: 'x',
    );
    expect(frontal.regions.single.confidence, closeTo(1, 1e-9));
    expect(turned.regions.single.confidence, lessThan(0.6));
  });

  test('variantes: fiel, intensa y sutil, todas válidas', () {
    final measurements = LookMeasurements(
      status: PhotoLookStatus.ok,
      skin: region(skin),
      lips: region(render(skin, red, 0.85, lumaFollow: 0.8)),
      cheeks: region(render(skin, red, 0.5)),
    );
    final faithful = ImageRecipeBuilder.build(measurements, name: 'Look').recipe;
    expect(faithful, isNotNull);
    if (faithful == null) return;
    final variants = ImageRecipeBuilder.variants(faithful, names: ['Fiel', 'Intensa', 'Sutil']);
    expect(variants.map((v) => v.name), ['Fiel', 'Intensa', 'Sutil']);
    for (final v in variants) {
      expect(valid.validate(v.toJson()).isValid, isTrue);
    }
    expect(variants[1].cheeks?.opacity, closeTo(0.5 * 1.25, 1e-3));
    expect(variants[2].cheeks?.opacity, closeTo(0.5 * 0.65, 1e-3));
    expect(variants[1].lips?.opacity, 1.0); // 0,85 × 1,25 se recorta
  });
}

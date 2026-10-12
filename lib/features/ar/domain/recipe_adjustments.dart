import 'makeup_recipe.dart';

/// Zona de la cara que se muestra de una receta (para comparar o capturar una
/// región sola).
enum MakeupZone { all, lips, eyes, cheeks, skin }

/// Intensidad máxima del control: 1 es la receta tal cual; más arriba se
/// refuerza (las opacidades se recortan a 1).
const double kMaxRecipeIntensity = 1.5;

/// La receta con solo las regiones de [zone], todas las opacidades (y el
/// coverage de la base) multiplicadas por [intensity] y, si se indica, otro
/// acabado de labial. Devuelve una receta nueva; la original no cambia.
MakeupRecipe adjustRecipe(
  MakeupRecipe recipe, {
  MakeupZone zone = MakeupZone.all,
  double intensity = 1.0,
  LipFinish? lipFinish,
}) {
  final k = intensity.clamp(0.0, kMaxRecipeIntensity).toDouble();
  double scale(double value) => (value * k).clamp(0.0, 1.0).toDouble();
  bool shows(MakeupZone region) => zone == MakeupZone.all || zone == region;

  final lips = recipe.lips;
  final cheeks = recipe.cheeks;
  final eyes = recipe.eyes;
  final skin = recipe.skin;
  final effects = recipe.effects;
  return MakeupRecipe(
    name: recipe.name,
    lips: lips == null || !shows(MakeupZone.lips)
        ? null
        : LipsSpec(
            color: lips.color,
            opacity: scale(lips.opacity),
            finish: lipFinish ?? lips.finish,
            gloss: lips.gloss,
            lumaFollow: lips.lumaFollow,
            liner: _scaleLayer(lips.liner, scale),
          ),
    cheeks: cheeks == null || !shows(MakeupZone.cheeks)
        ? null
        : CheeksSpec(
            color: cheeks.color,
            opacity: scale(cheeks.opacity),
            spread: cheeks.spread,
            placement: cheeks.placement,
          ),
    eyes: eyes == null || !shows(MakeupZone.eyes) ? null : _scaleEyes(eyes, scale),
    skin: skin == null || !shows(MakeupZone.skin)
        ? null
        : SkinSpec(
            foundation: _scaleFoundation(skin.foundation, scale),
            contour: _scaleLayer(skin.contour, scale),
            highlight: _scaleLayer(skin.highlight, scale),
          ),
    // Los efectos no son de una zona: solo con la cara completa.
    effects: effects == null || zone != MakeupZone.all
        ? null
        : [
            for (final effect in effects)
              MakeupEffect(type: effect.type, intensity: scale(effect.intensity), region: effect.region),
          ],
  );
}

ColorLayer? _scaleLayer(ColorLayer? layer, double Function(double) scale) =>
    layer == null ? null : ColorLayer(color: layer.color, opacity: scale(layer.opacity));

FoundationSpec? _scaleFoundation(FoundationSpec? foundation, double Function(double) scale) =>
    foundation == null ? null : FoundationSpec(color: foundation.color, coverage: scale(foundation.coverage));

EyesSpec _scaleEyes(EyesSpec eyes, double Function(double) scale) {
  final shadow = eyes.shadow;
  final liner = eyes.liner;
  final lashes = eyes.lashes;
  return EyesSpec(
    shadow: shadow == null
        ? null
        : [
            for (final layer in shadow)
              EyeShadowLayer(color: layer.color, opacity: scale(layer.opacity), region: layer.region, finish: layer.finish),
          ],
    liner: liner == null
        ? null
        : EyeLinerSpec(color: liner.color, opacity: scale(liner.opacity), thickness: liner.thickness, wing: liner.wing),
    lashes: lashes == null ? null : LashesSpec(opacity: scale(lashes.opacity), length: lashes.length, volume: lashes.volume),
  );
}

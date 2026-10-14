/// Foto de referencia -> receta (F4, informe §10.5 pasos 5 a 8;
/// docs/ar_engine/F4_PLAN.md). Dominio puro.
///
/// El motor pinta cada capa como `obs = base + w · (color · s − base)`, con
/// s ≈ 1 sobre la piel media y la L mezclada con `lumaFollow`. En la foto solo
/// se ve el resultado: color y opacidad no se pueden separar. Convención del
/// informe: la opacidad sale de una política por región y el color se despeja.
/// Si sale del gamut sRGB, se sube la opacidad hasta que entre.
///
/// Cada región trae su confianza (cobertura en la foto × pose) y su error de
/// ajuste: el ΔE OK entre lo que el motor pintaría con la receta sobre la piel
/// de la foto y lo observado. Ese error es el criterio de salida de F4 (< 0,02).
library;

import 'dart:math' as math;

import '../../ar/domain/makeup_recipe.dart';
import '../../ar/domain/recipe_validator.dart';
import 'image_look.dart';
import 'oklab.dart';
import 'recipe_edits.dart';

/// Políticas y umbrales iniciales (a calibrar con fotos reales en el E20).
abstract final class ImageRecipePolicy {
  // Opacidad por política (§10.5 paso 5).
  static const double lipsOpacity = 0.85;
  static const double lipLinerOpacity = 0.9;
  static const double cheeksOpacity = 0.35;
  static const double shadowOpacity = 0.5;
  static const double eyeLinerOpacity = 0.9;

  /// `lumaFollow` del labial (el default del motor, RecipeParams.kt).
  static const double lipsLumaFollow = 0.8;

  // Presencia de cada región respecto de la piel base.
  static const double shadowMinDelta = 0.045;
  static const double cheeksMinChroma = 0.02;
  static const double lipLinerMinDelta = 0.05;

  /// Dos sombras con colores más parecidos que esto se dejan en una.
  static const double shadowMergeDelta = 0.03;

  /// Delineado: grosor del motor (engine_config.h: kLinerThickness*,
  /// kLinerFeather) y margen sobre el mínimo para contarlo como delineado
  /// (las pestañas naturales ya oscurecen la línea).
  static const double linerThicknessMin = 0.12;
  static const double linerThicknessMax = 0.6;
  static const double linerFeather = 0.08;
  static const double linerMinMargin = 0.05;
  static const double wingMin = 0.15;

  // Acabado por gloss_score.
  static const double matteBelow = 0.15;
  static const double satinBelow = 0.5;

  /// Por debajo de esta confianza la región se descarta.
  static const double minConfidence = 0.4;

  /// Giro en que la confianza por pose llega a la mitad (kStillMaxYawRatio).
  static const double maxYawRatio = 0.22;

  /// Pestañas por defecto si hay ojos maquillados (no se miden en la foto).
  static const double lashOpacity = 0.8;

  // Variantes: más intensa y más sutil (opacidades × factor).
  static const double bolderFactor = 1.25;
  static const double subtlerFactor = 0.65;

  /// Error de ajuste máximo aceptado (criterio de §7 para F4).
  static const double maxFitError = 0.02;
}

/// Cómo quedó una región de la foto en la receta.
final class ImageRegionReport {
  const ImageRegionReport({required this.layer, required this.confidence, required this.fitError});

  final RecipeLayer layer;

  /// [0, 1]: cobertura de la región en la foto × pose.
  final double confidence;

  /// ΔE OK entre el render previsto sobre la piel de la foto y lo observado.
  final double fitError;
}

final class ImageRecipeResult {
  const ImageRecipeResult({this.recipe, this.regions = const [], this.status = PhotoLookStatus.ok});

  /// null si la foto no sirve ([status] dice por qué).
  final MakeupRecipe? recipe;
  final List<ImageRegionReport> regions;
  final PhotoLookStatus status;

  /// El peor error de ajuste (0 sin regiones).
  double get worstFitError => regions.fold(0.0, (worst, r) => math.max(worst, r.fitError));
}

/// Color y opacidad despejados, con el error de ajuste.
final class SolvedLayer {
  const SolvedLayer({required this.color, required this.opacity, required this.fitError});

  final Oklab color;
  final double opacity;
  final double fitError;
}

abstract final class ImageRecipeBuilder {
  static const RecipeValidator _validator = RecipeValidator(clampOutOfRange: true);

  /// Despeja el color de una capa con opacidad [policy] sobre [base] para que
  /// el motor reproduzca [observed]. Si el color sale del gamut, sube la
  /// opacidad (60 pasos hasta 1, como el script de referencia).
  static SolvedLayer solve(Oklab base, Oklab observed, double policy, {double lumaFollow = 1}) {
    const steps = 60;
    for (var i = 0; i < steps; i++) {
      final w = policy + (1 - policy) * i / (steps - 1);
      final target = Oklab(
        (base.l + (observed.l - base.l) / (w * lumaFollow)).clamp(0.0, 1.0),
        base.a + (observed.a - base.a) / w,
        base.b + (observed.b - base.b) / w,
      );
      if (target.inGamut) {
        return SolvedLayer(color: target, opacity: w, fitError: fitError(base, observed, target, w, lumaFollow));
      }
    }
    // Ni con opacidad 1 entra: el color observado, recortado al gamut.
    final clipped = Oklab.fromColor(observed.toRecipeColor());
    return SolvedLayer(color: clipped, opacity: 1, fitError: fitError(base, observed, clipped, 1, lumaFollow));
  }

  /// ΔE OK entre lo que el motor pinta sobre [base] con ([target], [w]) y [observed].
  static double fitError(Oklab base, Oklab observed, Oklab target, double w, double lumaFollow) {
    final rendered = Oklab(
      base.l + (target.l - base.l) * w * lumaFollow,
      base.a + (target.a - base.a) * w,
      base.b + (target.b - base.b) * w,
    );
    return rendered.distanceTo(observed);
  }

  /// Receta desde las medidas. [name]: nombre de la receta (1–60 caracteres).
  static ImageRecipeResult build(LookMeasurements m, {required String name}) {
    if (m.status != PhotoLookStatus.ok) return ImageRecipeResult(status: m.status);
    final skin = m.skin;
    if (!skin.valid) return const ImageRecipeResult(status: PhotoLookStatus.badImage);
    final base = skin.color;
    final pose = (1 - 0.5 * (m.yawRatio.abs() / ImageRecipePolicy.maxYawRatio)).clamp(0.0, 1.0);
    double confidence(LookRegion region) => (region.coverage * pose).clamp(0.0, 1.0);
    bool usable(LookRegion region) => region.valid && confidence(region) >= ImageRecipePolicy.minConfidence;

    final reports = <ImageRegionReport>[];
    final json = <String, Object?>{'schema': kMakeupRecipeSchemaV2, 'name': name};

    // Labios: siempre (el color del labio de la foto es parte del look).
    if (usable(m.lips)) {
      final solved = solve(
        base,
        m.lips.color,
        ImageRecipePolicy.lipsOpacity,
        lumaFollow: ImageRecipePolicy.lipsLumaFollow,
      );
      final lips = <String, Object?>{
        'color': solved.color.toRecipeColor().toHex(),
        'opacity': _round(solved.opacity),
        ..._lipFinish(m.lips.gloss),
      };
      reports.add(
        ImageRegionReport(layer: RecipeLayer.lips, confidence: confidence(m.lips), fitError: solved.fitError),
      );
      // Delineado de labios: el anillo más oscuro y distinto que el centro.
      final ring = m.lipLiner;
      final interior = m.lipInterior;
      if (usable(ring) &&
          interior.valid &&
          ring.color.distanceTo(interior.color) > ImageRecipePolicy.lipLinerMinDelta &&
          ring.color.l < interior.color.l) {
        final liner = solve(interior.color, ring.color, ImageRecipePolicy.lipLinerOpacity);
        lips['liner'] = {'color': liner.color.toRecipeColor().toHex(), 'opacity': _round(liner.opacity)};
        reports.add(
          ImageRegionReport(layer: RecipeLayer.lipLiner, confidence: confidence(ring), fitError: liner.fitError),
        );
      }
      json['lips'] = lips;
    }

    // Rubor: más rojo que la piel y con croma distinta.
    final cheeks = m.cheeks;
    if (usable(cheeks) &&
        cheeks.color.chromaDistanceTo(base) > ImageRecipePolicy.cheeksMinChroma &&
        cheeks.color.a > base.a) {
      final solved = solve(base, cheeks.color, ImageRecipePolicy.cheeksOpacity);
      json['cheeks'] = {
        'color': solved.color.toRecipeColor().toHex(),
        'opacity': _round(solved.opacity),
        'spread': 0.5,
        'placement': m.cheekPlacement.wireName,
      };
      reports.add(
        ImageRegionReport(layer: RecipeLayer.cheeks, confidence: confidence(cheeks), fitError: solved.fitError),
      );
    }

    // Sombras: las regiones que se apartan de la piel, hasta 4 (las de más
    // contraste), sin repetir un color casi igual. El hueso de la ceja solo
    // si es más claro que la piel (si no, son las cejas).
    final candidates =
        <({ShadowRegion region, LookRegion measured, double delta})>[
          for (final region in ShadowRegion.values)
            if (usable(m.eye(region)))
              (region: region, measured: m.eye(region), delta: m.eye(region).color.distanceTo(base)),
        ]..removeWhere(
          (c) =>
              c.delta <= ImageRecipePolicy.shadowMinDelta ||
              (c.region == ShadowRegion.browBone && c.measured.color.l <= base.l),
        );
    candidates.sort((x, y) => y.delta.compareTo(x.delta));
    final chosen = <({ShadowRegion region, LookRegion measured, double delta})>[];
    for (final c in candidates) {
      if (chosen.length >= RecipeLimits.maxShadowLayers) break;
      if (chosen.any(
        (other) => other.measured.color.distanceTo(c.measured.color) < ImageRecipePolicy.shadowMergeDelta,
      )) {
        continue;
      }
      chosen.add(c);
    }
    chosen.sort((x, y) => x.region.index.compareTo(y.region.index));
    final eyes = <String, Object?>{};
    final shadows = <Map<String, Object?>>[];
    for (final c in chosen) {
      final solved = solve(base, c.measured.color, ImageRecipePolicy.shadowOpacity);
      shadows.add({
        'color': solved.color.toRecipeColor().toHex(),
        'opacity': _round(solved.opacity),
        'region': c.region.wireName,
        'finish': _shadowFinish(c.measured.gloss).wireName,
      });
      reports.add(
        ImageRegionReport(
          layer: RecipeLayer.values[RecipeLayer.shadow0.index + shadows.length - 1],
          confidence: confidence(c.measured),
          fitError: solved.fitError,
        ),
      );
    }
    if (shadows.isNotEmpty) eyes['shadow'] = shadows;

    // Delineado: grosor medido sobre el mínimo del motor; wing si se ve.
    final linerThreshold = ImageRecipePolicy.linerThicknessMin + ImageRecipePolicy.linerMinMargin;
    if (usable(m.liner) && m.linerExtent >= linerThreshold) {
      final solved = solve(base, m.liner.color, ImageRecipePolicy.eyeLinerOpacity);
      // El borde visible del motor queda ~medio feather después del umbral.
      final thickness =
          (m.linerExtent - ImageRecipePolicy.linerFeather / 2 - ImageRecipePolicy.linerThicknessMin) /
          (ImageRecipePolicy.linerThicknessMax - ImageRecipePolicy.linerThicknessMin);
      eyes['liner'] = {
        'color': solved.color.toRecipeColor().toHex(),
        'opacity': _round(solved.opacity),
        'thickness': _round(thickness.clamp(0.0, 1.0)),
        'wing': _round(m.wingExtent >= ImageRecipePolicy.wingMin ? m.wingExtent.clamp(0.0, 1.0) : 0.0),
      };
      reports.add(
        ImageRegionReport(layer: RecipeLayer.eyeLiner, confidence: confidence(m.liner), fitError: solved.fitError),
      );
    }
    if (eyes.isNotEmpty) {
      eyes['lashes'] = {'opacity': ImageRecipePolicy.lashOpacity, 'length': 0.5, 'volume': 0.5};
      json['eyes'] = eyes;
    }

    final recipe = _validator.validate(json).recipe;
    if (recipe == null || reports.isEmpty) return const ImageRecipeResult(status: PhotoLookStatus.badImage);
    return ImageRecipeResult(recipe: recipe, regions: List.unmodifiable(reports));
  }

  /// Fiel, más intensa y más sutil (opacidades × factor), con los nombres dados.
  static List<MakeupRecipe> variants(MakeupRecipe faithful, {required List<String> names}) {
    MakeupRecipe scaled(double factor) {
      var out = faithful;
      for (final layer in RecipeEdits.layersOf(faithful)) {
        final amount = RecipeEdits.valueOf(out, layer)?.amount;
        if (amount != null) out = RecipeEdits.withAmount(out, layer, amount * factor);
      }
      return out;
    }

    final recipes = [faithful, scaled(ImageRecipePolicy.bolderFactor), scaled(ImageRecipePolicy.subtlerFactor)];
    return [
      for (var i = 0; i < recipes.length; i++)
        i < names.length ? RecipeEdits.withName(recipes[i], names[i]) : recipes[i],
    ];
  }

  static Map<String, Object?> _lipFinish(double gloss) {
    if (gloss < ImageRecipePolicy.matteBelow) return {'finish': LipFinish.matte.wireName, 'gloss': 0.0};
    if (gloss < ImageRecipePolicy.satinBelow) return {'finish': LipFinish.satin.wireName};
    return {'finish': LipFinish.gloss.wireName, 'gloss': _round(math.max(0.5, gloss))};
  }

  static ShadowFinish _shadowFinish(double gloss) => gloss < ImageRecipePolicy.matteBelow
      ? ShadowFinish.matte
      : gloss < ImageRecipePolicy.satinBelow
      ? ShadowFinish.satin
      : ShadowFinish.shimmer;

  /// Tres decimales: recetas legibles en Firestore y en el editor.
  static double _round(double value) => (value * 1000).round() / 1000;
}

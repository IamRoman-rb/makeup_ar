/// Guía de maquillaje (docs/ar_engine/COACH.md): mientras la usuaria se
/// maquilla de verdad, la app mide su cara con la cámara y la compara con el
/// look elegido, zona por zona. Dominio puro: sin Flutter ni el plugin.
///
/// La comparación usa el mismo modelo que el motor para pintar una capa
/// (`ImageRecipeBuilder.fitError`): sobre el color natural `base`, el color
/// de la receta con cantidad `t` da `base + t · (color − base)` (la L con
/// `lumaFollow`). Se busca la `t` que mejor explica lo observado:
/// - si con ninguna se parece, el tono no es el del look;
/// - si es menor que la opacidad de la receta, falta; si es mayor, sobra.
library;

import 'dart:math' as math;

import '../../ar/domain/makeup_recipe.dart';
import '../../studio/domain/image_look.dart';
import '../../studio/domain/image_recipe.dart';
import '../../studio/domain/oklab.dart';
import 'coach_policy.dart';

/// Zonas que revisa la guía, en el orden en que se aplican (v1, sin cejas:
/// no están en el esquema de recetas).
enum CoachZone {
  shadowLid,
  shadowCrease,
  shadowOuterV,
  shadowInnerCorner,
  shadowBrowBone,
  eyeLiner,
  cheeks,
  lipLiner,
  lips;

  static CoachZone shadow(ShadowRegion region) => switch (region) {
        ShadowRegion.lid => shadowLid,
        ShadowRegion.crease => shadowCrease,
        ShadowRegion.outerV => shadowOuterV,
        ShadowRegion.innerCorner => shadowInnerCorner,
        ShadowRegion.browBone => shadowBrowBone,
      };

  ShadowRegion? get shadowRegion => switch (this) {
        shadowLid => ShadowRegion.lid,
        shadowCrease => ShadowRegion.crease,
        shadowOuterV => ShadowRegion.outerV,
        shadowInnerCorner => ShadowRegion.innerCorner,
        shadowBrowBone => ShadowRegion.browBone,
        _ => null,
      };
}

/// Qué pasa en una zona respecto del look.
enum CoachVerdict {
  ok,

  /// Falta color (o delineado).
  tooLittle,

  /// Hay de más.
  tooMuch,

  /// El color quedó más oscuro, más claro u otro tono que el del look.
  tooDark,
  tooLight,
  otherTone,

  /// Delineado: grosor y largo del wing.
  tooThin,
  tooThick,
  wingShort,
  wingLong,

  /// La zona no se ve lo suficiente (giro, pelo, mano).
  notVisible,

  /// El delineado no se puede juzgar con la cara lejos.
  tooFar,
}

/// Problemas de la toma que impiden opinar.
enum CoachIssue { lookAtCamera, comeCloser, moreLight }

/// Color de una capa de la receta.
final class ColorTarget {
  const ColorTarget({required this.color, required this.opacity, this.lumaFollow = 1});

  final Oklab color;
  final double opacity;
  final double lumaFollow;
}

/// Delineado de ojos de la receta (unidades de la receta, 0..1).
final class LinerTarget {
  const LinerTarget({required this.thickness, required this.wing});

  final double thickness;
  final double wing;
}

/// Lo que pide el look, por zona.
final class CoachTarget {
  CoachTarget._(this.colors, this.liner);

  /// `lumaFollow` del labial si la receta no lo trae (el del motor,
  /// RecipeParams.kt) y grosor del delineado por defecto (ídem).
  static const double defaultLipsLumaFollow = 0.8;
  static const double defaultLinerThickness = 0.5;

  factory CoachTarget.from(MakeupRecipe recipe) {
    final colors = <CoachZone, ColorTarget>{};
    void add(CoachZone zone, RecipeColor color, double opacity, {double lumaFollow = 1}) {
      if (opacity < CoachPolicy.minTargetOpacity) return;
      final previous = colors[zone];
      // Dos capas en la misma región: manda la más cubriente.
      if (previous != null && previous.opacity >= opacity) return;
      colors[zone] = ColorTarget(color: Oklab.fromColor(color), opacity: opacity, lumaFollow: lumaFollow);
    }

    final lips = recipe.lips;
    if (lips != null) {
      add(CoachZone.lips, lips.color, lips.opacity, lumaFollow: lips.lumaFollow ?? defaultLipsLumaFollow);
      final liner = lips.liner;
      if (liner != null) add(CoachZone.lipLiner, liner.color, liner.opacity);
    }
    final cheeks = recipe.cheeks;
    if (cheeks != null) add(CoachZone.cheeks, cheeks.color, cheeks.opacity);
    final eyes = recipe.eyes;
    for (final layer in eyes?.shadow ?? const <EyeShadowLayer>[]) {
      add(CoachZone.shadow(layer.region), layer.color, layer.opacity);
    }
    final liner = eyes?.liner;
    final linerTarget = liner == null || liner.opacity < CoachPolicy.minTargetOpacity
        ? null
        : LinerTarget(thickness: liner.thickness ?? defaultLinerThickness, wing: liner.wing ?? 0);
    return CoachTarget._(Map.unmodifiable(colors), linerTarget);
  }

  final Map<CoachZone, ColorTarget> colors;
  final LinerTarget? liner;

  /// Zonas a revisar, en orden de aplicación.
  List<CoachZone> get zones => [
        for (final zone in CoachZone.values)
          if (colors.containsKey(zone) || (zone == CoachZone.eyeLiner && liner != null)) zone,
      ];

  bool get isEmpty => zones.isEmpty;
}

abstract final class CoachEvaluator {
  /// Veredicto de cada zona de [target] con la medida [current] (status ok).
  /// [baseline]: la referencia con la cara lavada, si se tomó.
  static Map<CoachZone, CoachVerdict> evaluate(CoachTarget target, LookMeasurements current,
      {LookMeasurements? baseline}) => {
        for (final zone in target.zones) zone: evaluateZone(zone, target, current, baseline: baseline),
      };

  static CoachVerdict evaluateZone(CoachZone zone, CoachTarget target, LookMeasurements current,
      {LookMeasurements? baseline}) {
    if (zone == CoachZone.eyeLiner) {
      final liner = target.liner;
      return liner == null ? CoachVerdict.ok : _liner(liner, current);
    }
    final wanted = target.colors[zone];
    if (wanted == null) return CoachVerdict.ok;
    final observed = _measured(zone, current);
    final base = _base(zone, current, baseline);
    if (!_visible(observed) || base == null) return CoachVerdict.notVisible;
    return colorVerdict(base, observed.color, wanted);
  }

  /// Compara un color observado sobre [base] con la capa [wanted].
  static CoachVerdict colorVerdict(Oklab base, Oklab observed, ColorTarget wanted) {
    final dl = (wanted.color.l - base.l) * wanted.lumaFollow;
    final da = wanted.color.a - base.a;
    final db = wanted.color.b - base.b;
    final contrast2 = dl * dl + da * da + db * db;
    final expected = Oklab(base.l + dl * wanted.opacity, base.a + da * wanted.opacity, base.b + db * wanted.opacity);
    if (contrast2 < CoachPolicy.minContrast * CoachPolicy.minContrast) {
      // El look casi no se distingue del color natural: solo el tono.
      return observed.distanceTo(expected) <= CoachPolicy.toneTolerance ? CoachVerdict.ok : _tone(observed, expected);
    }
    final ol = observed.l - base.l;
    final oa = observed.a - base.a;
    final ob = observed.b - base.b;
    final amount = ((ol * dl + oa * da + ob * db) / contrast2).clamp(0.0, CoachPolicy.maxAmount);
    final fitted = Oklab(base.l + dl * amount, base.a + da * amount, base.b + db * amount);
    if (fitted.distanceTo(observed) > CoachPolicy.toneTolerance) return _tone(observed, expected);
    // El ruido de la medida (ΔE) mueve la cantidad hasta ruido / contraste: con
    // poco contraste entre el look y el natural hace falta más evidencia para
    // decir que falta o que sobra (coach_calibration_test.dart).
    final slack = CoachPolicy.measurementNoise / math.sqrt(contrast2);
    if (amount < wanted.opacity * (1 - CoachPolicy.amountLow) - slack) return CoachVerdict.tooLittle;
    if (amount > wanted.opacity * (1 + CoachPolicy.amountHigh) + slack) return CoachVerdict.tooMuch;
    return CoachVerdict.ok;
  }

  static CoachVerdict _tone(Oklab observed, Oklab expected) {
    final dl = observed.l - expected.l;
    final dc = observed.chromaDistanceTo(expected);
    if (dl.abs() >= dc) return dl < 0 ? CoachVerdict.tooDark : CoachVerdict.tooLight;
    return CoachVerdict.otherTone;
  }

  static CoachVerdict _liner(LinerTarget wanted, LookMeasurements current) {
    if (current.eyeDistancePx > 0 && current.eyeDistancePx < CoachPolicy.minEyeDistanceForLinerPx) {
      return CoachVerdict.tooFar;
    }
    if (!current.liner.valid && current.linerExtent <= 0) {
      return wanted.thickness > 0 ? CoachVerdict.tooLittle : CoachVerdict.ok;
    }
    // Mismo mapeo que "Desde foto" (ImageRecipeBuilder.build).
    final detected = current.linerExtent >= ImageRecipePolicy.linerThicknessMin + ImageRecipePolicy.linerMinMargin;
    if (!detected) return CoachVerdict.tooLittle;
    final thickness = ((current.linerExtent - ImageRecipePolicy.linerFeather / 2 - ImageRecipePolicy.linerThicknessMin) /
            (ImageRecipePolicy.linerThicknessMax - ImageRecipePolicy.linerThicknessMin))
        .clamp(0.0, 1.0);
    if (thickness < wanted.thickness - CoachPolicy.linerThicknessTolerance) return CoachVerdict.tooThin;
    if (thickness > wanted.thickness + CoachPolicy.linerThicknessTolerance) return CoachVerdict.tooThick;
    final wing = current.wingExtent >= ImageRecipePolicy.wingMin ? current.wingExtent.clamp(0.0, 1.0) : 0.0;
    if (wanted.wing >= ImageRecipePolicy.wingMin) {
      if (wing < wanted.wing - CoachPolicy.wingTolerance) return CoachVerdict.wingShort;
      if (wing > wanted.wing + CoachPolicy.wingTolerance) return CoachVerdict.wingLong;
    } else if (wing > ImageRecipePolicy.wingMin + CoachPolicy.wingTolerance) {
      return CoachVerdict.wingLong;  // el look no lleva cola
    }
    return CoachVerdict.ok;
  }

  static LookRegion _measured(CoachZone zone, LookMeasurements m) => switch (zone) {
        CoachZone.lips => m.lips,
        CoachZone.lipLiner => m.lipLiner,
        CoachZone.cheeks => m.cheeks,
        CoachZone.eyeLiner => m.liner,
        _ => m.eye(zone.shadowRegion ?? ShadowRegion.lid),
      };

  static bool _visible(LookRegion region) => region.valid && region.coverage >= CoachPolicy.minCoverage;

  /// Color natural de la zona: la referencia con la cara lavada si hay; si
  /// no, la piel con la misma luz (el labio, estimado desde la piel).
  static Oklab? _base(CoachZone zone, LookMeasurements current, LookMeasurements? baseline) {
    Oklab? valid(LookRegion? region) => region != null && region.valid ? region.color : null;
    final skin = valid(current.skin);
    switch (zone) {
      case CoachZone.lips:
        final natural = valid(baseline?.lips);
        if (natural != null) return natural;
        return skin == null
            ? null
            : Oklab(skin.l + CoachPolicy.naturalLipDeltaL, skin.a + CoachPolicy.naturalLipDeltaA, skin.b);
      case CoachZone.lipLiner:
        // El delineado va sobre el labial: su base es el centro del labio.
        return valid(current.lipInterior) ?? _base(CoachZone.lips, current, baseline);
      case CoachZone.cheeks:
        return valid(baseline?.cheeks) ?? valid(current.cheekSkin) ?? skin;
      case CoachZone.eyeLiner:
        return skin;
      default:
        final region = zone.shadowRegion ?? ShadowRegion.lid;
        return valid(baseline?.eye(region)) ?? valid(current.eyeSkin) ?? skin;
    }
  }
}

/// Lo que la guía tiene para decir ahora.
final class CoachPrompt {
  const CoachPrompt.zone(CoachZone this.zone, CoachVerdict this.verdict)
      : issue = null,
        done = false;
  const CoachPrompt.issue(CoachIssue this.issue)
      : zone = null,
        verdict = null,
        done = false;
  const CoachPrompt.done()
      : zone = null,
        verdict = null,
        issue = null,
        done = true;

  final CoachZone? zone;
  final CoachVerdict? verdict;
  final CoachIssue? issue;
  final bool done;

  @override
  bool operator ==(Object other) =>
      other is CoachPrompt && other.zone == zone && other.verdict == verdict && other.issue == issue && other.done == done;

  @override
  int get hashCode => Object.hash(zone, verdict, issue, done);
}

/// Estado de una guía: veredictos estables por zona (histéresis), la zona en
/// foco y cuándo decir algo. El reloj se inyecta (tests).
final class CoachSession {
  CoachSession(this.target);

  final CoachTarget target;

  /// Referencia con la cara lavada (promedio de las muestras), o null.
  LookMeasurements? baseline;

  final Map<CoachZone, CoachVerdict> _stable = {};
  final Map<CoachZone, ({CoachVerdict verdict, int count})> _pending = {};
  CoachIssue? _issue;
  CoachPrompt? _lastSpoken;
  Duration? _lastSpokenAt;

  /// Veredicto estable por zona (las que todavía no se midieron no están).
  Map<CoachZone, CoachVerdict> get verdicts => Map.unmodifiable(_stable);

  /// Problema de la última toma (mirá de frente, acercate, falta luz).
  CoachIssue? get issue => _issue;

  /// La primera zona, en orden de aplicación, que no está bien.
  CoachZone? get focus {
    for (final zone in target.zones) {
      final verdict = _stable[zone];
      if (verdict != null && verdict != CoachVerdict.ok && verdict != CoachVerdict.notVisible) return zone;
    }
    return null;
  }

  bool get done => target.zones.isNotEmpty && target.zones.every((zone) => _stable[zone] == CoachVerdict.ok);

  /// Lo que hay que mostrar ahora (null hasta la primera medida útil).
  CoachPrompt? get current {
    final issue = _issue;
    if (issue != null) return CoachPrompt.issue(issue);
    if (done) return const CoachPrompt.done();
    final zone = focus;
    if (zone != null) return CoachPrompt.zone(zone, _stable[zone] ?? CoachVerdict.ok);
    // Lo que queda sin ok no se ve: que mire a la cámara.
    if (target.zones.any((zone) => _stable[zone] == CoachVerdict.notVisible)) {
      return const CoachPrompt.issue(CoachIssue.lookAtCamera);
    }
    return null;
  }

  /// Agrega una medida tomada en [now]. Devuelve la indicación para decir en
  /// voz alta, o null si no cambió (o se dijo hace menos de repeatAfter).
  CoachPrompt? add(LookMeasurements m, Duration now) {
    final issue = issueOf(m.status);
    _issue = issue;
    if (issue == null) {
      final raw = CoachEvaluator.evaluate(target, m, baseline: baseline);
      raw.forEach(_confirm);
    }
    return _toSpeak(now);
  }

  /// Promedio de las muestras con la cara lavada (las que salieron bien).
  /// Devuelve false si ninguna sirvió.
  bool setBaseline(List<LookMeasurements> samples) {
    final ok = [for (final m in samples) if (m.status == PhotoLookStatus.ok) m];
    if (ok.isEmpty) return false;
    baseline = averageMeasurements(ok);
    return true;
  }

  void _confirm(CoachZone zone, CoachVerdict verdict) {
    final stable = _stable[zone];
    if (stable == null) {
      _stable[zone] = verdict;  // la primera lectura vale
      return;
    }
    if (verdict == stable) {
      _pending.remove(zone);
      return;
    }
    final pending = _pending[zone];
    final count = pending != null && pending.verdict == verdict ? pending.count + 1 : 1;
    if (count >= CoachPolicy.confirmations) {
      _stable[zone] = verdict;
      _pending.remove(zone);
    } else {
      _pending[zone] = (verdict: verdict, count: count);
    }
  }

  CoachPrompt? _toSpeak(Duration now) {
    final prompt = current;
    if (prompt == null) return null;
    final last = _lastSpoken;
    final lastAt = _lastSpokenAt;
    final repeat = !prompt.done && lastAt != null && now - lastAt >= CoachPolicy.repeatAfter;
    if (prompt == last && !repeat) return null;
    _lastSpoken = prompt;
    _lastSpokenAt = now;
    return prompt;
  }

  static CoachIssue? issueOf(PhotoLookStatus status) => switch (status) {
        PhotoLookStatus.ok => null,
        PhotoLookStatus.faceTooSmall => CoachIssue.comeCloser,
        PhotoLookStatus.badImage => CoachIssue.moreLight,
        PhotoLookStatus.noFace || PhotoLookStatus.lowPresence || PhotoLookStatus.profile => CoachIssue.lookAtCamera,
      };
}

/// Promedio región por región (las válidas en alguna muestra).
LookMeasurements averageMeasurements(List<LookMeasurements> samples) {
  LookRegion avg(LookRegion Function(LookMeasurements m) pick) {
    final valid = [for (final m in samples) if (pick(m).valid) pick(m)];
    if (valid.isEmpty) return LookRegion.missing;
    final n = valid.length;
    return LookRegion(
      valid: true,
      color: Oklab(
        valid.fold(0.0, (s, r) => s + r.color.l) / n,
        valid.fold(0.0, (s, r) => s + r.color.a) / n,
        valid.fold(0.0, (s, r) => s + r.color.b) / n,
      ),
      gloss: valid.fold(0.0, (s, r) => s + r.gloss) / n,
      coverage: valid.fold(1.0, (s, r) => math.min(s, r.coverage)),
    );
  }

  final first = samples.first;
  return LookMeasurements(
    status: PhotoLookStatus.ok,
    yawRatio: first.yawRatio,
    eyeDistancePx: first.eyeDistancePx,
    skin: avg((m) => m.skin),
    lips: avg((m) => m.lips),
    lipLiner: avg((m) => m.lipLiner),
    lipInterior: avg((m) => m.lipInterior),
    cheeks: avg((m) => m.cheeks),
    cheekPlacement: first.cheekPlacement,
    eyeRegions: [
      for (final region in ShadowRegion.values) avg((m) => m.eye(region)),
    ],
    liner: avg((m) => m.liner),
    linerExtent: samples.fold(0.0, (s, m) => s + m.linerExtent) / samples.length,
    wingExtent: samples.fold(0.0, (s, m) => s + m.wingExtent) / samples.length,
    cheekSkin: avg((m) => m.cheekSkin),
    eyeSkin: avg((m) => m.eyeSkin),
  );
}

/// Toma una medida de la cara en vivo (implementación: el motor nativo).
/// Sin cara devuelve status noFace (no tira).
abstract interface class ICoachSampler {
  Future<LookMeasurements> sample();
}

/// Voz de la guía (implementación: TextToSpeech de Android en el plugin).
abstract interface class ICoachVoice {
  /// Dice [text] cortando lo anterior. [locale]: es, en, pt o fr. Devuelve
  /// false si el idioma no está disponible (queda solo el texto).
  Future<bool> speak(String text, {required String locale});
  Future<void> stop();

  /// Libera el motor de voz (al salir de la guía).
  Future<void> release();
}

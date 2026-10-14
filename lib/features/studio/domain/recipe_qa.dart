/// QA automático de una receta antes de publicar (F5, informe §10.10).
/// Dominio puro.
///
/// Cada capa se "pinta" en el píxel medio de su región sobre caras de prueba
/// sintéticas: los 5 tonos de piel de tools/makeup/calibration_grid.py con
/// luz neutra, y el tono medio con luz cálida y fría (el maquillaje adaptado a
/// la luz como en scene_light.cpp). Misma matemática que el motor:
/// lips.frag (labial y delineado de labios) y face.frag/eyes.frag (el resto),
/// con su referencia Python en tools/studio/qa_reference.py, que genera
/// test/fixtures/qa_render_cases.json para comprobar que coinciden.
///
/// Sin fotos de personas: no hay dataset ni consentimiento que gestionar.
library;

import 'dart:math' as math;

import '../../ar/domain/makeup_recipe.dart';
import 'oklab.dart';
import 'recipe_edits.dart';

/// Los chequeos del §10.10.
enum QaCheckKind { visibility, clipping, consistency, coverage, cost }

enum QaLevel { pass, warn, fail }

/// Motivo de un aviso o falla (para el texto en la UI).
enum QaReason {
  /// No se nota en ningún tono (falla).
  invisible,

  /// Apenas se nota en el tono medio.
  subtle,

  /// Color muy saturado que el motor desatura con luz (se lava).
  washedOut,

  /// Base o iluminador que aclara la piel profunda como tiza (falla).
  chalky,

  /// Color que aclara la piel profunda (ceniza).
  ashy,

  /// Se nota en el tono medio pero no en el más claro o el más profundo.
  fadesOnTone,

  /// Delineado y wing al máximo.
  extremeLiner,

  /// Base muy cubritiva (efecto máscara).
  maskFoundation,

  /// Rubor máximo e intenso.
  heavyBlush,

  /// 3 efectos a la vez: combinación sin medir en el E20.
  effectsUnmeasured,
}

final class QaIssue {
  const QaIssue({required this.kind, required this.level, required this.reason, this.layer});

  final QaCheckKind kind;
  final QaLevel level;
  final QaReason reason;

  /// Capa afectada (null en los chequeos de toda la receta).
  final RecipeLayer? layer;
}

final class QaReport {
  const QaReport(this.issues);

  final List<QaIssue> issues;

  /// El peor nivel de un chequeo (pass si no tiene avisos).
  QaLevel levelOf(QaCheckKind kind) => issues
      .where((i) => i.kind == kind)
      .fold(QaLevel.pass, (worst, i) => i.level.index > worst.index ? i.level : worst);

  List<QaIssue> issuesOf(QaCheckKind kind) => [for (final i in issues) if (i.kind == kind) i];

  /// Con una falla (rojo) no se publica.
  bool get blocksPublish => issues.any((i) => i.level == QaLevel.fail);
}

enum QaLight { neutral, warm, cool }

/// Una capa pintada en una escena (para el test de paridad con Python).
final class QaSample {
  const QaSample({
    required this.layer,
    required this.tone,
    required this.light,
    required this.camera,
    required this.out,
    required this.maxShading,
  });

  final RecipeLayer layer;
  final int tone;
  final QaLight light;

  /// sRGB [0, 1] del píxel medio sin maquillaje y con la capa.
  final List<double> camera;
  final List<double> out;

  /// Mayor sombreado con el color todavía en gamut ([1, 1,6]).
  final double maxShading;
}

/// Umbrales (iniciales, calibrados para que los presets pasen: `python
/// tools/studio/qa_reference.py --report`).
abstract final class QaPolicy {
  /// ΔE OK máximo entre todos los tonos por debajo del cual la capa no se nota.
  static const double invisibleBelow = 0.008;

  /// ΔE OK en el tono medio por debajo del cual apenas se nota.
  static const double subtleBelow = 0.012;

  /// ΔE OK en el tono más claro o el más profundo por debajo del cual se pierde.
  static const double fadesBelow = 0.006;

  /// Subida de L sobre la piel más profunda: tiza (base, iluminador) o ceniza.
  static const double lightenLimit = 0.15;

  /// Color saturado (croma OKLab) que sale de gamut antes de este sombreado.
  static const double saturatedChroma = 0.15;
  static const double minShadingInGamut = 1.1;

  // Cobertura plausible.
  static const double extremeLiner = 0.85;
  static const double maskCoverage = 0.8;
  static const double heavySpread = 0.95;
  static const double heavyBlushOpacity = 0.7;
}

abstract final class RecipeQa {
  // Escenas: los mismos tonos y luces que tools/makeup/calibration_grid.py.
  // (L, croma, tono°) OKLab, de muy clara a profunda.
  static const List<(double, double, double)> skinTones = [
    (0.86, 0.045, 65.0),
    (0.78, 0.060, 60.0),
    (0.68, 0.070, 58.0),
    (0.55, 0.070, 55.0),
    (0.40, 0.050, 50.0),
  ];
  static const int mediumTone = 2;
  static const int deepTone = 4;
  static const int lightTone = 0;
  static const Map<QaLight, List<double>> _tints = {
    QaLight.warm: [1.15, 1.0, 0.78],
    QaLight.cool: [0.88, 1.0, 1.18],
  };
  static const List<(int, QaLight)> scenes = [
    (0, QaLight.neutral),
    (1, QaLight.neutral),
    (2, QaLight.neutral),
    (3, QaLight.neutral),
    (4, QaLight.neutral),
    (2, QaLight.warm),
    (2, QaLight.cool),
  ];

  // Labio natural de cada tono (calibration_grid.bare_face).
  static const double _lipDeltaL = 0.07;
  static const double _lipChroma = 0.075;
  static const double _lipHue = 22.0;
  static const double _backgroundSrgb = 0.5;

  // Constantes del motor (engine_config.h y shaders; el test de paridad
  // detecta si cambian de un lado).
  static const double _lightAdaptDegree = 0.5;
  static const double _lightAdaptGainMin = 0.85;
  static const double _lightAdaptGainMax = 1.18;
  static const double _highlightLumaFollow = 0.4;
  static const double _highlightShine = 0.16;
  static const double _shadowSatinShine = 0.08;
  static const double _defaultLipLumaFollow = 0.8;
  static const double _shadingMax = 1.6;
  static const double _lightnessMin = 0.1;
  static const double _shineShadingLow = 0.85;
  static const double _shineShadingHigh = 1.1;
  static const int _gamutSteps = 6;
  static const double _gamutEpsilon = 1e-5;
  static const int _shadingSteps = 12;
  static const List<double> _luminance = [0.2126, 0.7152, 0.0722];

  static QaReport check(MakeupRecipe recipe) {
    final issues = <QaIssue>[];
    final samples = render(recipe);
    final json = recipe.toJson();
    for (final layer in _layers(json)) {
      QaSample sample(int tone, QaLight light) =>
          samples.firstWhere((s) => s.layer == layer.layer && s.tone == tone && s.light == light);
      double delta(QaSample s) => _labOfSrgb(s.camera).distanceTo(_labOfSrgb(s.out));

      final neutral = [for (var t = 0; t < skinTones.length; t++) delta(sample(t, QaLight.neutral))];
      final mid = neutral[mediumTone];
      if (neutral.reduce(math.max) < QaPolicy.invisibleBelow) {
        issues.add(QaIssue(kind: QaCheckKind.visibility, level: QaLevel.fail, reason: QaReason.invisible, layer: layer.layer));
      } else if (mid < QaPolicy.subtleBelow) {
        issues.add(QaIssue(kind: QaCheckKind.visibility, level: QaLevel.warn, reason: QaReason.subtle, layer: layer.layer));
      }

      final midSample = sample(mediumTone, QaLight.neutral);
      final chroma = math.sqrt(layer.color.a * layer.color.a + layer.color.b * layer.color.b);
      if (chroma >= QaPolicy.saturatedChroma && midSample.maxShading < QaPolicy.minShadingInGamut) {
        issues.add(QaIssue(kind: QaCheckKind.clipping, level: QaLevel.warn, reason: QaReason.washedOut, layer: layer.layer));
      }

      final deep = sample(deepTone, QaLight.neutral);
      final lighten = _labOfSrgb(deep.out).l - _labOfSrgb(deep.camera).l;
      if (lighten > QaPolicy.lightenLimit) {
        final chalky = layer.layer == RecipeLayer.foundation || layer.layer == RecipeLayer.highlight;
        issues.add(QaIssue(
          kind: QaCheckKind.consistency,
          level: chalky ? QaLevel.fail : QaLevel.warn,
          reason: chalky ? QaReason.chalky : QaReason.ashy,
          layer: layer.layer,
        ));
      } else if (mid >= QaPolicy.subtleBelow &&
          (neutral[deepTone] < QaPolicy.fadesBelow || neutral[lightTone] < QaPolicy.fadesBelow)) {
        issues.add(QaIssue(kind: QaCheckKind.consistency, level: QaLevel.warn, reason: QaReason.fadesOnTone, layer: layer.layer));
      }
    }

    // Cobertura plausible.
    final liner = recipe.eyes?.liner;
    // Sin valor, los del motor (RecipeParams.kt): grosor 0,5, wing 0, spread 0,5.
    if (liner != null && (liner.thickness ?? 0.5) > QaPolicy.extremeLiner && (liner.wing ?? 0) > QaPolicy.extremeLiner) {
      issues.add(const QaIssue(kind: QaCheckKind.coverage, level: QaLevel.warn, reason: QaReason.extremeLiner,
          layer: RecipeLayer.eyeLiner));
    }
    final foundation = RecipeEdits.valueOf(recipe, RecipeLayer.foundation);
    if (foundation != null && foundation.amount > QaPolicy.maskCoverage) {
      issues.add(const QaIssue(kind: QaCheckKind.coverage, level: QaLevel.warn, reason: QaReason.maskFoundation,
          layer: RecipeLayer.foundation));
    }
    final cheeks = recipe.cheeks;
    if (cheeks != null && (cheeks.spread ?? 0.5) >= QaPolicy.heavySpread && cheeks.opacity > QaPolicy.heavyBlushOpacity) {
      issues.add(const QaIssue(kind: QaCheckKind.coverage, level: QaLevel.warn, reason: QaReason.heavyBlush,
          layer: RecipeLayer.cheeks));
    }

    // Costo: el look completo se midió en el E20 (28 fps); 3 efectos a la vez, no.
    if ((recipe.effects?.length ?? 0) >= RecipeLimits.maxEffects) {
      issues.add(const QaIssue(kind: QaCheckKind.cost, level: QaLevel.warn, reason: QaReason.effectsUnmeasured));
    }
    return QaReport(List.unmodifiable(issues));
  }

  /// Cada capa con color en cada escena.
  static List<QaSample> render(MakeupRecipe recipe) {
    final json = recipe.toJson();
    final layers = _layers(json);
    final lips = json['lips'];
    final out = <QaSample>[];
    for (final (tone, light) in scenes) {
      final tint = _normalizedTint(light);
      final (skinL, skinC, skinH) = skinTones[tone];
      final skinCamera = _camera(_lch(skinL, skinC, skinH), tint);
      final lipCamera = _camera(_lch(skinL - _lipDeltaL, _lipChroma, _lipHue), tint);
      final gain = tint == null ? null : _sceneGain(tint);
      List<double> adapt(List<double> lab) => gain == null ? lab : _adapt(lab, gain);

      for (final layer in layers) {
        final target = adapt(_srgbHexToOk(layer.hex));
        final List<double> rendered;
        final List<double> camera;
        if (layer.kind == _Kind.face) {
          camera = skinCamera;
          rendered = _compose(skinCamera, target, layer.amount, layer.lumaFollow, layer.shine);
        } else {
          camera = lipCamera;
          final lipsMap = lips is Map ? lips : const <String, Object?>{};
          final lipTarget = adapt(_srgbHexToOk(lipsMap['color'] as String? ?? '#000000'));
          final opacity = (lipsMap['opacity'] as num?)?.toDouble() ?? 0;
          final lumaFollow = (lipsMap['lumaFollow'] as num?)?.toDouble() ?? _defaultLipLumaFollow;
          rendered = layer.kind == _Kind.lips
              ? _shadeLips(lipCamera, lipTarget, opacity, lumaFollow)
              : _shadeLips(lipCamera, lipTarget, opacity, lumaFollow, liner: layer.amount, linerLab: target);
        }
        out.add(QaSample(
          layer: layer.layer,
          tone: tone,
          light: light,
          camera: camera,
          out: rendered,
          maxShading: _maxShading(target),
        ));
      }
    }
    return out;
  }

  // --- Capas (mismo orden y nombres que RecipeLayer y qa_reference.layers_of) ---

  static List<_Layer> _layers(Map<String, Object?> json) {
    double num_(Object? v, double fallback) => v is num ? v.toDouble() : fallback;
    final out = <_Layer>[];
    final lips = json['lips'];
    if (lips is Map) {
      out.add(_Layer(RecipeLayer.lips, _Kind.lips, lips['color'] as String, num_(lips['opacity'], 0),
          num_(lips['lumaFollow'], _defaultLipLumaFollow), 0));
      final liner = lips['liner'];
      if (liner is Map) {
        out.add(_Layer(RecipeLayer.lipLiner, _Kind.lipLiner, liner['color'] as String, num_(liner['opacity'], 0), 1, 0));
      }
    }
    final cheeks = json['cheeks'];
    if (cheeks is Map) {
      out.add(_Layer(RecipeLayer.cheeks, _Kind.face, cheeks['color'] as String, num_(cheeks['opacity'], 0), 1, 0));
    }
    final skin = json['skin'];
    if (skin is Map) {
      final foundation = skin['foundation'];
      if (foundation is Map) {
        out.add(_Layer(RecipeLayer.foundation, _Kind.face, foundation['color'] as String,
            num_(foundation['coverage'], 0), 1, 0));
      }
      final contour = skin['contour'];
      if (contour is Map) {
        out.add(_Layer(RecipeLayer.contour, _Kind.face, contour['color'] as String, num_(contour['opacity'], 0), 1, 0));
      }
      final highlight = skin['highlight'];
      if (highlight is Map) {
        out.add(_Layer(RecipeLayer.highlight, _Kind.face, highlight['color'] as String,
            num_(highlight['opacity'], 0), _highlightLumaFollow, _highlightShine));
      }
    }
    final eyes = json['eyes'];
    if (eyes is Map) {
      final liner = eyes['liner'];
      if (liner is Map) {
        out.add(_Layer(RecipeLayer.eyeLiner, _Kind.face, liner['color'] as String, num_(liner['opacity'], 0), 1, 0));
      }
      final shadows = eyes['shadow'];
      if (shadows is List) {
        for (var i = 0; i < shadows.length && i < RecipeLimits.maxShadowLayers; i++) {
          final shadow = shadows[i];
          if (shadow is! Map) continue;
          final finish = shadow['finish'] as String? ?? 'matte';
          final shine = finish == 'satin' || finish == 'shimmer' ? _shadowSatinShine : 0.0;
          out.add(_Layer(RecipeLayer.values[RecipeLayer.shadow0.index + i], _Kind.face, shadow['color'] as String,
              num_(shadow['opacity'], 0), 1, shine));
        }
      }
    }
    return out;
  }

  // --- Escena ---

  static List<double>? _normalizedTint(QaLight light) {
    final tint = _tints[light];
    if (tint == null) return null;
    final lum = _dot(tint, _luminance);
    return [for (final c in tint) c / lum];
  }

  static List<double> _camera(List<double> lab, List<double>? tint) {
    var linear = _fromOk(lab);
    if (tint != null) linear = [for (var i = 0; i < 3; i++) linear[i] * tint[i]];
    return _linToSrgb(linear);
  }

  /// Ganancia gray-world de un fondo gris bajo la luz (face_shading.scene_gain).
  static List<double> _sceneGain(List<double> tint) {
    final background = _linToSrgb([for (final t in tint) math.pow(_backgroundSrgb, 2.2) * t]);
    final linear = [for (final c in background) math.pow(c, 2.2).toDouble()];
    final mean = (linear[0] + linear[1] + linear[2]) / 3;
    final gain = [
      for (final c in linear)
        math.pow(c / mean, _lightAdaptDegree).toDouble().clamp(_lightAdaptGainMin, _lightAdaptGainMax),
    ];
    final lum = _dot(gain, _luminance);
    return [for (final g in gain) g / lum];
  }

  static List<double> _adapt(List<double> lab, List<double> gain) {
    final linear = _fromOk(lab);
    return _toOk([for (var i = 0; i < 3; i++) linear[i] * gain[i]]);
  }

  // --- Mezcla (face_shading.compose con una capa; lip_shading.shade) ---

  static List<double> _compose(List<double> camera, List<double> target, double amount, double lumaFollow,
      double layerShine) {
    final lab = _toOk(_srgbToLin(camera));
    final shading = (lab[0] / math.max(lab[0], _lightnessMin)).clamp(0.0, _shadingMax);
    final a = amount.clamp(0.0, 1.0);
    if (a <= 0) return camera;
    final lit = [for (final c in target) c * shading];
    final lightness = (lab[0] + (lit[0] - lab[0]) * a * lumaFollow).clamp(0.0, 1.0);
    final mixed = [lightness, lab[1] + (lit[1] - lab[1]) * a, lab[2] + (lit[2] - lab[2]) * a];
    final shine = layerShine * a;
    final linear = _toLinearInGamut(mixed);
    final gate = _smoothstep(_shineShadingLow, _shineShadingHigh, shading);
    return _linToSrgb([for (final c in linear) math.min(c + shine * gate, 1.0)]);
  }

  static List<double> _shadeLips(List<double> camera, List<double> target, double opacity, double lumaFollow,
      {double liner = 0, List<double>? linerLab}) {
    final w = opacity.clamp(0.0, 1.0);
    if (w <= 0 && liner <= 0) return camera;
    final lab = _toOk(_srgbToLin(camera));
    // El labio de referencia es el mismo píxel: sombreado 1.
    final shading = (lab[0] / math.max(lab[0], _lightnessMin)).clamp(0.0, _shadingMax);
    final lit = [for (final c in target) c * shading];
    var lightness = (lab[0] + (lit[0] - lab[0]) * w * lumaFollow).clamp(0.0, 1.0);
    var a = lab[1] + (lit[1] - lab[1]) * w;
    var b = lab[2] + (lit[2] - lab[2]) * w;
    if (linerLab != null) {
      final k = math.min(shading, 1.0);
      final linerLit = [for (final c in linerLab) c * k];
      lightness = (lightness + (linerLit[0] - lightness) * liner).clamp(0.0, 1.0);
      a = a + (linerLit[1] - a) * liner;
      b = b + (linerLit[2] - b) * liner;
    }
    return _linToSrgb(_toLinearInGamut([lightness, a, b]));
  }

  // --- Gamut (color.glsl: oklabToLinearInGamut) ---

  static bool _inGamut(List<double> linear) =>
      linear.every((c) => c >= -_gamutEpsilon && c <= 1.0 + _gamutEpsilon);

  static List<double> _toLinearInGamut(List<double> lab) {
    final direct = _fromOk(lab);
    if (_inGamut(direct)) return [for (final c in direct) c.clamp(0.0, 1.0)];
    var lo = 0.0;
    var hi = 1.0;
    for (var i = 0; i < _gamutSteps; i++) {
      final mid = 0.5 * (lo + hi);
      if (_inGamut(_fromOk([lab[0], lab[1] * mid, lab[2] * mid]))) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    return [for (final c in _fromOk([lab[0], lab[1] * lo, lab[2] * lo])) c.clamp(0.0, 1.0)];
  }

  static double _maxShading(List<double> lab) {
    bool inside(double s) => _inGamut(_fromOk([for (final c in lab) c * s]));
    if (!inside(1)) return 1;
    if (inside(_shadingMax)) return _shadingMax;
    var lo = 1.0;
    var hi = _shadingMax;
    for (var i = 0; i < _shadingSteps; i++) {
      final mid = 0.5 * (lo + hi);
      if (inside(mid)) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    return lo;
  }

  // --- Color (sample_region_reference.py: gamma 2.2, to_ok con max(·, 0)) ---

  static List<double> _lch(double l, double c, double hueDeg) {
    final h = hueDeg * math.pi / 180;
    return [l, c * math.cos(h), c * math.sin(h)];
  }

  static List<double> _srgbToLin(List<double> srgb) => [for (final c in srgb) math.pow(c.clamp(0.0, 1.0), 2.2).toDouble()];

  static List<double> _linToSrgb(List<double> linear) =>
      [for (final c in linear) math.pow(c.clamp(0.0, 1.0), 1 / 2.2).toDouble()];

  static List<double> _srgbHexToOk(String hex) {
    final color = RecipeColor.tryParse(hex) ?? const RecipeColor(0);
    return _toOk(_srgbToLin([color.red / 255, color.green / 255, color.blue / 255]));
  }

  static Oklab _labOfSrgb(List<double> srgb) {
    final lab = _toOk(_srgbToLin(srgb));
    return Oklab(lab[0], lab[1], lab[2]);
  }

  static List<double> _toOk(List<double> rgb) {
    double cbrt(double x) => math.pow(math.max(x, 0.0), 1 / 3).toDouble();
    final l = cbrt(0.4122214708 * rgb[0] + 0.5363325363 * rgb[1] + 0.0514459929 * rgb[2]);
    final m = cbrt(0.2119034982 * rgb[0] + 0.6806995451 * rgb[1] + 0.1073969566 * rgb[2]);
    final s = cbrt(0.0883024619 * rgb[0] + 0.2817188376 * rgb[1] + 0.6299787005 * rgb[2]);
    return [
      0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
      1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
      0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s,
    ];
  }

  static List<double> _fromOk(List<double> lab) => Oklab(lab[0], lab[1], lab[2]).toLinear();

  static double _dot(List<double> a, List<double> b) => a[0] * b[0] + a[1] * b[1] + a[2] * b[2];

  static double _smoothstep(double edge0, double edge1, double x) {
    final t = ((x - edge0) / (edge1 - edge0)).clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
  }
}

enum _Kind { lips, lipLiner, face }

final class _Layer {
  _Layer(this.layer, this.kind, this.hex, this.amount, this.lumaFollow, this.shine)
      : color = Oklab.fromColor(RecipeColor.tryParse(hex) ?? const RecipeColor(0));

  final RecipeLayer layer;
  final _Kind kind;
  final String hex;
  final double amount;
  final double lumaFollow;
  final double shine;

  /// Color de la receta sin adaptar (para la croma del chequeo de saturación).
  final Oklab color;
}

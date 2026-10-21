import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:ar_makeup_app/features/ar/domain/recipe_presets.dart';
import 'package:ar_makeup_app/features/coach/domain/coach.dart';
import 'package:ar_makeup_app/features/coach/domain/coach_policy.dart';
import 'package:ar_makeup_app/features/studio/domain/oklab.dart';

/// Calibración de la guía (COACH.md): 5 tonos de piel (los de
/// tools/makeup/calibration_grid.py, OKLCh) × los presets × sus zonas, con el
/// ruido de una cámara en vivo. Lo que tiene que pasar en todos los casos:
/// - el look bien aplicado da "bien", también con ruido;
/// - la cara sin maquillaje da "falta" si el look se distingue del natural.

/// (L, croma, tono en grados) de calibration_grid.py: SKIN_TONES.
const _tones = [
  (0.86, 0.045, 65.0),
  (0.78, 0.060, 60.0),
  (0.68, 0.070, 58.0),
  (0.55, 0.070, 55.0),
  (0.40, 0.050, 50.0),
];

Oklab _lch(double l, double c, double hDeg) {
  final h = hDeg * math.pi / 180;
  return Oklab(l, c * math.cos(h), c * math.sin(h));
}

/// Labio natural de calibration_grid.py (bare_face): L − 0,07, croma 0,075, 22°.
Oklab _naturalLip(double skinL) => _lch(skinL - 0.07, 0.075, 22);

Oklab _paint(Oklab base, ColorTarget t, double amount) => Oklab(
      base.l + (t.color.l - base.l) * t.lumaFollow * amount,
      base.a + (t.color.a - base.a) * amount,
      base.b + (t.color.b - base.b) * amount,
    );

/// Direcciones de ruido fijas (unitarias en OKLab).
final _noiseDirections = [
  for (final (l, a, b) in const [
    (1.0, 0.0, 0.0), (-1.0, 0.0, 0.0), (0.0, 1.0, 0.0), (0.0, -1.0, 0.0), (0.0, 0.0, 1.0), (0.0, 0.0, -1.0),
    (0.577, 0.577, 0.577), (-0.577, 0.577, -0.577), (0.577, -0.577, 0.577), (-0.577, -0.577, -0.577),
  ])
    (l, a, b),
];

double _contrast(Oklab base, ColorTarget t) {
  final dl = (t.color.l - base.l) * t.lumaFollow;
  final da = t.color.a - base.a;
  final db = t.color.b - base.b;
  return math.sqrt(dl * dl + da * da + db * db);
}

void main() {
  test('el look bien aplicado da "bien" en todos los tonos, con el ruido de la cámara', () {
    final failures = <String>[];
    for (final preset in RecipePresets.all) {
      final target = CoachTarget.from(preset.recipe);
      for (final tone in _tones) {
        final skin = _lch(tone.$1, tone.$2, tone.$3);
        for (final MapEntry(key: zone, value: wanted) in target.colors.entries) {
          final base = zone == CoachZone.lips ? _naturalLip(tone.$1) : skin;
          final applied = _paint(base, wanted, wanted.opacity);
          for (final (l, a, b) in _noiseDirections) {
            final n = CoachPolicy.measurementNoise;
            final observed = Oklab(applied.l + l * n, applied.a + a * n, applied.b + b * n);
            final verdict = CoachEvaluator.colorVerdict(base, observed, wanted);
            if (verdict != CoachVerdict.ok) {
              failures.add('${preset.id}/${zone.name}/L${tone.$1}: $verdict (contraste '
                  '${_contrast(base, wanted).toStringAsFixed(3)})');
            }
          }
        }
      }
    }
    expect(failures, isEmpty, reason: failures.take(12).join('\n'));
  });

  test('sin maquillaje dice "falta" cuando el look se distingue del natural', () {
    final failures = <String>[];
    var checked = 0;
    for (final preset in RecipePresets.all) {
      final target = CoachTarget.from(preset.recipe);
      for (final tone in _tones) {
        final skin = _lch(tone.$1, tone.$2, tone.$3);
        for (final MapEntry(key: zone, value: wanted) in target.colors.entries) {
          final base = zone == CoachZone.lips ? _naturalLip(tone.$1) : skin;
          // Lo que el look le suma al natural tiene que verse más que el ruido.
          final visible = _contrast(base, wanted) * wanted.opacity;
          if (visible < 2 * CoachPolicy.measurementNoise) continue;
          checked++;
          final verdict = CoachEvaluator.colorVerdict(base, base, wanted);
          if (verdict != CoachVerdict.tooLittle) {
            failures.add('${preset.id}/${zone.name}/L${tone.$1}: $verdict');
          }
        }
      }
    }
    expect(checked, greaterThan(40));
    expect(failures, isEmpty, reason: failures.take(12).join('\n'));
  });
}

import 'package:flutter_test/flutter_test.dart';

import 'package:ar_makeup_app/features/ar/domain/makeup_recipe.dart';
import 'package:ar_makeup_app/features/coach/domain/coach.dart';
import 'package:ar_makeup_app/features/coach/domain/coach_policy.dart';
import 'package:ar_makeup_app/features/studio/domain/image_look.dart';
import 'package:ar_makeup_app/features/studio/domain/oklab.dart';

const _skin = Oklab(0.72, 0.035, 0.05);
const _naturalLip = Oklab(0.62, 0.08, 0.05);
const _red = RecipeColor(0xB3122D);

LookRegion _region(Oklab color, {double coverage = 0.9}) => LookRegion(valid: true, color: color, coverage: coverage);

/// Lo que el motor pinta con [color] a [amount] sobre [base] (mismo modelo).
Oklab _paint(Oklab base, RecipeColor color, double amount, {double lumaFollow = 1}) {
  final c = Oklab.fromColor(color);
  return Oklab(
    base.l + (c.l - base.l) * lumaFollow * amount,
    base.a + (c.a - base.a) * amount,
    base.b + (c.b - base.b) * amount,
  );
}

LookMeasurements _measure({
  Oklab? lips,
  Oklab? cheeks,
  Map<ShadowRegion, Oklab> shadows = const {},
  double linerExtent = 0,
  double wingExtent = 0,
  double eyeDistancePx = 220,
  PhotoLookStatus status = PhotoLookStatus.ok,
  double lipsCoverage = 0.9,
}) =>
    LookMeasurements(
      status: status,
      eyeDistancePx: eyeDistancePx,
      skin: _region(_skin),
      lips: lips == null ? LookRegion.missing : _region(lips, coverage: lipsCoverage),
      cheeks: cheeks == null ? LookRegion.missing : _region(cheeks),
      cheekSkin: _region(_skin),
      eyeSkin: _region(_skin),
      eyeRegions: [
        for (final region in ShadowRegion.values)
          shadows[region] == null ? _region(_skin) : _region(shadows[region] ?? _skin),
      ],
      liner: linerExtent > 0 ? _region(const Oklab(0.2, 0, 0)) : LookRegion.missing,
      linerExtent: linerExtent,
      wingExtent: wingExtent,
    );

final _baseline = LookMeasurements(status: PhotoLookStatus.ok, skin: _region(_skin), lips: _region(_naturalLip));

MakeupRecipe _lipsRecipe({double opacity = 0.8}) =>
    MakeupRecipe(name: 'Rojo', lips: LipsSpec(color: _red, opacity: opacity, lumaFollow: 1));

void main() {
  group('CoachTarget', () {
    test('toma las zonas de la receta en orden de aplicación', () {
      final recipe = MakeupRecipe(
        name: 'Completo',
        lips: LipsSpec(color: _red, opacity: 0.8, liner: const ColorLayer(color: RecipeColor(0x6E0A1A), opacity: 0.7)),
        cheeks: const CheeksSpec(color: RecipeColor(0xE07A7A), opacity: 0.4),
        eyes: EyesSpec(
          shadow: const [
            EyeShadowLayer(color: RecipeColor(0x8A5A7A), opacity: 0.6, region: ShadowRegion.lid),
            EyeShadowLayer(color: RecipeColor(0x4A3050), opacity: 0.02, region: ShadowRegion.outerV),
          ],
          liner: const EyeLinerSpec(color: RecipeColor(0x111111), opacity: 0.9, thickness: 0.4, wing: 0.6),
        ),
      );
      final target = CoachTarget.from(recipe);
      // La sombra con opacidad 0,02 no se revisa: casi no se ve.
      expect(target.zones, [CoachZone.shadowLid, CoachZone.eyeLiner, CoachZone.cheeks, CoachZone.lipLiner, CoachZone.lips]);
      expect(target.colors[CoachZone.lips]?.lumaFollow, CoachTarget.defaultLipsLumaFollow);
      expect(target.liner?.wing, 0.6);
    });

    test('una receta sin capas revisables queda vacía', () {
      expect(CoachTarget.from(MakeupRecipe(name: 'Nada')).isEmpty, isTrue);
    });
  });

  group('CoachEvaluator: color', () {
    final target = CoachTarget.from(_lipsRecipe());

    CoachVerdict lips(Oklab observed, {bool withBaseline = true}) => CoachEvaluator.evaluateZone(
          CoachZone.lips,
          target,
          _measure(lips: observed),
          baseline: withBaseline ? _baseline : null,
        );

    test('sin labial falta, con la cantidad justa está bien y de más sobra', () {
      expect(lips(_naturalLip), CoachVerdict.tooLittle);
      expect(lips(_paint(_naturalLip, _red, 0.3)), CoachVerdict.tooLittle);
      expect(lips(_paint(_naturalLip, _red, 0.8)), CoachVerdict.ok);
      expect(lips(_paint(_naturalLip, _red, 0.95)), CoachVerdict.ok);
      expect(lips(_paint(_naturalLip, _red, 1.0)), CoachVerdict.ok);
    });

    test('con poca opacidad en la receta, cubrir todo es de más', () {
      final soft = CoachTarget.from(_lipsRecipe(opacity: 0.4));
      final verdict = CoachEvaluator.evaluateZone(
        CoachZone.lips,
        soft,
        _measure(lips: _paint(_naturalLip, _red, 0.9)),
        baseline: _baseline,
      );
      expect(verdict, CoachVerdict.tooMuch);
    });

    test('otro color: más oscuro, más claro u otro tono', () {
      final expected = _paint(_naturalLip, _red, 0.8);
      expect(lips(Oklab(expected.l - 0.15, expected.a, expected.b)), CoachVerdict.tooDark);
      expect(lips(Oklab(expected.l + 0.15, expected.a, expected.b)), CoachVerdict.tooLight);
      // Un labial violeta: misma luz, croma muy distinta.
      expect(lips(Oklab(expected.l, 0.05, -0.12)), CoachVerdict.otherTone);
    });

    test('sin referencia estima el labio natural desde la piel', () {
      final estimated = Oklab(_skin.l + CoachPolicy.naturalLipDeltaL, _skin.a + CoachPolicy.naturalLipDeltaA, _skin.b);
      expect(lips(_paint(estimated, _red, 0.8), withBaseline: false), CoachVerdict.ok);
      expect(lips(estimated, withBaseline: false), CoachVerdict.tooLittle);
    });

    test('una zona que no se ve no opina', () {
      final verdict = CoachEvaluator.evaluateZone(
        CoachZone.lips,
        target,
        _measure(lips: _naturalLip, lipsCoverage: 0.1),
        baseline: _baseline,
      );
      expect(verdict, CoachVerdict.notVisible);
    });

    test('rubor y sombras usan la piel con la misma luz', () {
      final recipe = MakeupRecipe(
        name: 'Rubor y párpado',
        cheeks: const CheeksSpec(color: RecipeColor(0xE07A7A), opacity: 0.5),
        eyes: EyesSpec(shadow: const [
          EyeShadowLayer(color: RecipeColor(0x6A3A7A), opacity: 0.7, region: ShadowRegion.lid),
        ]),
      );
      final t = CoachTarget.from(recipe);
      final good = _measure(
        cheeks: _paint(_skin, const RecipeColor(0xE07A7A), 0.5),
        shadows: {ShadowRegion.lid: _paint(_skin, const RecipeColor(0x6A3A7A), 0.7)},
      );
      expect(CoachEvaluator.evaluate(t, good), {CoachZone.shadowLid: CoachVerdict.ok, CoachZone.cheeks: CoachVerdict.ok});
      final heavy = _measure(
        cheeks: _paint(_skin, const RecipeColor(0xE07A7A), 1.0),
        shadows: {ShadowRegion.lid: _skin},
      );
      expect(CoachEvaluator.evaluate(t, heavy),
          {CoachZone.shadowLid: CoachVerdict.tooLittle, CoachZone.cheeks: CoachVerdict.tooMuch});
    });
  });

  group('CoachEvaluator: delineado', () {
    final target = CoachTarget.from(MakeupRecipe(
      name: 'Delineado',
      eyes: EyesSpec(liner: const EyeLinerSpec(color: RecipeColor(0x111111), opacity: 0.9, thickness: 0.4, wing: 0.6)),
    ));

    // Extensión medida para un grosor de receta (inverso del de ImageRecipeBuilder).
    double extentFor(double thickness) => 0.12 + 0.08 / 2 + thickness * (0.6 - 0.12);

    CoachVerdict liner({required double thickness, required double wing, double eyes = 220, bool none = false}) =>
        CoachEvaluator.evaluateZone(
          CoachZone.eyeLiner,
          target,
          _measure(linerExtent: none ? 0 : extentFor(thickness), wingExtent: wing, eyeDistancePx: eyes),
        );

    test('grosor y cola como el look', () {
      expect(liner(thickness: 0.4, wing: 0.6), CoachVerdict.ok);
    });

    test('sin delineado falta; fino, grueso, cola corta y larga', () {
      expect(liner(thickness: 0, wing: 0, none: true), CoachVerdict.tooLittle);
      expect(liner(thickness: 0.1, wing: 0.6), CoachVerdict.tooThin);
      expect(liner(thickness: 0.8, wing: 0.6), CoachVerdict.tooThick);
      expect(liner(thickness: 0.4, wing: 0.2), CoachVerdict.wingShort);
      expect(liner(thickness: 0.4, wing: 0.95), CoachVerdict.wingLong);
    });

    test('con la cara lejos no se juzga el delineado', () {
      expect(liner(thickness: 0.4, wing: 0.6, eyes: 100), CoachVerdict.tooFar);
    });

    test('un look sin cola marca la cola de más', () {
      final noWing = CoachTarget.from(MakeupRecipe(
        name: 'Fino',
        eyes: EyesSpec(liner: const EyeLinerSpec(color: RecipeColor(0x111111), opacity: 0.9, thickness: 0.3)),
      ));
      final verdict = CoachEvaluator.evaluateZone(
        CoachZone.eyeLiner,
        noWing,
        _measure(linerExtent: extentFor(0.3), wingExtent: 0.7),
      );
      expect(verdict, CoachVerdict.wingLong);
    });
  });

  group('CoachSession', () {
    Duration s(int seconds) => Duration(seconds: seconds);

    test('la primera lectura vale; después hacen falta dos iguales para cambiar', () {
      final session = CoachSession(CoachTarget.from(_lipsRecipe()))..baseline = _baseline;
      expect(session.add(_measure(lips: _naturalLip), s(0)), const CoachPrompt.zone(CoachZone.lips, CoachVerdict.tooLittle));
      // Una lectura buena suelta (ruido) no alcanza.
      expect(session.add(_measure(lips: _paint(_naturalLip, _red, 0.8)), s(1)), isNull);
      expect(session.verdicts[CoachZone.lips], CoachVerdict.tooLittle);
      // La segunda confirma: listo.
      expect(session.add(_measure(lips: _paint(_naturalLip, _red, 0.8)), s(2)), const CoachPrompt.done());
      expect(session.done, isTrue);
      // "Listo" no se repite.
      expect(session.add(_measure(lips: _paint(_naturalLip, _red, 0.8)), s(20)), isNull);
    });

    test('foco en la primera zona sin terminar y repetición espaciada', () {
      final recipe = MakeupRecipe(
        name: 'Ojos y labios',
        lips: LipsSpec(color: _red, opacity: 0.8, lumaFollow: 1),
        eyes: EyesSpec(shadow: const [
          EyeShadowLayer(color: RecipeColor(0x6A3A7A), opacity: 0.7, region: ShadowRegion.lid),
        ]),
      );
      final session = CoachSession(CoachTarget.from(recipe))..baseline = _baseline;
      final bare = _measure(lips: _naturalLip);
      expect(session.add(bare, s(0)), const CoachPrompt.zone(CoachZone.shadowLid, CoachVerdict.tooLittle));
      expect(session.add(bare, s(3)), isNull);
      expect(session.add(bare, s(6)), const CoachPrompt.zone(CoachZone.shadowLid, CoachVerdict.tooLittle));
      expect(session.focus, CoachZone.shadowLid);
    });

    test('sin cara o lejos avisa y no toca los veredictos', () {
      final session = CoachSession(CoachTarget.from(_lipsRecipe()))..baseline = _baseline;
      session.add(_measure(lips: _paint(_naturalLip, _red, 0.8)), s(0));
      expect(session.add(_measure(status: PhotoLookStatus.noFace), s(1)), const CoachPrompt.issue(CoachIssue.lookAtCamera));
      expect(session.add(_measure(status: PhotoLookStatus.faceTooSmall), s(2)), const CoachPrompt.issue(CoachIssue.comeCloser));
      expect(session.add(_measure(status: PhotoLookStatus.badImage), s(3)), const CoachPrompt.issue(CoachIssue.moreLight));
      expect(session.verdicts[CoachZone.lips], CoachVerdict.ok);
    });

    test('la referencia promedia las muestras que salieron bien', () {
      final session = CoachSession(CoachTarget.from(_lipsRecipe()));
      final ok = session.setBaseline([
        LookMeasurements(status: PhotoLookStatus.ok, skin: _region(_skin), lips: _region(const Oklab(0.60, 0.08, 0.05))),
        const LookMeasurements(status: PhotoLookStatus.noFace),
        LookMeasurements(status: PhotoLookStatus.ok, skin: _region(_skin), lips: _region(const Oklab(0.64, 0.08, 0.05))),
      ]);
      expect(ok, isTrue);
      expect(session.baseline?.lips.color.l, closeTo(0.62, 1e-9));
      expect(session.setBaseline(const [LookMeasurements(status: PhotoLookStatus.profile)]), isFalse);
    });
  });
}

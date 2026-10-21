import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ar_makeup_app/features/ar/domain/makeup_recipe.dart';
import 'package:ar_makeup_app/features/ar/presentation/test_filter_view.dart';
import 'package:ar_makeup_app/features/coach/domain/coach.dart';
import 'package:ar_makeup_app/features/coach/presentation/coach_screen.dart';
import 'package:ar_makeup_app/features/studio/domain/image_look.dart';
import 'package:ar_makeup_app/features/studio/domain/oklab.dart';
import 'package:ar_makeup_app/l10n/app_localizations.dart';

import '../../ar/presentation/test_filter_view_test.dart' show FakeRenderer;

const _skin = Oklab(0.72, 0.035, 0.05);
const _naturalLip = Oklab(0.62, 0.08, 0.05);
const _red = RecipeColor(0xB3122D);

LookRegion _region(Oklab color) => LookRegion(valid: true, color: color, coverage: 0.9);

LookMeasurements _face(Oklab lips) => LookMeasurements(
      status: PhotoLookStatus.ok,
      eyeDistancePx: 220,
      skin: _region(_skin),
      lips: _region(lips),
    );

Oklab _painted(double amount) {
  final c = Oklab.fromColor(_red);
  return Oklab(
    _naturalLip.l + (c.l - _naturalLip.l) * amount,
    _naturalLip.a + (c.a - _naturalLip.a) * amount,
    _naturalLip.b + (c.b - _naturalLip.b) * amount,
  );
}

final class _FakeSampler implements ICoachSampler {
  _FakeSampler(this.results);

  final List<LookMeasurements> results;
  int calls = 0;

  @override
  Future<LookMeasurements> sample() async {
    final result = results[calls < results.length ? calls : results.length - 1];
    calls++;
    return result;
  }
}

final class _FakeVoice implements ICoachVoice {
  final List<String> spoken = [];
  int stops = 0;
  int releases = 0;
  bool available = true;

  @override
  Future<bool> speak(String text, {required String locale}) async {
    spoken.add(text);
    return available;
  }

  @override
  Future<void> stop() async => stops++;

  @override
  Future<void> release() async => releases++;
}

TestFilterOption _look({MakeupRecipe? recipe}) => TestFilterOption(
      id: 'look-1',
      label: 'Rojo',
      recipe: recipe ?? MakeupRecipe(name: 'Rojo', lips: const LipsSpec(color: _red, opacity: 0.8, lumaFollow: 1)),
    );

Widget _app(Widget home) => MaterialApp(
      locale: const Locale('es'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    );

/// Varias vueltas del loop async (muestra -> evaluar -> setState -> voz).
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump();
  }
}

/// Desmonta la pantalla: cancela el timer de muestras.
Future<void> _close(WidgetTester tester) => tester.pumpWidget(const SizedBox());

void main() {
  testWidgets('saltear: mide, dice qué falta y la cámara muestra la cara sin maquillaje', (tester) async {
    final renderer = FakeRenderer();
    final sampler = _FakeSampler([_face(_naturalLip)]);
    final voice = _FakeVoice();
    await tester.pumpWidget(_app(CoachScreen(look: _look(), renderer: renderer, sampler: sampler, voice: voice)));
    await _settle(tester);
    expect(find.text('Antes de empezar'), findsOneWidget);
    expect(sampler.calls, 0);

    await tester.tap(find.byKey(const ValueKey('coach-skip')));
    await _settle(tester);
    expect(sampler.calls, 1);
    const expected = 'Labios: falta color, sumá un poco más.';
    expect(find.text(expected), findsOneWidget);
    expect(voice.spoken, [expected]);
    expect(find.byKey(const ValueKey('coach-zone-lips')), findsOneWidget);
    // La cámara no pinta el look: la cara real.
    expect(renderer.recipes.every((r) => r == null), isTrue);
    // Sin FPS ni comparar en la guía.
    expect(find.textContaining('fps'), findsNothing);

    // La muestra siguiente llega con el timer; la misma indicación no se repite enseguida.
    await tester.pump(const Duration(milliseconds: 1500));
    await _settle(tester);
    expect(sampler.calls, 2);
    expect(voice.spoken, hasLength(1));

    await _close(tester);
    expect(voice.releases, 1);
  });

  testWidgets('con referencia: mide la cara lavada y después el labial bien puesto da "listo"', (tester) async {
    final sampler = _FakeSampler([
      _face(_naturalLip),
      _face(_naturalLip),
      _face(_painted(0.8)),
    ]);
    final voice = _FakeVoice();
    await tester.pumpWidget(_app(CoachScreen(look: _look(), renderer: FakeRenderer(), sampler: sampler, voice: voice)));
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('coach-reference')));
    await _settle(tester);
    expect(sampler.calls, greaterThanOrEqualTo(3));
    expect(find.text('¡Listo! Tu maquillaje coincide con el look.'), findsOneWidget);
    expect(voice.spoken.last, '¡Listo! Tu maquillaje coincide con el look.');
    await _close(tester);
  });

  testWidgets('vibra cuando una zona queda bien y al terminar', (tester) async {
    final haptics = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') haptics.add(call.arguments as String);
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    final sampler = _FakeSampler([_face(_naturalLip), _face(_painted(0.8)), _face(_painted(0.8))]);
    await tester.pumpWidget(_app(CoachScreen(look: _look(), renderer: FakeRenderer(), sampler: sampler, voice: _FakeVoice())));
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('coach-skip')));
    await _settle(tester);
    expect(haptics, isEmpty);
    for (var i = 0; i < 2; i++) {
      await tester.pump(const Duration(milliseconds: 1500));
      await _settle(tester);
    }
    // Una sola zona: al quedar bien, terminó (la vibración de "listo").
    expect(haptics, ['HapticFeedbackType.mediumImpact']);
    await _close(tester);
  });

  testWidgets('silenciar corta la voz y no habla más', (tester) async {
    final sampler = _FakeSampler([_face(_naturalLip), const LookMeasurements(status: PhotoLookStatus.faceTooSmall)]);
    final voice = _FakeVoice();
    await tester.pumpWidget(_app(CoachScreen(look: _look(), renderer: FakeRenderer(), sampler: sampler, voice: voice)));
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('coach-skip')));
    await _settle(tester);
    expect(voice.spoken, hasLength(1));
    await tester.tap(find.byKey(const ValueKey('coach-mute')));
    await tester.pump();
    expect(voice.stops, greaterThanOrEqualTo(1));
    await tester.pump(const Duration(milliseconds: 1500));
    await _settle(tester);
    // Cambió la indicación (acercate) pero está silenciada: solo en pantalla.
    expect(find.text('Acercate un poco a la cámara.'), findsOneWidget);
    expect(voice.spoken, hasLength(1));
    await _close(tester);
  });

  testWidgets('sin voz para el idioma avisa una vez', (tester) async {
    final voice = _FakeVoice()..available = false;
    await tester.pumpWidget(_app(CoachScreen(
      look: _look(),
      renderer: FakeRenderer(),
      sampler: _FakeSampler([_face(_naturalLip)]),
      voice: voice,
    )));
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('coach-skip')));
    await _settle(tester);
    expect(find.textContaining('no tiene voz para este idioma'), findsOneWidget);
    await _close(tester);
  });

  testWidgets('mantener "ver el look" pinta el look y al soltar vuelve la cara real', (tester) async {
    final renderer = FakeRenderer();
    await tester.pumpWidget(_app(CoachScreen(
      look: _look(),
      renderer: renderer,
      sampler: _FakeSampler([_face(_naturalLip)]),
      voice: _FakeVoice(),
    )));
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('coach-skip')));
    await _settle(tester);
    final gesture = await tester.startGesture(tester.getCenter(find.byKey(const ValueKey('coach-show-target'))));
    await _settle(tester);
    expect(renderer.recipes.last?.lips?.color.toHex(), '#B3122D');
    await gesture.up();
    await _settle(tester);
    expect(renderer.recipes.last, isNull);
    expect(renderer.starts, 1, reason: 'mostrar el look no reabre la cámara');
    await _close(tester);
  });

  testWidgets('sin motor AR: lo avisa y no mide', (tester) async {
    final sampler = _FakeSampler([_face(_naturalLip)]);
    await tester.pumpWidget(_app(CoachScreen(
      look: _look(),
      renderer: FakeRenderer(available: false),
      sampler: sampler,
      voice: _FakeVoice(),
    )));
    await _settle(tester);
    expect(find.byKey(const ValueKey('coach-skip')), findsNothing);
    await tester.pump(const Duration(seconds: 3));
    expect(sampler.calls, 0);
    expect(find.textContaining('no está disponible'), findsWidgets);
    await _close(tester);
  });

  testWidgets('un look sin zonas revisables lo dice y no mide', (tester) async {
    final sampler = _FakeSampler([_face(_naturalLip)]);
    await tester.pumpWidget(_app(CoachScreen(
      look: _look(recipe: MakeupRecipe(name: 'Vacío')),
      renderer: FakeRenderer(),
      sampler: sampler,
      voice: _FakeVoice(),
    )));
    await _settle(tester);
    expect(find.text('Este look no tiene zonas que la guía pueda revisar.'), findsOneWidget);
    expect(find.byKey(const ValueKey('coach-skip')), findsNothing);
    expect(sampler.calls, 0);
    await _close(tester);
  });
}

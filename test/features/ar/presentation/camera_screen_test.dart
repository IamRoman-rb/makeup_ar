import 'package:ar_makeup_app/features/ar/domain/i_makeup_renderer.dart';
import 'package:ar_makeup_app/features/ar/domain/makeup_recipe.dart';
import 'package:ar_makeup_app/features/ar/domain/recipe_presets.dart';
import 'package:ar_makeup_app/features/ar/presentation/camera_screen.dart';
import 'package:ar_makeup_app/features/ar/presentation/test_filter_view.dart';
import 'package:ar_makeup_app/features/coach/domain/coach.dart';
import 'package:ar_makeup_app/features/coach/presentation/coach_screen.dart';
import 'package:ar_makeup_app/features/studio/domain/image_look.dart';
import 'package:ar_makeup_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_filter_view_test.dart' show FakeRenderer;

/// El motor nativo admite una sola sesión: un start con otra abierta falla
/// ("already_started").
final class _SingleSessionEngine {
  bool open = false;
}

final class _ExclusiveRenderer implements IMakeupRenderer {
  _ExclusiveRenderer(this.engine);

  final _SingleSessionEngine engine;
  int stops = 0;
  int rejected = 0;

  @override
  String? get unavailableReason => rejected > 0 ? 'already_started' : null;

  @override
  Future<MakeupSurface?> start() async {
    if (engine.open) {
      rejected++;
      return null;
    }
    engine.open = true;
    return const MakeupSurface(textureId: 3, width: 720, height: 1280);
  }

  @override
  Future<void> stop() async {
    stops++;
    engine.open = false;
  }

  @override
  Future<void> applyRecipe(MakeupRecipe? recipe) async {}

  @override
  Future<void> setShowLandmarks(bool show) async {}

  @override
  Future<void> setLightAdaptation(bool enabled) async {}

  @override
  Future<void> setTrackingEnabled(bool enabled) async {}

  @override
  Future<MakeupRendererStats> stats() async => MakeupRendererStats.empty;
}

final class _NoFaceSampler implements ICoachSampler {
  @override
  Future<LookMeasurements> sample() async => const LookMeasurements(status: PhotoLookStatus.noFace);
}

final class _SilentVoice implements ICoachVoice {
  @override
  Future<bool> speak(String text, {required String locale}) async => true;

  @override
  Future<void> stop() async {}

  @override
  Future<void> release() async {}
}

Widget _app(Widget home) => MaterialApp(
      locale: const Locale('es'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    );

void main() {
  final look = TestFilterOption(id: 'look-abc', label: 'Rojo de noche', recipe: RecipePresets.byId('classic_red').recipe);

  testWidgets('Espejo de la barra: solo cámara, sin filtros ni tutorial', (tester) async {
    final renderer = FakeRenderer();
    await tester.pumpWidget(_app(CameraScreen(renderer: renderer)));
    await tester.pumpAndSettle();
    expect(renderer.starts, 1);
    expect(renderer.tracking, [false]);
    expect(renderer.recipes.every((r) => r == null), isTrue);
    expect(find.descendant(of: find.byType(AppBar), matching: find.text('Espejo')), findsOneWidget);
    expect(find.text('Rojo clásico'), findsNothing);
    expect(find.byType(Slider), findsNothing);
    expect(find.byKey(const ValueKey('camera-open-tutorial')), findsNothing);
  });

  testWidgets('con un look: ese look puesto, sin los demás filtros', (tester) async {
    final renderer = FakeRenderer();
    await tester.pumpWidget(_app(CameraScreen(renderer: renderer, initialLook: look)));
    await tester.pumpAndSettle();
    expect(renderer.tracking.where((t) => !t), isEmpty, reason: 'el tracker no se apaga');
    expect(renderer.recipes.last?.lips?.color.toHex(), '#B3122D');
    expect(find.text('Rojo de noche'), findsOneWidget);  // título
    expect(find.text('Rojo clásico'), findsNothing);
    expect(find.text('Sin filtro'), findsNothing);
    expect(find.byType(Slider), findsOneWidget);
    expect(find.text('Mantené para comparar'), findsOneWidget);
    // Sin callback, sin botón de tutorial (por ejemplo, desde "Mis looks").
    expect(find.byKey(const ValueKey('camera-open-tutorial')), findsNothing);
  });

  testWidgets('"Ver tutorial" llama al callback', (tester) async {
    var opened = 0;
    await tester.pumpWidget(_app(CameraScreen(renderer: FakeRenderer(), initialLook: look, onOpenTutorial: () => opened++)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('camera-open-tutorial')));
    expect(opened, 1);
    expect(find.text('Ver tutorial'), findsOneWidget);
  });

  testWidgets('"Guíame" suelta la cámara antes de abrir la guía', (tester) async {
    // Como el motor real: una sola sesión a la vez.
    final engine = _SingleSessionEngine();
    final mirror = _ExclusiveRenderer(engine);
    final coach = _ExclusiveRenderer(engine);
    await tester.pumpWidget(_app(Builder(
      builder: (context) => CameraScreen(
        renderer: mirror,
        initialLook: look,
        onOpenCoach: () => Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
          builder: (_) => CoachScreen(look: look, renderer: coach, sampler: _NoFaceSampler(), voice: _SilentVoice()),
        )),
      ),
    )));
    await tester.pumpAndSettle();
    expect(engine.open, isTrue);

    await tester.tap(find.byKey(const ValueKey('camera-open-coach')));
    await tester.pumpAndSettle();
    expect(mirror.stops, 1);
    expect(coach.rejected, 0, reason: 'el motor no estaba ocupado al arrancar la guía');
    expect(find.byKey(const ValueKey('coach-skip')), findsOneWidget, reason: 'la guía en vivo, no los pasos sin cámara');
    expect(find.text('Pasos del look'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('"Guíame" sobre la cámara solo con un look y su callback', (tester) async {
    var opened = 0;
    await tester.pumpWidget(_app(CameraScreen(renderer: FakeRenderer(), initialLook: look, onOpenCoach: () => opened++)));
    await tester.pumpAndSettle();
    expect(find.text('Guíame'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('camera-open-coach')));
    expect(opened, 0, reason: 'primero se suelta la cámara');
    await tester.pump();
    expect(opened, 1);
    // Un segundo toque mientras se abre no la abre dos veces.
    expect(find.byKey(const ValueKey('camera-open-coach')), findsNothing);

    await tester.pumpWidget(_app(CameraScreen(renderer: FakeRenderer(), initialLook: look)));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('camera-open-coach')), findsNothing);
  });

  testWidgets('"Guíame" y comparar comparten la fila de abajo sin taparse ni tapar el slider (E20, es y fr)',
      (tester) async {
    tester.view.physicalSize = const Size(720, 1600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    for (final locale in const [Locale('es'), Locale('fr')]) {
      await tester.pumpWidget(MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: CameraScreen(renderer: FakeRenderer(), initialLook: look, onOpenCoach: () {}),
      ));
      await tester.pumpAndSettle();
      final coach = tester.getRect(find.byKey(const ValueKey('camera-open-coach')));
      final compare = tester.getRect(find.byKey(const ValueKey('filter-compare')));
      final slider = tester.getRect(find.byType(Slider));
      expect(coach.right, lessThan(compare.left), reason: '$locale');
      expect(compare.right, lessThanOrEqualTo(360));
      expect(compare.bottom, lessThanOrEqualTo(slider.top));
      expect(coach.bottom, lessThanOrEqualTo(slider.top));
      expect(tester.takeException(), isNull, reason: 'sin overflow');
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('sin "Guíame", comparar queda solo abajo a la derecha', (tester) async {
    await tester.pumpWidget(_app(CameraScreen(renderer: FakeRenderer(), initialLook: look)));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('camera-open-coach')), findsNothing);
    final compare = tester.getRect(find.byKey(const ValueKey('filter-compare')));
    final view = tester.getRect(find.byType(TestFilterView));
    expect(view.right - compare.right, closeTo(12, 0.5));
    expect(compare.bottom, lessThanOrEqualTo(tester.getRect(find.byType(Slider)).top));
  });

  testWidgets('sin motor: espejo de respaldo', (tester) async {
    final renderer = FakeRenderer(available: false);
    await tester.pumpWidget(_app(CameraScreen(renderer: renderer)));
    // El respaldo abre CameraController (en el test no hay cámara: queda el
    // spinner animado), así que no se puede esperar a que todo se asiente.
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(TestFilterView), findsNothing);
    expect(renderer.starts, 1);
  });
}

import 'package:ar_makeup_app/features/ar/domain/recipe_presets.dart';
import 'package:ar_makeup_app/features/ar/presentation/camera_screen.dart';
import 'package:ar_makeup_app/features/ar/presentation/test_filter_view.dart';
import 'package:ar_makeup_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_filter_view_test.dart' show FakeRenderer;

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

  testWidgets('"Guíame" sobre la cámara solo con un look y su callback', (tester) async {
    var opened = 0;
    await tester.pumpWidget(_app(CameraScreen(renderer: FakeRenderer(), initialLook: look, onOpenCoach: () => opened++)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('camera-open-coach')));
    expect(opened, 1);
    expect(find.text('Guíame'), findsOneWidget);

    await tester.pumpWidget(_app(CameraScreen(renderer: FakeRenderer(), initialLook: look)));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('camera-open-coach')), findsNothing);
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

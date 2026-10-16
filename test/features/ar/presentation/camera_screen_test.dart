import 'package:ar_makeup_app/features/ar/presentation/camera_screen.dart';
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
  testWidgets('Espejo y filtro comparten la sesión del motor: alternar no reabre la cámara', (tester) async {
    final renderer = FakeRenderer();
    await tester.pumpWidget(_app(CameraScreen(renderer: renderer)));
    await tester.pumpAndSettle();
    expect(renderer.starts, 1);
    expect(renderer.tracking, [false]);

    final toggle = find.byKey(const ValueKey('camera-filter-toggle'));
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(renderer.tracking.last, isTrue);
    expect(renderer.recipes.last, isNotNull);

    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(renderer.tracking.last, isFalse);
    expect(renderer.recipes.last, isNull);
    expect(renderer.starts, 1);
    expect(renderer.stops, 0);
  });

  testWidgets('sin motor: espejo de respaldo, sin botón de filtro', (tester) async {
    final renderer = FakeRenderer(available: false);
    await tester.pumpWidget(_app(CameraScreen(renderer: renderer)));
    // El respaldo abre CameraController (en el test no hay cámara: queda el
    // spinner animado), así que no se puede esperar a que todo se asiente.
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const ValueKey('camera-filter-toggle')), findsNothing);
    expect(renderer.starts, 1);
  });
}

import 'package:ar_makeup_app/features/ar/presentation/camera_permission_gate.dart';
import 'package:ar_makeup_app/features/ar/presentation/test_filter_view.dart';
import 'package:ar_makeup_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_filter_view_test.dart' show FakeRenderer;

final class _FakePermission implements ICameraPermission {
  _FakePermission(this.current);

  /// Lo que contesta el diálogo del sistema.
  static const CameraAccess onRequest = CameraAccess.granted;

  CameraAccess current;
  int requests = 0;
  int settings = 0;

  @override
  Future<CameraAccess> status() async => current;

  @override
  Future<CameraAccess> request() async {
    requests++;
    return current = onRequest;
  }

  @override
  Future<bool> openSettings() async {
    settings++;
    return true;
  }
}

const _labels = TestFilterLabels(
  noFilter: 'Sin filtro',
  intensity: 'Intensidad',
  note: 'nota',
  showPoints: 'Ver puntos',
  compare: 'Comparar',
  matte: 'Mate',
  satin: 'Satinado',
  gloss: 'Brillo',
  shimmer: 'Shimmer',
  zoneAll: 'Todo',
  zoneLips: 'Labios',
  zoneEyes: 'Ojos',
  zoneCheeks: 'Mejillas',
  zoneSkin: 'Piel',
  unavailable: 'No disponible',
);

Widget _app(FakeRenderer renderer, ICameraPermission permission) => MaterialApp(
      locale: const Locale('es'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: TestFilterView(labels: _labels, renderer: renderer, cameraPermission: permission)),
    );

/// La vista muestra un spinner mientras no hay cámara: pumpAndSettle no
/// terminaría nunca. Alcanza con dejar correr las animaciones del diálogo.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUp(CameraPermissionSession.reset);

  testWidgets('explica antes del diálogo del sistema y, con permiso, abre la cámara', (tester) async {
    final renderer = FakeRenderer();
    final permission = _FakePermission(CameraAccess.denied);
    await tester.pumpWidget(_app(renderer, permission));
    await _settle(tester);
    expect(find.text('Acceso a la cámara'), findsOneWidget);
    expect(renderer.starts, 0);
    await tester.tap(find.text('Continuar'));
    await _settle(tester);
    expect(permission.requests, 1);
    expect(renderer.starts, 1);
  });

  testWidgets('"Ahora no": no pide, no abre la cámara y no vuelve a insistir sola', (tester) async {
    final renderer = FakeRenderer();
    final permission = _FakePermission(CameraAccess.denied);
    await tester.pumpWidget(_app(renderer, permission));
    await _settle(tester);
    await tester.tap(find.text('Ahora no'));
    await _settle(tester);
    expect(permission.requests, 0);
    expect(renderer.starts, 0);
    expect(find.text('Permitir cámara'), findsOneWidget);
    expect(CameraPermissionSession.declined, isTrue);

    // Otra vista (como al volver de segundo plano): sin explicación de nuevo.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(_app(FakeRenderer(), permission));
    await _settle(tester);
    expect(find.text('Acceso a la cámara'), findsNothing);
    expect(find.text('Permitir cámara'), findsOneWidget);

    // El botón es un pedido de la persona: va directo al diálogo del sistema.
    await tester.tap(find.text('Permitir cámara'));
    await _settle(tester);
    expect(permission.requests, 1);
  });

  testWidgets('denegado para siempre: ofrece abrir los ajustes', (tester) async {
    final renderer = FakeRenderer();
    final permission = _FakePermission(CameraAccess.permanentlyDenied);
    await tester.pumpWidget(_app(renderer, permission));
    await _settle(tester);
    expect(renderer.starts, 0);
    await tester.tap(find.text('Abrir ajustes'));
    await tester.pump();
    expect(permission.settings, 1);
  });

  testWidgets('con el permiso ya dado no pregunta nada', (tester) async {
    final renderer = FakeRenderer();
    final permission = _FakePermission(CameraAccess.granted);
    await tester.pumpWidget(_app(renderer, permission));
    await _settle(tester);
    expect(find.byType(AlertDialog), findsNothing);
    expect(renderer.starts, 1);
  });
}

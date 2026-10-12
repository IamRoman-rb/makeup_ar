import 'package:ar_makeup_app/features/ar/domain/makeup_recipe.dart';
import 'package:ar_makeup_app/features/ar/domain/recipe_presets.dart';
import 'package:ar_makeup_app/features/ar/presentation/test_filter_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:makeup_engine/makeup_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('makeup_engine');
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      switch (call.method) {
        case 'start':
          return {'textureId': 3, 'width': 720, 'height': 1280, 'glInfo': 'test'};
        case 'getStats':
          return {'frames': 30.0, 'intervalP50Ms': 33.3};
        default:
          return null;
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  Widget app() => const MaterialApp(
        home: Scaffold(
          body: TestFilterView(
            labels: TestFilterLabels(
              noFilter: 'Sin filtro',
              intensity: 'Intensidad',
              note: 'nota',
              lipsOnly: 'Solo labios',
              showPoints: 'Ver puntos',
              compare: 'Comparar',
              matte: 'Mate',
              satin: 'Satinado',
              gloss: 'Brillo',
              shimmer: 'Shimmer',
            ),
          ),
        ),
      );

  List<Map<Object?, Object?>> recipeCalls() => calls
      .where((c) => c.method == 'setRecipe')
      .map((c) => (c.arguments as Map<Object?, Object?>)['recipe'] as Map<Object?, Object?>)
      .toList();

  List<Map<Object?, Object?>> tintCalls() =>
      calls.where((c) => c.method == 'setTint').map((c) => c.arguments as Map<Object?, Object?>).toList();

  test('las opciones son "sin filtro" + los presets, con su color', () {
    final options = TestFilterOption.fromPresets('Sin filtro');
    expect(options.first.color, isNull);
    expect(options.length, RecipePresets.all.length + 1);
    expect(options.skip(1).every((o) => o.color != null), isTrue);
    final red = options.firstWhere((o) => o.id == 'classic_red');
    expect(red.color?.toHex(), '#B3122D');
  });

  testWidgets('inicia el motor y manda el labial del primer preset', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(calls.first.method, 'start');
    expect(find.byType(Texture), findsOneWidget);
    final lips = recipeCalls().last['lips'] as Map<Object?, Object?>;
    final natural = RecipePresets.all.first.recipe.lips;
    expect(lips['color'], natural?.color.toHex());
    expect(lips['opacity'], natural?.opacity);
    expect(lips['finish'], natural?.finish?.wireName);
  });

  testWidgets('acabado, comparar y "sin filtro" en modo labios', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Rojo clásico'));
    await tester.pumpAndSettle();
    expect((recipeCalls().last['lips'] as Map)['color'], '#B3122D');

    await tester.tap(find.text('Brillo'));
    await tester.pumpAndSettle();
    expect((recipeCalls().last['lips'] as Map)['finish'], 'gloss');

    final gesture = await tester.startGesture(tester.getCenter(find.text('Comparar')));
    await tester.pumpAndSettle();
    expect((recipeCalls().last['lips'] as Map)['opacity'], 0.0);
    await gesture.up();
    await tester.pumpAndSettle();
    expect((recipeCalls().last['lips'] as Map)['opacity'], 0.85);

    await tester.tap(find.text('Sin filtro'));
    await tester.pumpAndSettle();
    expect(recipeCalls().last.containsKey('lips'), isFalse);
    expect(find.byType(Slider), findsNothing);
  });

  testWidgets('sin "solo labios" usa el tinte de pantalla completa', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Solo labios'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rojo clásico'));
    await tester.pumpAndSettle();
    final red = tintCalls().last;
    expect(red['r'], closeTo(0xB3 / 255, 1e-9));
    expect(red['amount'], closeTo(0.45, 1e-9));
  });

  test('lipsRecipe cambia opacidad y acabado y conserva el resto', () {
    final red = TestFilterOption.fromPresets('x').firstWhere((o) => o.id == 'classic_red');
    final json = lipsRecipe(red, opacity: 0.5, finish: LipFinish.matte);
    final lips = json['lips'] as Map<String, Object?>;
    expect(lips['opacity'], 0.5);
    expect(lips['finish'], 'matte');
    expect(lips['lumaFollow'], 0.9);
    expect(json['name'], 'Rojo clásico');
    expect(lipsRecipe(TestFilterOption.fromPresets('x').first, opacity: 1).containsKey('lips'), isFalse);
  });

  List<Map<Object?, Object?>> optionCalls() =>
      calls.where((c) => c.method == 'setRenderOptions').map((c) => c.arguments as Map<Object?, Object?>).toList();

  testWidgets('arranca en "solo labios" sin puntos y los chips cambian las opciones', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(optionCalls().last, {'showLandmarks': false, 'region': TintRegion.lips.index});

    await tester.tap(find.text('Ver puntos'));
    await tester.pumpAndSettle();
    expect(optionCalls().last, {'showLandmarks': true, 'region': TintRegion.lips.index});

    await tester.tap(find.text('Solo labios'));
    await tester.pumpAndSettle();
    expect(optionCalls().last, {'showLandmarks': true, 'region': TintRegion.full.index});
  });

  test('etiqueta del tracker según su estado', () {
    expect(trackerLabel(TrackerStats.empty, requested: false), 'Tracker: apagado');
    expect(trackerLabel(TrackerStats.empty, requested: true), 'Tracker: cargando modelos…');
    expect(trackerLabel(const TrackerStats(backend: 'detector=gpu'), requested: true), 'Tracker: iniciando…');
    expect(trackerLabel(const TrackerStats(state: TrackerState.searching), requested: true), 'Tracker: buscando cara…');
    expect(
      trackerLabel(const TrackerStats(state: TrackerState.tracking, intervalP50Ms: 50, landmarkP50Ms: 17.2), requested: true),
      'Tracker: 20 Hz · 17 ms',
    );
  });

  testWidgets('detiene el motor al desmontarse', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pumpAndSettle();
    expect(calls.last.method, 'stop');
  });

  testWidgets('muestra el error si el motor no puede iniciar', (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'start') throw PlatformException(code: 'gl_init_failed', message: 'sin GLES 3');
      return null;
    });
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.textContaining('gl_init_failed'), findsOneWidget);
    expect(find.byType(Texture), findsNothing);
  });

  testWidgets('un pedido rechazado por el motor se descarta sin romper la vista', (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      switch (call.method) {
        case 'start':
          return {'textureId': 3, 'width': 720, 'height': 1280, 'glInfo': 'test'};
        case 'setRecipe':
        case 'setRenderOptions':
          throw PlatformException(code: 'not_running', message: 'motor detenido');
        default:
          return null;
      }
    });
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rojo clásico'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ver puntos'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(Texture), findsOneWidget);
    expect(calls.where((c) => c.method == 'setRecipe').length, greaterThanOrEqualTo(2));
  });
}

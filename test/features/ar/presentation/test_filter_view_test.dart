import 'package:ar_makeup_app/features/ar/domain/recipe_presets.dart';
import 'package:ar_makeup_app/features/ar/presentation/test_filter_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

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
          body: TestFilterView(noFilterLabel: 'Sin filtro', intensityLabel: 'Intensidad', note: 'nota'),
        ),
      );

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

  testWidgets('inicia el motor, muestra la textura y aplica el primer preset', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(calls.first.method, 'start');
    expect(find.byType(Texture), findsOneWidget);
    final first = tintCalls().last;
    final natural = RecipePresets.all.first.recipe.lips?.color;
    expect(natural, isNotNull);
    expect(first['r'], closeTo((natural?.red ?? 0) / 255, 1e-9));
    expect(first['amount'], closeTo(0.45, 1e-9));
  });

  testWidgets('elegir un preset manda su color y "sin filtro" apaga el tinte', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Rojo clásico'));
    await tester.pumpAndSettle();
    final red = tintCalls().last;
    expect(red['r'], closeTo(0xB3 / 255, 1e-9));
    expect(red['g'], closeTo(0x12 / 255, 1e-9));
    expect(red['b'], closeTo(0x2D / 255, 1e-9));

    await tester.tap(find.text('Sin filtro'));
    await tester.pumpAndSettle();
    expect(tintCalls().last['amount'], 0.0);
    expect(find.byType(Slider), findsNothing);
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
}

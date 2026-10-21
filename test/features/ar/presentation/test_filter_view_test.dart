import 'package:ar_makeup_app/features/ar/domain/i_makeup_renderer.dart';
import 'package:ar_makeup_app/features/ar/domain/makeup_recipe.dart';
import 'package:ar_makeup_app/features/ar/domain/recipe_adjustments.dart';
import 'package:ar_makeup_app/features/ar/domain/recipe_presets.dart';
import 'package:ar_makeup_app/features/ar/presentation/test_filter_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Renderer de prueba: registra lo que recibe la vista.
final class FakeRenderer implements IMakeupRenderer {
  FakeRenderer({this.available = true});

  final bool available;
  final List<MakeupRecipe?> recipes = [];
  final List<bool> landmarks = [];
  final List<bool> lightAdaptation = [];
  final List<bool> tracking = [];
  int starts = 0;
  int stops = 0;

  @override
  String? get unavailableReason => available ? null : 'prueba';

  @override
  Future<MakeupSurface?> start() async {
    starts++;
    return available ? const MakeupSurface(textureId: 3, width: 720, height: 1280) : null;
  }

  @override
  Future<void> applyRecipe(MakeupRecipe? recipe) async => recipes.add(recipe);

  @override
  Future<void> setShowLandmarks(bool show) async => landmarks.add(show);

  @override
  Future<void> setLightAdaptation(bool enabled) async => lightAdaptation.add(enabled);

  @override
  Future<void> setTrackingEnabled(bool enabled) async => tracking.add(enabled);

  int statsCalls = 0;

  @override
  Future<MakeupRendererStats> stats() async {
    statsCalls++;
    return const MakeupRendererStats(renderFps: 28, tracking: FaceTrackingState.tracking, trackerHz: 14, landmarkMs: 21);
  }

  @override
  Future<void> stop() async => stops++;
}

void main() {
  const labels = TestFilterLabels(
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

  Widget app(IMakeupRenderer renderer, {VoidCallback? onUnavailable}) => MaterialApp(
        home: Scaffold(body: TestFilterView(labels: labels, renderer: renderer, onUnavailable: onUnavailable)),
      );

  Widget mirrorApp(IMakeupRenderer renderer, {required bool mirrorOnly}) => MaterialApp(
        home: Scaffold(body: TestFilterView(labels: labels, renderer: renderer, mirrorOnly: mirrorOnly)),
      );

  testWidgets('Espejo: sin tracker desde antes de abrir la cámara, sin receta ni controles', (tester) async {
    final renderer = FakeRenderer();
    await tester.pumpWidget(mirrorApp(renderer, mirrorOnly: true));
    await tester.pumpAndSettle();

    expect(renderer.starts, 1);
    expect(renderer.tracking, [false]);
    expect(renderer.recipes, isNotEmpty);
    expect(renderer.recipes.every((r) => r == null), isTrue);
    expect(find.byType(Texture), findsOneWidget);
    expect(find.text('Comparar'), findsNothing);
    expect(find.text('Intensidad'), findsNothing);
    await tester.pump(const Duration(seconds: 2));
    expect(find.textContaining('fps'), findsNothing);
  });

  testWidgets('Espejo -> filtro -> Espejo: misma sesión, conserva el look elegido', (tester) async {
    final renderer = FakeRenderer();
    await tester.pumpWidget(mirrorApp(renderer, mirrorOnly: false));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rojo clásico'));
    await tester.pumpAndSettle();
    expect(renderer.recipes.last?.lips?.color.toHex(), '#B3122D');

    await tester.pumpWidget(mirrorApp(renderer, mirrorOnly: true));
    await tester.pumpAndSettle();
    expect(renderer.tracking.last, isFalse);
    expect(renderer.recipes.last, isNull);
    expect(find.text('Rojo clásico'), findsNothing);

    await tester.pumpWidget(mirrorApp(renderer, mirrorOnly: false));
    await tester.pumpAndSettle();
    expect(renderer.tracking.last, isTrue);
    expect(renderer.recipes.last?.lips?.color.toHex(), '#B3122D');
    expect(renderer.starts, 1, reason: 'alternar no reabre la cámara');
    expect(renderer.stops, 0);
  });

  testWidgets('controls: intensity muestra solo el slider, sin otros filtros ni zonas', (tester) async {
    final renderer = FakeRenderer();
    final red = RecipePresets.byId('classic_red').recipe;
    final look = TestFilterOption(id: 'look-1', label: 'Mi look', recipe: red);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TestFilterView(
          labels: labels,
          renderer: renderer,
          options: [look],
          initialOptionId: look.id,
          controls: TestFilterControls.intensity,
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(renderer.recipes.last?.lips?.color.toHex(), '#B3122D');
    expect(find.byType(Slider), findsOneWidget);
    expect(find.text('Comparar'), findsOneWidget);
    expect(find.text('Mi look'), findsNothing);
    expect(find.text('Sin filtro'), findsNothing);
    expect(find.text('Labios'), findsNothing);
    expect(find.text('Ver puntos'), findsNothing);
    expect(find.text('Mate'), findsNothing);

    // El slider sigue escalando el look.
    tester.widget<Slider>(find.byType(Slider)).onChanged?.call(0.5);
    await tester.pumpAndSettle();
    expect(renderer.recipes.last?.lips?.opacity, closeTo((red.lips?.opacity ?? 0) * 0.5, 1e-9));
  });

  testWidgets('controls: none no muestra controles abajo; comparar sigue', (tester) async {
    final renderer = FakeRenderer();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: TestFilterView(labels: labels, renderer: renderer, controls: TestFilterControls.none)),
    ));
    await tester.pumpAndSettle();
    expect(renderer.recipes.last, isNotNull);
    expect(find.byType(Slider), findsNothing);
    expect(find.text('Sin filtro'), findsNothing);
    expect(find.text('Labios'), findsNothing);
    expect(find.text('Comparar'), findsOneWidget);
  });

  testWidgets('showStats: false oculta el FPS y no pide métricas; comparar sigue', (tester) async {
    final renderer = FakeRenderer();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: TestFilterView(labels: labels, renderer: renderer, showStats: false)),
    ));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));
    expect(find.textContaining('fps'), findsNothing);
    expect(find.text('Comparar'), findsOneWidget);
    expect(renderer.statsCalls, 0);
  });

  test('las opciones son "sin filtro" + los presets, con su color', () {
    final options = TestFilterOption.fromPresets('Sin filtro');
    expect(options.first.color, isNull);
    expect(options.length, RecipePresets.all.length + 1);
    expect(options.skip(1).every((o) => o.color != null), isTrue);
    final red = options.firstWhere((o) => o.id == 'classic_red');
    expect(red.color?.toHex(), '#B3122D');
  });

  testWidgets('inicia el renderer y manda el primer preset completo', (tester) async {
    final renderer = FakeRenderer();
    await tester.pumpWidget(app(renderer));
    await tester.pumpAndSettle();

    expect(renderer.starts, 1);
    expect(find.byType(Texture), findsOneWidget);
    final natural = RecipePresets.all.first.recipe;
    final sent = renderer.recipes.last;
    expect(sent?.name, natural.name);
    expect(sent?.lips?.color.toHex(), natural.lips?.color.toHex());
    expect(sent?.cheeks?.opacity, natural.cheeks?.opacity);
    expect(sent?.eyes?.shadow?.length, natural.eyes?.shadow?.length);
    expect(find.textContaining('28 fps'), findsNothing);  // el timer de métricas todavía no corrió
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('28 fps'), findsOneWidget);
    expect(find.textContaining('14 Hz'), findsOneWidget);
    // Desmontar detiene el timer y el renderer.
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    expect(renderer.stops, 1);
  });

  testWidgets('zona, acabado, intensidad, comparar y "sin filtro"', (tester) async {
    final renderer = FakeRenderer();
    await tester.pumpWidget(app(renderer));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Rojo clásico'));
    await tester.pumpAndSettle();
    expect(renderer.recipes.last?.lips?.color.toHex(), '#B3122D');
    expect(renderer.recipes.last?.eyes?.liner, isNotNull);

    await tester.tap(find.text('Ojos'));
    await tester.pumpAndSettle();
    expect(renderer.recipes.last?.lips, isNull);
    expect(renderer.recipes.last?.eyes?.liner, isNotNull);
    expect(find.text('Brillo'), findsNothing);  // sin labios no hay acabado

    await tester.tap(find.text('Labios'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Brillo'));
    await tester.pumpAndSettle();
    expect(renderer.recipes.last?.lips?.finish, LipFinish.gloss);
    expect(renderer.recipes.last?.eyes, isNull);

    final slider = tester.widget<Slider>(find.byType(Slider));
    slider.onChanged?.call(0.5);
    await tester.pumpAndSettle();
    expect(renderer.recipes.last?.lips?.opacity, closeTo(0.85 * 0.5, 1e-9));

    final gesture = await tester.startGesture(tester.getCenter(find.text('Comparar')));
    await tester.pumpAndSettle();
    expect(renderer.recipes.last, isNull);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(renderer.recipes.last?.lips?.opacity, closeTo(0.425, 1e-9));

    await tester.tap(find.text('Sin filtro'));
    await tester.pumpAndSettle();
    expect(renderer.recipes.last, isNull);
    expect(find.byType(Slider), findsNothing);
  });

  testWidgets('"ver puntos" prende los landmarks', (tester) async {
    final renderer = FakeRenderer();
    await tester.pumpWidget(app(renderer));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ver puntos'));
    await tester.pumpAndSettle();
    expect(renderer.landmarks, [true]);
    await tester.tap(find.text('Ver puntos'));
    await tester.pumpAndSettle();
    expect(renderer.landmarks, [true, false]);
  });

  testWidgets('sin maquillaje disponible muestra el aviso y avisa a quien la monta', (tester) async {
    final renderer = FakeRenderer(available: false);
    var unavailable = 0;
    await tester.pumpWidget(app(renderer, onUnavailable: () => unavailable++));
    await tester.pumpAndSettle();
    expect(find.text('No disponible'), findsOneWidget);
    expect(find.byType(Texture), findsNothing);
    expect(unavailable, 1);
    expect(renderer.recipes, isEmpty);
  });

  testWidgets('las opciones extra van después de los presets', (tester) async {
    final renderer = FakeRenderer();
    final extra = TestFilterOption(id: 'x', label: 'Prueba', recipe: MakeupRecipe(name: 'Prueba'));
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: TestFilterView(labels: labels, renderer: renderer, extraOptions: [extra])),
    ));
    await tester.pumpAndSettle();
    // La lista de looks se construye a demanda: hay que desplazarla.
    final looks = find.ancestor(of: find.text('Natural'), matching: find.byType(Scrollable));
    await tester.scrollUntilVisible(find.text('Prueba'), 200, scrollable: looks.first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Prueba'));
    await tester.pumpAndSettle();
    expect(renderer.recipes.last?.name, 'Prueba');
  });

  testWidgets('el chip de luz adaptada solo aparece con su etiqueta y la apaga', (tester) async {
    final renderer = FakeRenderer();
    await tester.pumpWidget(app(renderer));
    await tester.pumpAndSettle();
    expect(find.text('Luz adaptada'), findsNothing);

    const withLight = TestFilterLabels(
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
      lightAdaptation: 'Luz adaptada',
    );
    final other = FakeRenderer();
    // Otra key: si no, Flutter reusa el State anterior (y su renderer).
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: TestFilterView(key: const ValueKey('luz'), labels: withLight, renderer: other)),
    ));
    await tester.pumpAndSettle();
    // La fila de chips se desplaza: se trae el chip a la vista antes de tocarlo.
    await tester.ensureVisible(find.text('Luz adaptada'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Luz adaptada'));
    await tester.pumpAndSettle();
    expect(other.lightAdaptation, [false]);
  });

  testWidgets('opciones propias: la edición en vivo se manda y la elección se conserva', (tester) async {
    final renderer = FakeRenderer();
    final red = RecipePresets.byId('classic_red').recipe;
    final selected = <String>[];
    Widget view(List<TestFilterOption> options) => MaterialApp(
          home: Scaffold(
            body: TestFilterView(
              labels: labels,
              renderer: renderer,
              options: options,
              initialOptionId: 'b',
              onOptionSelected: (option) => selected.add(option.id),
            ),
          ),
        );
    final a = TestFilterOption(id: 'a', label: 'A', recipe: MakeupRecipe(name: 'A', lips: red.lips));
    final b = TestFilterOption(id: 'b', label: 'B', recipe: MakeupRecipe(name: 'B', lips: red.lips));
    await tester.pumpWidget(view([a, b]));
    await tester.pumpAndSettle();
    expect(renderer.recipes.last?.name, 'B');  // initialOptionId
    expect(find.text('Rojo clásico'), findsNothing);  // sin presets

    // La opción elegida cambió de receta (edición): se vuelve a mandar.
    final edited = TestFilterOption(id: 'b', label: 'B2', recipe: MakeupRecipe(name: 'B2', lips: red.lips));
    await tester.pumpWidget(view([a, edited]));
    await tester.pumpAndSettle();
    expect(renderer.recipes.last?.name, 'B2');

    await tester.tap(find.text('A'));
    await tester.pumpAndSettle();
    expect(selected, ['a']);
    expect(renderer.recipes.last?.name, 'A');
    // Si la elegida desaparece, vuelve a initialOptionId.
    await tester.pumpWidget(view([edited]));
    await tester.pumpAndSettle();
    expect(renderer.recipes.last?.name, 'B2');
  });

  test('etiqueta del tracker según su estado', () {
    expect(trackerLabel(MakeupRendererStats.empty), 'Tracker: iniciando…');
    expect(trackerLabel(const MakeupRendererStats(tracking: FaceTrackingState.loading)), 'Tracker: cargando modelos…');
    expect(trackerLabel(const MakeupRendererStats(tracking: FaceTrackingState.searching)), 'Tracker: buscando cara…');
    expect(
      trackerLabel(const MakeupRendererStats(tracking: FaceTrackingState.tracking, trackerHz: 14.6, landmarkMs: 21.2)),
      'Tracker: 15 Hz · 21 ms',
    );
  });

  test('las zonas tienen etiqueta', () {
    expect(MakeupZone.values.map(labels.zone).toSet().length, MakeupZone.values.length);
  });
}


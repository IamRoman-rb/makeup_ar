import 'package:ar_makeup_app/features/ar/domain/i_makeup_renderer.dart';
import 'package:ar_makeup_app/features/ar/domain/makeup_recipe.dart';
import 'package:ar_makeup_app/features/ar/domain/recipe_presets.dart';
import 'package:ar_makeup_app/features/studio/domain/image_look.dart';
import 'package:ar_makeup_app/features/studio/domain/oklab.dart';
import 'package:ar_makeup_app/features/studio/domain/recipe_generator.dart';
import 'package:ar_makeup_app/features/studio/domain/studio_look.dart';
import 'package:ar_makeup_app/features/studio/presentation/studio_screen.dart';
import 'package:ar_makeup_app/l10n/app_localizations.dart';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final class FakeRenderer implements IMakeupRenderer {
  final List<MakeupRecipe?> recipes = [];

  @override
  String? get unavailableReason => null;

  @override
  Future<MakeupSurface?> start() async => const MakeupSurface(textureId: 1, width: 720, height: 1280);

  @override
  Future<void> applyRecipe(MakeupRecipe? recipe) async => recipes.add(recipe);

  @override
  Future<void> setShowLandmarks(bool show) async {}

  @override
  Future<void> setLightAdaptation(bool enabled) async {}

  @override
  Future<void> setTrackingEnabled(bool enabled) async {}

  @override
  Future<MakeupRendererStats> stats() async => MakeupRendererStats.empty;

  @override
  Future<void> stop() async {}
}

final class FakeGenerator implements IRecipeGenerator {
  FakeGenerator(this.result);

  GenerationResult result;
  final List<String> prompts = [];
  final List<String> locales = [];
  MakeupRecipe? remixBase;

  @override
  Future<GenerationResult> generate({required String prompt, required String locale}) async {
    prompts.add(prompt);
    locales.add(locale);
    return result;
  }

  @override
  Future<GenerationResult> remix({required MakeupRecipe base, required String instruction, required String locale}) async {
    remixBase = base;
    prompts.add(instruction);
    return result;
  }
}

final class MemoryRepository implements ILookRepository {
  final Map<String, StudioLook> savedDrafts = {};
  final List<StudioLook> published = [];
  var _next = 0;

  @override
  Future<String> saveDraft(StudioLook look) async {
    final id = look.id ?? 'd${_next++}';
    savedDrafts[id] = look.copyWith(id: id);
    return id;
  }

  @override
  Future<List<StudioLook>> drafts() async => savedDrafts.values.toList();

  @override
  Future<void> deleteDraft(String id) async => savedDrafts.remove(id);

  @override
  Future<String> publish(StudioLook look) async {
    published.add(look);
    final id = look.id;
    if (id != null) savedDrafts.remove(id);
    return 'look${published.length}';
  }
}

final class FakeAnalyzer implements IImageLookAnalyzer {
  FakeAnalyzer(this.measurements, {this.swatches = const []});

  LookMeasurements measurements;
  List<ProductSwatch> swatches;
  int faceCalls = 0;

  @override
  Future<LookMeasurements> analyzeFace(Uint8List bytes) async {
    faceCalls++;
    return measurements;
  }

  @override
  Future<List<ProductSwatch>> palette(Uint8List bytes) async => swatches;
}

LookRegion region(Oklab color, {double gloss = 0}) => LookRegion(valid: true, color: color, gloss: gloss, coverage: 1);

/// Receta con los labios de un preset y otro nombre.
MakeupRecipe named(String preset, String name) => MakeupRecipe(name: name, lips: RecipePresets.byId(preset).recipe.lips);

void main() {
  Future<void> pumpStudio(WidgetTester tester, FakeGenerator generator, MemoryRepository repository,
      FakeRenderer renderer, {IImageLookAnalyzer? analyzer}) async {
    tester.view.physicalSize = const Size(900, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('es'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: StudioScreen(
        generator: generator,
        repository: repository,
        renderer: renderer,
        imageAnalyzer: analyzer,
        pickImage: () async => Uint8List.fromList([1, 2, 3]),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('genera, elige, edita, guarda y publica', (tester) async {
    final variants = [named('classic_red', 'Rojo fiel'), named('gothic', 'Rojo intenso'), named('natural', 'Rojo sutil')];
    final generator = FakeGenerator(GenerationResult(variants: variants, model: 'gemini-3.5-flash'));
    final repository = MemoryRepository();
    final renderer = FakeRenderer();
    await pumpStudio(tester, generator, repository, renderer);

    expect(find.text('Escribí un pedido y tocá Generar.'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'labios rojos');
    await tester.tap(find.text('Generar'));
    await tester.pumpAndSettle();
    expect(generator.prompts, ['labios rojos']);
    expect(generator.locales, ['es']);
    expect(renderer.recipes.last?.name, 'Rojo fiel');

    // Elegir la tercera variante: la vista previa y el editor la siguen.
    await tester.tap(find.text('Rojo sutil').first);
    await tester.pumpAndSettle();
    expect(renderer.recipes.last?.name, 'Rojo sutil');

    // Editar la opacidad del labial: llega en vivo al renderer.
    final slider = tester.widget<Slider>(find.byKey(const ValueKey('amount-lips')));
    slider.onChanged?.call(0.3);
    await tester.pumpAndSettle();
    expect(renderer.recipes.last?.name, 'Rojo sutil');
    expect(renderer.recipes.last?.lips?.opacity, closeTo(0.3, 1e-9));

    await tester.tap(find.text('Guardar borrador'));
    await tester.pumpAndSettle();
    expect(repository.savedDrafts.values.single.name, 'Rojo sutil');
    expect(repository.savedDrafts.values.single.sourcePrompt, 'labios rojos');
    expect(repository.savedDrafts.values.single.model, 'gemini-3.5-flash');

    await tester.tap(find.widgetWithText(FilledButton, 'Publicar'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Nombre'), 'Rojo de noche');
    await tester.tap(find.widgetWithText(FilledButton, 'Publicar').last);
    await tester.pumpAndSettle();
    final look = repository.published.single;
    expect(look.name, 'Rojo de noche');
    expect(look.category, LookCategory.lips);
    expect(look.recipe.lips?.opacity, closeTo(0.3, 1e-9));
    expect(look.id, isNotNull);  // venía de un borrador: se borra al publicar
    expect(repository.savedDrafts, isEmpty);
  });

  testWidgets('sin variantes: preset de respaldo y el motivo', (tester) async {
    final fallback = RecipePresets.byId('gothic').recipe;
    final generator = FakeGenerator(
      GenerationResult(variants: const [], failure: GenerationFailure.quotaExhausted, fallback: fallback),
    );
    final renderer = FakeRenderer();
    await pumpStudio(tester, generator, MemoryRepository(), renderer);
    await tester.enterText(find.byType(TextField).first, 'gótico');
    await tester.tap(find.text('Generar'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Se agotó la cuota'), findsOneWidget);
    expect(renderer.recipes.last?.name, fallback.name);
  });

  testWidgets('remix sobre la variante elegida', (tester) async {
    final first = named('classic_red', 'Rojo');
    final generator = FakeGenerator(GenerationResult(variants: [first]));
    await pumpStudio(tester, generator, MemoryRepository(), FakeRenderer());
    await tester.enterText(find.byType(TextField).first, 'rojo');
    await tester.tap(find.text('Generar'));
    await tester.pumpAndSettle();
    generator.result = GenerationResult(variants: [named('natural', 'Rojo natural')]);
    await tester.enterText(find.widgetWithText(TextField, 'Ajuste (ej.: más natural, tonos más cálidos)'), 'más natural');
    await tester.tap(find.text('Remix'));
    await tester.pumpAndSettle();
    expect(generator.remixBase?.name, 'Rojo');
    expect(find.text('Rojo natural'), findsWidgets);
  });

  testWidgets('desde foto: aviso, 3 variantes, confianza y origen image', (tester) async {
    final skin = Oklab.fromSrgb(0.8, 0.62, 0.52);
    final analyzer = FakeAnalyzer(LookMeasurements(
      status: PhotoLookStatus.ok,
      skin: region(skin),
      lips: region(Oklab.fromSrgb(0.7, 0.15, 0.22), gloss: 0.8),
    ));
    final renderer = FakeRenderer();
    final repository = MemoryRepository();
    await pumpStudio(tester, FakeGenerator(GenerationResult(variants: const [])), repository, renderer,
        analyzer: analyzer);

    await tester.tap(find.text('Desde foto'));
    await tester.pumpAndSettle();
    expect(find.textContaining('no se sube ni se guarda'), findsOneWidget);
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    expect(analyzer.faceCalls, 1);
    expect(renderer.recipes.last?.name, 'Foto · fiel');
    expect(find.text('Foto · intensa'), findsWidgets);
    expect(find.text('Labial: 100 %'), findsOneWidget);
    expect(renderer.recipes.last?.lips?.finish, LipFinish.gloss);

    // El aviso es una vez por pantalla.
    await tester.tap(find.text('Desde foto'));
    await tester.pumpAndSettle();
    expect(find.text('Continuar'), findsNothing);
    expect(analyzer.faceCalls, 2);

    await tester.tap(find.text('Guardar borrador'));
    await tester.pumpAndSettle();
    expect(repository.savedDrafts.values.single.sourceType, LookSourceType.image);
    expect(repository.savedDrafts.values.single.sourcePrompt, isNull);
  });

  testWidgets('desde foto: cara girada muestra el motivo', (tester) async {
    final analyzer = FakeAnalyzer(const LookMeasurements(status: PhotoLookStatus.profile));
    await pumpStudio(tester, FakeGenerator(GenerationResult(variants: const [])), MemoryRepository(), FakeRenderer(),
        analyzer: analyzer);
    await tester.tap(find.text('Desde foto'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    expect(find.textContaining('foto de frente'), findsOneWidget);
  });

  testWidgets('paleta de producto: color a una capa nueva', (tester) async {
    final plum = RecipeColor(0x7A3E8C);
    final analyzer = FakeAnalyzer(
      const LookMeasurements(status: PhotoLookStatus.ok),
      swatches: [ProductSwatch(color: plum, fraction: 0.7), ProductSwatch(color: RecipeColor(0xD08080), fraction: 0.3)],
    );
    final renderer = FakeRenderer();
    final generator = FakeGenerator(GenerationResult(variants: [named('classic_red', 'Rojo')]));
    await pumpStudio(tester, generator, MemoryRepository(), renderer, analyzer: analyzer);
    // Sin receta la paleta está deshabilitada.
    expect(tester.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Paleta de producto')).onPressed, isNull);
    await tester.enterText(find.byType(TextField).first, 'rojo');
    await tester.tap(find.text('Generar'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Paleta de producto'));
    await tester.pumpAndSettle();
    expect(find.text('70 %'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('swatch-#7A3E8C')));
    await tester.pumpAndSettle();
    expect(find.text('¿Dónde va este color?'), findsOneWidget);
    await tester.tap(find.text('Sombra nueva'));
    await tester.pumpAndSettle();
    final shadows = renderer.recipes.last?.eyes?.shadow ?? const [];
    expect(shadows.single.color, plum);
    expect(renderer.recipes.last?.lips, isNotNull);
  });

  testWidgets('QA: una capa invisible bloquea Publicar y se ve el motivo', (tester) async {
    final lips = RecipePresets.byId('classic_red').recipe.lips;
    expect(lips, isNotNull);
    if (lips == null) return;
    final invisible = MakeupRecipe(
      name: 'Casi nada',
      lips: LipsSpec(color: lips.color, opacity: 0.01, finish: lips.finish, gloss: lips.gloss, lumaFollow: lips.lumaFollow),
    );
    final repository = MemoryRepository();
    await pumpStudio(tester, FakeGenerator(GenerationResult(variants: [invisible])), repository, FakeRenderer());
    await tester.enterText(find.byType(TextField).first, 'casi nada');
    await tester.tap(find.text('Generar'));
    await tester.pumpAndSettle();

    expect(find.text('Control de calidad'), findsOneWidget);
    expect(find.text('Labial: no se nota en ninguna piel'), findsOneWidget);
    expect(find.text('Corregí lo marcado en rojo para publicar.'), findsOneWidget);
    final publish = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Publicar'));
    expect(publish.onPressed, isNull);
    // El borrador se guarda igual.
    await tester.tap(find.text('Guardar borrador'));
    await tester.pumpAndSettle();
    expect(repository.savedDrafts, hasLength(1));

    // Subir la opacidad: deja de fallar y se puede publicar.
    tester.widget<Slider>(find.byKey(const ValueKey('amount-lips'))).onChanged?.call(0.85);
    await tester.pumpAndSettle();
    expect(find.text('Corregí lo marcado en rojo para publicar.'), findsNothing);
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Publicar')).onPressed, isNotNull);
  });
}

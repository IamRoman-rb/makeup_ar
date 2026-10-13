import 'package:ar_makeup_app/features/ar/domain/i_makeup_renderer.dart';
import 'package:ar_makeup_app/features/ar/domain/makeup_recipe.dart';
import 'package:ar_makeup_app/features/ar/domain/recipe_presets.dart';
import 'package:ar_makeup_app/features/studio/domain/recipe_generator.dart';
import 'package:ar_makeup_app/features/studio/domain/studio_look.dart';
import 'package:ar_makeup_app/features/studio/presentation/studio_screen.dart';
import 'package:ar_makeup_app/l10n/app_localizations.dart';
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

/// Receta con los labios de un preset y otro nombre.
MakeupRecipe named(String preset, String name) => MakeupRecipe(name: name, lips: RecipePresets.byId(preset).recipe.lips);

void main() {
  Future<void> pumpStudio(WidgetTester tester, FakeGenerator generator, MemoryRepository repository,
      FakeRenderer renderer) async {
    tester.view.physicalSize = const Size(900, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('es'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: StudioScreen(generator: generator, repository: repository, renderer: renderer),
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
}

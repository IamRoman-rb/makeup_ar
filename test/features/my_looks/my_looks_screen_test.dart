import 'dart:async';

import 'package:ar_makeup_app/features/ar/domain/makeup_recipe.dart';
import 'package:ar_makeup_app/features/ar/domain/recipe_presets.dart';
import 'package:ar_makeup_app/features/my_looks/domain/ai_look.dart';
import 'package:ar_makeup_app/features/my_looks/presentation/my_looks_screen.dart';
import 'package:ar_makeup_app/features/studio/domain/recipe_generator.dart';
import 'package:ar_makeup_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final class FakeGenerator implements IRecipeGenerator {
  FakeGenerator(this.result);

  GenerationResult result;
  final List<String> prompts = [];

  @override
  Future<GenerationResult> generate({required String prompt, required String locale}) async {
    prompts.add(prompt);
    return result;
  }

  @override
  Future<GenerationResult> remix({required MakeupRecipe base, required String instruction, required String locale}) async =>
      result;
}

/// Repositorio en memoria que se comporta como el servidor: tope y stream.
final class MemoryAiLooks implements IAiLookRepository {
  MemoryAiLooks({this.max = AiLookLimits.maxSaved});

  final int max;
  final List<AiLook> looks = [];
  final _controller = StreamController<List<AiLook>>.broadcast();
  var _next = 0;

  @override
  Stream<List<AiLook>> watch() async* {
    yield List.of(looks);
    yield* _controller.stream;
  }

  @override
  Future<AiLookFailure?> save(MakeupRecipe recipe, {AiLookSource source = AiLookSource.prompt}) async {
    if (looks.length >= max) return AiLookFailure.full;
    looks.insert(0, AiLook(id: 'l${_next++}', recipe: recipe));
    _controller.add(List.of(looks));
    return null;
  }

  @override
  Future<AiLookFailure?> delete(String id) async {
    final before = looks.length;
    looks.removeWhere((l) => l.id == id);
    _controller.add(List.of(looks));
    return looks.length < before ? null : AiLookFailure.notFound;
  }
}

MakeupRecipe preset(String id) => RecipePresets.byId(id).recipe;

void main() {
  late FakeGenerator generator;
  late MemoryAiLooks repository;
  late List<MakeupRecipe> tried;

  Future<void> pump(WidgetTester tester) async {
    tried = [];
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('es'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MyLooksScreen(repository: repository, generator: generator, onTryOn: tried.add, locale: 'es'),
    ));
    await tester.pumpAndSettle();
  }

  setUp(() {
    generator = FakeGenerator(GenerationResult(variants: [preset('classic_red'), preset('fresh_pink')]));
    repository = MemoryAiLooks();
  });

  testWidgets('generar, probar y guardar una variante', (tester) async {
    await pump(tester);
    expect(find.text('Todavía no guardaste looks con IA.'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('ai-prompt')), 'labios rojos');
    await tester.tap(find.byKey(const ValueKey('ai-generate')));
    await tester.pumpAndSettle();
    expect(generator.prompts, ['labios rojos']);
    final red = preset('classic_red');
    expect(find.text(red.name), findsOneWidget);

    await tester.tap(find.text('Probar').first);
    expect(tried.single.name, red.name);

    await tester.tap(find.byTooltip('Guardar').first);
    await tester.pumpAndSettle();
    expect(repository.looks.single.recipe.name, red.name);
    expect(find.text('Guardado en tus looks'), findsOneWidget);
    expect(find.byKey(const ValueKey('saved-l0')), findsOneWidget);
  });

  testWidgets('sin variantes de la IA: sugiere el preset y avisa', (tester) async {
    generator.result = GenerationResult(
      variants: const [],
      failure: GenerationFailure.unavailable,
      fallback: preset('fresh_pink'),
    );
    await pump(tester);
    await tester.enterText(find.byKey(const ValueKey('ai-prompt')), 'algo rosado');
    await tester.tap(find.byKey(const ValueKey('ai-generate')));
    await tester.pumpAndSettle();
    expect(find.text('Sugerencia'), findsOneWidget);
    expect(find.text('La IA no respondió: te sugerimos un look parecido.'), findsOneWidget);
    expect(find.text(preset('fresh_pink').name), findsOneWidget);
  });

  testWidgets('cuota agotada: mensaje con el límite', (tester) async {
    generator.result = GenerationResult(variants: const [], failure: GenerationFailure.quotaExhausted);
    await pump(tester);
    await tester.enterText(find.byKey(const ValueKey('ai-prompt')), 'rojo');
    await tester.tap(find.byKey(const ValueKey('ai-generate')));
    await tester.pumpAndSettle();
    expect(find.textContaining('límite de ${AiLookLimits.dailyGenerations}'), findsOneWidget);
  });

  testWidgets('pedido vacío no llama a la IA', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const ValueKey('ai-generate')));
    await tester.pumpAndSettle();
    expect(generator.prompts, isEmpty);
    expect(find.byKey(const ValueKey('ai-message')), findsOneWidget);
  });

  testWidgets('tope de guardados: avisa', (tester) async {
    repository = MemoryAiLooks(max: 0);
    await pump(tester);
    await tester.enterText(find.byKey(const ValueKey('ai-prompt')), 'rojo');
    await tester.tap(find.byKey(const ValueKey('ai-generate')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Guardar').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('Borrá uno para guardar otro'), findsOneWidget);
  });

  testWidgets('guardados: tocar prueba en AR y borrar pide confirmación', (tester) async {
    await repository.save(preset('classic_red'));
    await pump(tester);
    await tester.tap(find.byKey(const ValueKey('saved-l0')));
    expect(tried.single.name, preset('classic_red').name);

    await tester.tap(find.byTooltip('Borrar'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Borrar'));
    await tester.pumpAndSettle();
    expect(repository.looks, isEmpty);
    expect(find.text('Todavía no guardaste looks con IA.'), findsOneWidget);
  });
}

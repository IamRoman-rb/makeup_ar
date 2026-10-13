import 'dart:async';

import 'package:ar_makeup_app/features/ar/domain/recipe_presets.dart';
import 'package:ar_makeup_app/features/studio/data/app_check_setup.dart';
import 'package:ar_makeup_app/features/studio/data/cloud_recipe_generator.dart';
import 'package:ar_makeup_app/features/studio/domain/recipe_generator.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> recipe(String name, {String color = '#B3122D'}) => {
      'schema': 'makeup-recipe/2',
      'name': name,
      'lips': {'color': color, 'opacity': 0.85},
    };

void main() {
  test('devuelve solo las variantes que validan en la app', () async {
    final sent = <Map<String, Object?>>[];
    final generator = CloudRecipeGenerator(callable: (payload) async {
      sent.add(payload);
      return {
        'variants': [
          recipe('Rojo'),
          {...recipe('Malo'), 'shader': 'x'},
          recipe('Nude', color: '#B07A6A'),
        ],
        'model': 'gemini-3.5-flash',
        'requestId': 'r1',
      };
    });
    final result = await generator.generate(prompt: 'labios rojos', locale: 'es');
    expect(sent.single, {'kind': 'prompt', 'prompt': 'labios rojos', 'locale': 'es'});
    expect(result.variants.map((r) => r.name), ['Rojo', 'Nude']);
    expect(result.discarded, 1);
    expect(result.failure, isNull);
    expect(result.fallback, isNull);
    expect(result.model, 'gemini-3.5-flash');
    expect(result.requestId, 'r1');
  });

  test('sin variantes válidas: preset local más cercano', () async {
    final generator = CloudRecipeGenerator(callable: (_) async => {'variants': <Object?>[]});
    final result = await generator.generate(prompt: 'labios góticos', locale: 'es');
    expect(result.hasVariants, isFalse);
    expect(result.failure, GenerationFailure.noValidVariants);
    expect(result.fallback?.name, RecipePresets.closestTo('labios góticos').recipe.name);
  });

  test('errores de la función: motivo y preset; respuesta rara sin romper', () async {
    for (final (code, failure) in [
      ('unauthenticated', GenerationFailure.unauthenticated),
      ('permission-denied', GenerationFailure.notAdmin),
      ('invalid-argument', GenerationFailure.invalidInput),
      ('resource-exhausted', GenerationFailure.quotaExhausted),
      ('unavailable', GenerationFailure.unavailable),
      ('deadline-exceeded', GenerationFailure.unavailable),
      ('failed-precondition', GenerationFailure.appCheck),
      ('internal', GenerationFailure.unknown),
    ]) {
      final generator = CloudRecipeGenerator(callable: (_) async => throw RecipeCallException(code));
      final result = await generator.generate(prompt: 'rojo', locale: 'es');
      expect(result.failure, failure, reason: code);
      expect(result.fallback, isNotNull, reason: code);
    }
    final timeout = CloudRecipeGenerator(callable: (_) async => throw TimeoutException('x'));
    expect((await timeout.generate(prompt: 'rojo', locale: 'es')).failure, GenerationFailure.unavailable);
    final weird = CloudRecipeGenerator(callable: (_) async => 'texto');
    expect((await weird.generate(prompt: 'rojo', locale: 'es')).failure, GenerationFailure.noValidVariants);
  });

  test('remix manda la receta base y no usa preset', () async {
    final sent = <Map<String, Object?>>[];
    final base = RecipePresets.byId('classic_red').recipe;
    final generator = CloudRecipeGenerator(callable: (payload) async {
      sent.add(payload);
      return {'variants': <Object?>[]};
    });
    final result = await generator.remix(base: base, instruction: 'más natural', locale: 'es');
    expect(sent.single['kind'], 'remix');
    expect(sent.single['prompt'], 'más natural');
    expect(sent.single['baseRecipe'], base.toJson());
    expect(result.fallback, isNull);
  });

  test('App Check: debug fuera de release, Play Integrity en release o por define', () {
    expect(appCheckProvider(mode: '', release: false), isA<AndroidDebugProvider>());
    expect(appCheckProvider(mode: '', release: true), isA<AndroidPlayIntegrityProvider>());
    expect(appCheckProvider(mode: 'debug', release: true), isA<AndroidDebugProvider>());
    expect(appCheckProvider(mode: 'playIntegrity', release: false), isA<AndroidPlayIntegrityProvider>());
  });
}

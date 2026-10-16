import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

import '../../ar/domain/makeup_recipe.dart';
import '../../ar/domain/recipe_validator.dart';
import '../domain/prompt_fallback.dart';
import '../domain/recipe_generator.dart';

/// Llamada a la callable: recibe el payload y devuelve `result.data`, o tira
/// [RecipeCallException]. Inyectable para los tests.
typedef RecipeCallable = Future<Object?> Function(Map<String, Object?> payload);

/// Error de la callable con su código (`unauthenticated`, `resource-exhausted`...).
final class RecipeCallException implements Exception {
  const RecipeCallException(this.code);

  final String code;

  @override
  String toString() => 'RecipeCallException($code)';
}

/// [IRecipeGenerator] sobre la Cloud Function `generateRecipe`.
///
/// Defensa en profundidad: el servidor ya valida con el esquema, pero cada
/// variante se vuelve a validar acá con [RecipeValidator] (estricto). Si no
/// queda ninguna, un prompt cae al respaldo local ([PromptFallback]: el preset
/// más cercano con los colores que pide el texto).
final class CloudRecipeGenerator implements IRecipeGenerator {
  CloudRecipeGenerator({RecipeCallable? callable}) : _callable = callable ?? _firebaseCallable();

  /// Región de la función (functions/src/index.ts).
  static const String region = 'us-central1';

  /// Más que el timeout del modelo en el servidor (15 s × 2 intentos).
  static const Duration timeout = Duration(seconds: 40);

  final RecipeCallable _callable;

  /// `--dart-define=FUNCTIONS_EMULATOR=host:puerto` usa el emulador local
  /// (con `adb reverse tcp:5001 tcp:5001`, host 127.0.0.1).
  static RecipeCallable _firebaseCallable() {
    final functions = FirebaseFunctions.instanceFor(region: region);
    const emulator = String.fromEnvironment('FUNCTIONS_EMULATOR');
    final separator = emulator.lastIndexOf(':');
    if (separator > 0) {
      final port = int.tryParse(emulator.substring(separator + 1));
      // Sin el mapeo automático a 10.0.2.2 (eso es solo para el emulador de
      // Android): en el teléfono, 127.0.0.1 llega a la PC por adb reverse.
      if (port != null) {
        functions.useFunctionsEmulator(emulator.substring(0, separator), port, automaticHostMapping: false);
      }
    }
    final callable = functions.httpsCallable('generateRecipe', options: HttpsCallableOptions(timeout: timeout));
    return (payload) async {
      try {
        return (await callable.call<Object?>(payload)).data;
      } on FirebaseFunctionsException catch (e) {
        throw RecipeCallException(e.code);
      }
    };
  }

  @override
  Future<GenerationResult> generate({required String prompt, required String locale}) =>
      _call({'kind': 'prompt', 'prompt': prompt, 'locale': locale}, fallbackFor: prompt);

  @override
  Future<GenerationResult> remix({required MakeupRecipe base, required String instruction, required String locale}) =>
      _call({'kind': 'remix', 'prompt': instruction, 'locale': locale, 'baseRecipe': base.toJson()});

  Future<GenerationResult> _call(Map<String, Object?> payload, {String? fallbackFor}) async {
    MakeupRecipe? fallback() => fallbackFor == null ? null : PromptFallback.recipeFor(fallbackFor);
    final Object? data;
    try {
      data = await _callable(payload);
    } on RecipeCallException catch (e) {
      debugPrint('generateRecipe: ${e.code}');
      return GenerationResult(variants: const [], failure: failureFor(e.code), fallback: fallback());
    } catch (e) {
      debugPrint('generateRecipe: $e');
      return GenerationResult(variants: const [], failure: GenerationFailure.unavailable, fallback: fallback());
    }
    final map = data is Map ? data : const {};
    final raw = map['variants'];
    final variants = <MakeupRecipe>[];
    var discarded = 0;
    if (raw is List) {
      for (final item in raw) {
        final recipe = const RecipeValidator().validate(item).recipe;
        if (recipe != null) {
          variants.add(recipe);
        } else {
          discarded++;
        }
      }
    }
    final model = map['model'];
    final requestId = map['requestId'];
    return GenerationResult(
      variants: variants,
      failure: variants.isEmpty ? GenerationFailure.noValidVariants : null,
      fallback: variants.isEmpty ? fallback() : null,
      discarded: discarded,
      model: model is String ? model : null,
      requestId: requestId is String ? requestId : null,
    );
  }

  /// Códigos de error de la callable (HttpsError en functions/src/generateRecipe.ts).
  @visibleForTesting
  static GenerationFailure failureFor(String code) => switch (code) {
        'unauthenticated' => GenerationFailure.unauthenticated,
        'permission-denied' => GenerationFailure.notAdmin,
        'invalid-argument' => GenerationFailure.invalidInput,
        'resource-exhausted' => GenerationFailure.quotaExhausted,
        'unavailable' || 'deadline-exceeded' => GenerationFailure.unavailable,
        // App Check sin token válido.
        'failed-precondition' => GenerationFailure.appCheck,
        _ => GenerationFailure.unknown,
      };
}

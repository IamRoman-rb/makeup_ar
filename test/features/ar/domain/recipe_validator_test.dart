import 'dart:convert';
import 'dart:io';

import 'package:ar_makeup_app/features/ar/domain/makeup_recipe.dart';
import 'package:ar_makeup_app/features/ar/domain/recipe_validator.dart';
import 'package:flutter_test/flutter_test.dart';

/// Casos compartidos con tools/studio/validate_recipe_cases.py (jsonschema).
List<Map<String, Object?>> _loadCases() {
  final file = File('test/fixtures/recipe_v2_cases.json');
  final decoded = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
  return (decoded['cases'] as List).cast<Map<String, Object?>>();
}

Map<String, Object?> _caseById(List<Map<String, Object?>> cases, String id) =>
    cases.firstWhere((c) => c['id'] == id);

void main() {
  final cases = _loadCases();
  const validator = RecipeValidator();

  group('paridad con recipe_v2.schema.json', () {
    for (final testCase in cases) {
      final id = testCase['id'];
      final expectedValid = testCase['valid'] == true;
      test('[${testCase['group']}] $id → ${expectedValid ? 'válida' : 'inválida'}', () {
        final result = validator.validate(testCase['recipe']);
        expect(result.isValid, expectedValid, reason: result.errors.join('\n'));
        if (expectedValid) {
          expect(result.errors, isEmpty);
        } else {
          expect(result.recipe, isNull);
          expect(result.errors, isNotEmpty);
        }
      });
    }
  });

  group('los 8 casos exactos del informe (§10.11)', () {
    test('son exactamente 1 válida y 7 inválidas', () {
      final informe = cases.where((c) => c['group'] == 'informe').toList();
      expect(informe, hasLength(8));
      expect(informe.where((c) => c['valid'] == true), hasLength(1));
    });

    final expectedErrorPaths = {
      'informe_opacidad_1_7': r'$.lips.opacity',
      'informe_color_rojo': r'$.lips.color',
      'informe_finish_metalico': r'$.lips.finish',
      'informe_propiedad_shader': r'$.shader',
      'informe_5_sombras': r'$.eyes.shadow',
      'informe_schema_v1': r'$.schema',
      'informe_nombre_vacio': r'$.name',
    };
    expectedErrorPaths.forEach((id, path) {
      test('$id se rechaza en $path', () {
        final result = validator.validate(_caseById(cases, id)['recipe']);
        expect(result.errors.map((e) => e.path), [path]);
      });
    });
  });

  group('MakeupRecipe', () {
    test('la receta válida se parsea con los tipos correctos', () {
      final recipe = validator.validate(_caseById(cases, 'informe_valida')['recipe']).recipe;
      expect(recipe, isNotNull);
      if (recipe == null) return;
      expect(recipe.schema, kMakeupRecipeSchemaV2);
      expect(recipe.name, 'Rojo clásico');
      expect(recipe.lips?.color, const RecipeColor(0xB3122D));
      expect(recipe.lips?.finish, LipFinish.gloss);
      expect(recipe.lips?.lumaFollow, 0.35);
      expect(recipe.eyes?.shadow?.map((s) => s.region), [ShadowRegion.lid, ShadowRegion.outerV]);
      expect(recipe.skin?.foundation?.coverage, 0.35);
      expect(recipe.effects, isNull);
    });

    test('toJson es idempotente y vuelve a validar igual', () {
      for (final testCase in cases.where((c) => c['valid'] == true)) {
        final first = validator.validate(testCase['recipe']).recipe;
        expect(first, isNotNull, reason: '${testCase['id']}');
        if (first == null) continue;
        final json = first.toJson();
        final second = validator.validate(jsonDecode(jsonEncode(json))).recipe;
        expect(second?.toJson(), json, reason: '${testCase['id']}');
      }
    });

    test('toJson normaliza los colores a mayúsculas', () {
      final recipe = validator.validate(_caseById(cases, 'color_minusculas')['recipe']).recipe;
      expect(recipe?.toJson()['lips'], containsPair('color', '#B3122D'));
    });

    test('las listas son inmodificables', () {
      final recipe = validator.validate(_caseById(cases, 'efectos_3')['recipe']).recipe;
      final effects = recipe?.effects;
      expect(effects, isNotNull);
      expect(() => effects?.add(const MakeupEffect(type: EffectType.sheen, intensity: 0.1)), throwsUnsupportedError);
      final shadow = recipe?.eyes?.shadow;
      expect(() => shadow?.clear(), throwsUnsupportedError);
    });
  });

  group('RecipeColor', () {
    test('parsea y serializa', () {
      expect(RecipeColor.tryParse('#00ff7F')?.toHex(), '#00FF7F');
      expect(RecipeColor.tryParse('#000000')?.rgb, 0);
      expect(const RecipeColor(0x0A0B0C).toHex(), '#0A0B0C');
      expect(const RecipeColor(0x123456).red, 0x12);
      expect(const RecipeColor(0x123456).green, 0x34);
      expect(const RecipeColor(0x123456).blue, 0x56);
    });

    test('rechaza formatos inválidos (incluido salto de línea final)', () {
      for (final hex in ['rojo', '#FFF', '#GGGGGG', 'FFFFFF', '#FFFFFF\n', ' #FFFFFF', '#FFFFFFFF']) {
        expect(RecipeColor.tryParse(hex), isNull, reason: hex);
      }
    });
  });

  group('modo clamp (entradas del editor)', () {
    const lenient = RecipeValidator(clampOutOfRange: true);

    test('recorta números fuera de rango y avisa', () {
      final result = lenient.validate(_caseById(cases, 'informe_opacidad_1_7')['recipe']);
      expect(result.isValid, isTrue);
      expect(result.recipe?.lips?.opacity, 1.0);
      expect(result.warnings.map((w) => w.path), [r'$.lips.opacity']);
    });

    test('recorta negativos a 0', () {
      final result = lenient.validate(_caseById(cases, 'opacidad_negativa')['recipe']);
      expect(result.recipe?.lips?.opacity, 0.0);
    });

    test('sigue rechazando todo lo que no sea un rango', () {
      for (final id in ['informe_color_rojo', 'informe_finish_metalico', 'informe_propiedad_shader', 'opacidad_texto', 'informe_5_sombras']) {
        expect(lenient.validate(_caseById(cases, id)['recipe']).isValid, isFalse, reason: id);
      }
    });

    test('el modo estricto no produce warnings', () {
      final result = validator.validate(_caseById(cases, 'informe_valida')['recipe']);
      expect(result.warnings, isEmpty);
    });
  });

  group('validateJsonString (respuesta cruda de un LLM)', () {
    test('acepta un JSON válido', () {
      final source = jsonEncode(_caseById(cases, 'informe_valida')['recipe']);
      expect(validator.validateJsonString(source).isValid, isTrue);
    });

    test('rechaza JSON mal formado sin lanzar', () {
      final result = validator.validateJsonString('{"schema": "makeup-recipe/2", ');
      expect(result.isValid, isFalse);
      expect(result.errors.single.path, r'$');
    });

    test('rechaza texto alrededor del JSON (markdown)', () {
      final source = '```json\n${jsonEncode(_caseById(cases, 'informe_valida')['recipe'])}\n```';
      expect(validator.validateJsonString(source).isValid, isFalse);
    });

    test('rechaza entradas demasiado grandes antes de decodificar', () {
      final huge = '{"name": "${'a' * RecipeValidator.maxJsonLength}"}';
      final result = validator.validateJsonString(huge);
      expect(result.isValid, isFalse);
      expect(result.errors.single.message, contains('demasiado grande'));
    });
  });

  test('acepta mapas de Firestore con tipos dinámicos', () {
    final dynamicMap = <dynamic, dynamic>{
      'schema': 'makeup-recipe/2',
      'name': 'Desde Firestore',
      'lips': <dynamic, dynamic>{'color': '#AA0000', 'opacity': 1},
    };
    final result = validator.validate(dynamicMap);
    expect(result.isValid, isTrue, reason: result.errors.join('\n'));
    expect(result.recipe?.lips?.opacity, 1.0);
  });

  test('reporta todos los errores, no solo el primero', () {
    final result = validator.validate({
      'schema': 'makeup-recipe/1',
      'name': '',
      'lips': {'color': 'rojo', 'opacity': 2, 'shader': 'x'},
    });
    expect(
      result.errors.map((e) => e.path).toSet(),
      {r'$.schema', r'$.name', r'$.lips.color', r'$.lips.opacity', r'$.lips.shader'},
    );
  });
}

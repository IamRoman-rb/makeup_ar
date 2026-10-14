import 'dart:convert';
import 'dart:io';

import 'package:ar_makeup_app/features/ar/domain/makeup_recipe.dart';
import 'package:ar_makeup_app/features/ar/domain/recipe_presets.dart';
import 'package:ar_makeup_app/features/ar/domain/recipe_validator.dart';
import 'package:ar_makeup_app/features/studio/domain/recipe_edits.dart';
import 'package:ar_makeup_app/features/studio/domain/recipe_qa.dart';
import 'package:flutter_test/flutter_test.dart';

MakeupRecipe recipe(Map<String, Object?> json) {
  final result = const RecipeValidator().validate({'schema': kMakeupRecipeSchemaV2, 'name': 'QA', ...json});
  final recipe = result.recipe;
  if (recipe == null) throw StateError('receta inválida: ${result.errors}');
  return recipe;
}

List<QaReason> reasons(QaReport report, [QaLevel? level]) =>
    [for (final i in report.issues) if (level == null || i.level == level) i.reason];

void main() {
  // Paridad con tools/studio/qa_reference.py (las funciones de referencia del
  // motor): si cambia la matemática de un lado, esto falla.
  test('paridad con la referencia Python (qa_render_cases.json)', () {
    final cases = jsonDecode(File('test/fixtures/qa_render_cases.json').readAsStringSync()) as List<Object?>;
    expect(cases, isNotEmpty);
    final byName = {for (final p in RecipePresets.all) p.recipe.name: p.recipe};
    final rendered = <String, List<QaSample>>{};
    for (final raw in cases) {
      final c = raw as Map<String, Object?>;
      final name = c['recipe'] as String;
      final preset = byName[name];
      expect(preset, isNotNull, reason: 'preset $name');
      if (preset == null) continue;
      final samples = rendered.putIfAbsent(name, () => RecipeQa.render(preset));
      final light = QaLight.values.byName(c['light'] as String);
      final layer = RecipeLayer.values.byName(c['layer'] as String);
      final sample = samples.firstWhere((s) => s.layer == layer && s.tone == c['tone'] && s.light == light);
      final camera = (c['camera'] as List<Object?>).cast<num>();
      final out = (c['out'] as List<Object?>).cast<num>();
      for (var i = 0; i < 3; i++) {
        expect(sample.camera[i], closeTo(camera[i].toDouble(), 1e-3), reason: '$name $layer tono ${c['tone']} $light cámara');
        expect(sample.out[i], closeTo(out[i].toDouble(), 1e-3), reason: '$name $layer tono ${c['tone']} $light salida');
      }
      expect(sample.maxShading, closeTo((c['maxShading'] as num).toDouble(), 1e-3), reason: '$name $layer gamut');
    }
  });

  test('ningún preset falla el QA', () {
    for (final preset in RecipePresets.all) {
      final report = RecipeQa.check(preset.recipe);
      expect(report.blocksPublish, isFalse, reason: '${preset.id}: ${reasons(report, QaLevel.fail)}');
    }
  });

  test('capa invisible: falla y bloquea', () {
    final report = RecipeQa.check(recipe({
      'lips': {'color': '#B3122D', 'opacity': 0.01},
    }));
    expect(reasons(report, QaLevel.fail), [QaReason.invisible]);
    expect(report.levelOf(QaCheckKind.visibility), QaLevel.fail);
    expect(report.blocksPublish, isTrue);
  });

  test('base blanca sobre piel profunda: tiza, falla', () {
    final report = RecipeQa.check(recipe({
      'skin': {
        'foundation': {'color': '#F4E4D8', 'coverage': 0.7},
      },
    }));
    expect(reasons(report, QaLevel.fail), contains(QaReason.chalky));
    expect(report.levelOf(QaCheckKind.consistency), QaLevel.fail);
  });

  test('labial pálido sobre piel profunda: ceniza, aviso', () {
    final report = RecipeQa.check(recipe({
      'lips': {'color': '#F2C6C2', 'opacity': 0.9},
    }));
    expect(reasons(report), contains(QaReason.ashy));
    expect(report.blocksPublish, isFalse);
  });

  test('neón saturado se lava con luz: aviso', () {
    final report = RecipeQa.check(recipe({
      'lips': {'color': '#FF00E6', 'opacity': 0.9},
    }));
    expect(reasons(report), contains(QaReason.washedOut));
    expect(report.levelOf(QaCheckKind.clipping), QaLevel.warn);
  });

  test('cobertura implausible y costo: avisos', () {
    final report = RecipeQa.check(recipe({
      'eyes': {
        'liner': {'color': '#000000', 'opacity': 1.0, 'thickness': 1.0, 'wing': 1.0},
      },
      'skin': {
        'foundation': {'color': '#C8A088', 'coverage': 0.95},
      },
      'cheeks': {'color': '#E8837A', 'opacity': 0.9, 'spread': 1.0},
      'effects': [
        {'type': 'glitter', 'intensity': 0.5},
        {'type': 'sheen', 'intensity': 0.5},
        {'type': 'freckles', 'intensity': 0.5},
      ],
    }));
    expect(
      reasons(report, QaLevel.warn),
      containsAll([QaReason.extremeLiner, QaReason.maskFoundation, QaReason.heavyBlush, QaReason.effectsUnmeasured]),
    );
    expect(report.levelOf(QaCheckKind.cost), QaLevel.warn);
  });

  test('una receta normal pasa todo', () {
    final report = RecipeQa.check(RecipePresets.byId('classic_red').recipe);
    for (final kind in QaCheckKind.values) {
      expect(report.levelOf(kind), isNot(QaLevel.fail), reason: '$kind');
    }
    expect(report.levelOf(QaCheckKind.cost), QaLevel.pass);
  });
}

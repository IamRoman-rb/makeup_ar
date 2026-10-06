/// Validador de recetas `makeup-recipe/2`.
///
/// Reproduce exactamente `docs/ar_engine/recipe_v2.schema.json`:
/// `additionalProperties: false` en todos los niveles, campos requeridos,
/// enums cerrados, HEX `^#[0-9A-Fa-f]{6}$`, números en `[0, 1]`, máximo 4
/// sombras y 3 efectos, y nombre de 1 a 60 caracteres. La paridad con el
/// esquema se verifica con `test/fixtures/recipe_v2_cases.json`, el mismo
/// archivo que valida `tools/studio/validate_recipe_cases.py` con jsonschema.
///
/// Todo lo que venga de un LLM o de Firestore pasa por acá: si no valida, se
/// descarta y se usa un preset local.
library;

import 'dart:convert';

import 'makeup_recipe.dart';

/// Problema encontrado en una receta. [path] usa notación tipo JSONPath
/// (`$.eyes.shadow[2].color`).
final class RecipeIssue {
  const RecipeIssue(this.path, this.message);

  final String path;
  final String message;

  @override
  String toString() => '$path: $message';
}

final class RecipeValidationResult {
  RecipeValidationResult._(this.recipe, List<RecipeIssue> errors, List<RecipeIssue> warnings)
      : errors = List.unmodifiable(errors),
        warnings = List.unmodifiable(warnings);

  /// La receta, solo si no hubo errores.
  final MakeupRecipe? recipe;

  /// Motivos de rechazo. Vacío si [isValid].
  final List<RecipeIssue> errors;

  /// Correcciones aplicadas sin rechazar (solo con `clampOutOfRange`).
  final List<RecipeIssue> warnings;

  bool get isValid => recipe != null;
}

final class RecipeValidator {
  /// Con [clampOutOfRange] en true, los números fuera de `[0, 1]` se recortan
  /// al rango y se informan como warning en lugar de rechazar la receta (útil
  /// para entradas del editor). Por defecto es estricto, igual que el esquema:
  /// así se tratan las respuestas de un LLM.
  const RecipeValidator({this.clampOutOfRange = false});

  final bool clampOutOfRange;

  /// Tamaño máximo aceptado por [validateJsonString]. Una receta completa
  /// ronda 1 KB; esto corta respuestas absurdas antes de decodificarlas.
  static const int maxJsonLength = 16 * 1024;

  static const _rootKeys = {'schema', 'name', 'lips', 'cheeks', 'eyes', 'skin', 'effects'};
  static const _lipsKeys = {'color', 'opacity', 'finish', 'gloss', 'lumaFollow', 'liner'};
  static const _colorLayerKeys = {'color', 'opacity'};
  static const _cheeksKeys = {'color', 'opacity', 'spread', 'placement'};
  static const _eyesKeys = {'shadow', 'liner', 'lashes'};
  static const _shadowKeys = {'color', 'opacity', 'region', 'finish'};
  static const _eyeLinerKeys = {'color', 'opacity', 'thickness', 'wing'};
  static const _lashesKeys = {'opacity', 'length', 'volume'};
  static const _skinKeys = {'foundation', 'contour', 'highlight'};
  static const _foundationKeys = {'color', 'coverage'};
  static const _effectKeys = {'type', 'intensity', 'region'};

  /// Valida un JSON en texto (por ejemplo, la respuesta cruda de un LLM).
  RecipeValidationResult validateJsonString(String source) {
    if (source.length > maxJsonLength) {
      return RecipeValidationResult._(null, [RecipeIssue(r'$', 'JSON demasiado grande (${source.length} > $maxJsonLength)')], const []);
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException catch (e) {
      return RecipeValidationResult._(null, [RecipeIssue(r'$', 'JSON mal formado: ${e.message}')], const []);
    }
    return validate(decoded);
  }

  /// Valida un JSON ya decodificado (`Map` de Firestore o de `jsonDecode`).
  RecipeValidationResult validate(Object? json) {
    final ctx = _Context(clampOutOfRange);
    final recipe = _parseRecipe(ctx, json);
    if (ctx.errors.isNotEmpty || recipe == null) {
      return RecipeValidationResult._(null, ctx.errors, ctx.warnings);
    }
    return RecipeValidationResult._(recipe, const [], ctx.warnings);
  }

  MakeupRecipe? _parseRecipe(_Context ctx, Object? json) {
    const path = r'$';
    final map = ctx.object(json, path, _rootKeys, const {'schema', 'name'});
    if (map == null) return null;

    if (map.containsKey('schema') && map['schema'] != kMakeupRecipeSchemaV2) {
      ctx.error('$path.schema', 'debe ser "$kMakeupRecipeSchemaV2"');
    }
    final name = ctx.name(map, 'name', '$path.name');
    final lips = map.containsKey('lips') ? _parseLips(ctx, map['lips'], '$path.lips') : null;
    final cheeks = map.containsKey('cheeks') ? _parseCheeks(ctx, map['cheeks'], '$path.cheeks') : null;
    final eyes = map.containsKey('eyes') ? _parseEyes(ctx, map['eyes'], '$path.eyes') : null;
    final skin = map.containsKey('skin') ? _parseSkin(ctx, map['skin'], '$path.skin') : null;
    final effects = map.containsKey('effects')
        ? ctx.array(map['effects'], '$path.effects', RecipeLimits.maxEffects, _parseEffect)
        : null;

    if (name == null) return null;
    return MakeupRecipe(name: name, lips: lips, cheeks: cheeks, eyes: eyes, skin: skin, effects: effects);
  }

  LipsSpec? _parseLips(_Context ctx, Object? json, String path) {
    final map = ctx.object(json, path, _lipsKeys, const {'color', 'opacity'});
    if (map == null) return null;
    final color = ctx.color(map, 'color', path);
    final opacity = ctx.unit(map, 'opacity', path);
    final finish = ctx.enumValue(map, 'finish', path, LipFinish.values, LipFinish.fromWire);
    final gloss = ctx.unit(map, 'gloss', path);
    final lumaFollow = ctx.unit(map, 'lumaFollow', path);
    final liner = map.containsKey('liner') ? _parseColorLayer(ctx, map['liner'], '$path.liner') : null;
    if (color == null || opacity == null) return null;
    return LipsSpec(color: color, opacity: opacity, finish: finish, gloss: gloss, lumaFollow: lumaFollow, liner: liner);
  }

  ColorLayer? _parseColorLayer(_Context ctx, Object? json, String path) {
    final map = ctx.object(json, path, _colorLayerKeys, _colorLayerKeys);
    if (map == null) return null;
    final color = ctx.color(map, 'color', path);
    final opacity = ctx.unit(map, 'opacity', path);
    if (color == null || opacity == null) return null;
    return ColorLayer(color: color, opacity: opacity);
  }

  CheeksSpec? _parseCheeks(_Context ctx, Object? json, String path) {
    final map = ctx.object(json, path, _cheeksKeys, const {'color', 'opacity'});
    if (map == null) return null;
    final color = ctx.color(map, 'color', path);
    final opacity = ctx.unit(map, 'opacity', path);
    final spread = ctx.unit(map, 'spread', path);
    final placement = ctx.enumValue(map, 'placement', path, CheekPlacement.values, CheekPlacement.fromWire);
    if (color == null || opacity == null) return null;
    return CheeksSpec(color: color, opacity: opacity, spread: spread, placement: placement);
  }

  EyesSpec? _parseEyes(_Context ctx, Object? json, String path) {
    final map = ctx.object(json, path, _eyesKeys, const {});
    if (map == null) return null;
    final shadow = map.containsKey('shadow')
        ? ctx.array(map['shadow'], '$path.shadow', RecipeLimits.maxShadowLayers, _parseShadow)
        : null;
    final liner = map.containsKey('liner') ? _parseEyeLiner(ctx, map['liner'], '$path.liner') : null;
    final lashes = map.containsKey('lashes') ? _parseLashes(ctx, map['lashes'], '$path.lashes') : null;
    return EyesSpec(shadow: shadow, liner: liner, lashes: lashes);
  }

  EyeShadowLayer? _parseShadow(_Context ctx, Object? json, String path) {
    final map = ctx.object(json, path, _shadowKeys, const {'color', 'opacity', 'region'});
    if (map == null) return null;
    final color = ctx.color(map, 'color', path);
    final opacity = ctx.unit(map, 'opacity', path);
    final region = ctx.enumValue(map, 'region', path, ShadowRegion.values, ShadowRegion.fromWire);
    final finish = ctx.enumValue(map, 'finish', path, ShadowFinish.values, ShadowFinish.fromWire);
    if (color == null || opacity == null || region == null) return null;
    return EyeShadowLayer(color: color, opacity: opacity, region: region, finish: finish);
  }

  EyeLinerSpec? _parseEyeLiner(_Context ctx, Object? json, String path) {
    final map = ctx.object(json, path, _eyeLinerKeys, const {'color', 'opacity'});
    if (map == null) return null;
    final color = ctx.color(map, 'color', path);
    final opacity = ctx.unit(map, 'opacity', path);
    final thickness = ctx.unit(map, 'thickness', path);
    final wing = ctx.unit(map, 'wing', path);
    if (color == null || opacity == null) return null;
    return EyeLinerSpec(color: color, opacity: opacity, thickness: thickness, wing: wing);
  }

  LashesSpec? _parseLashes(_Context ctx, Object? json, String path) {
    final map = ctx.object(json, path, _lashesKeys, const {'opacity'});
    if (map == null) return null;
    final opacity = ctx.unit(map, 'opacity', path);
    final length = ctx.unit(map, 'length', path);
    final volume = ctx.unit(map, 'volume', path);
    if (opacity == null) return null;
    return LashesSpec(opacity: opacity, length: length, volume: volume);
  }

  SkinSpec? _parseSkin(_Context ctx, Object? json, String path) {
    final map = ctx.object(json, path, _skinKeys, const {});
    if (map == null) return null;
    final foundation = map.containsKey('foundation') ? _parseFoundation(ctx, map['foundation'], '$path.foundation') : null;
    final contour = map.containsKey('contour') ? _parseColorLayer(ctx, map['contour'], '$path.contour') : null;
    final highlight = map.containsKey('highlight') ? _parseColorLayer(ctx, map['highlight'], '$path.highlight') : null;
    return SkinSpec(foundation: foundation, contour: contour, highlight: highlight);
  }

  FoundationSpec? _parseFoundation(_Context ctx, Object? json, String path) {
    final map = ctx.object(json, path, _foundationKeys, _foundationKeys);
    if (map == null) return null;
    final color = ctx.color(map, 'color', path);
    final coverage = ctx.unit(map, 'coverage', path);
    if (color == null || coverage == null) return null;
    return FoundationSpec(color: color, coverage: coverage);
  }

  MakeupEffect? _parseEffect(_Context ctx, Object? json, String path) {
    final map = ctx.object(json, path, _effectKeys, const {'type', 'intensity'});
    if (map == null) return null;
    final type = ctx.enumValue(map, 'type', path, EffectType.values, EffectType.fromWire);
    final intensity = ctx.unit(map, 'intensity', path);
    final region = ctx.enumValue(map, 'region', path, EffectRegion.values, EffectRegion.fromWire);
    if (type == null || intensity == null) return null;
    return MakeupEffect(type: type, intensity: intensity, region: region);
  }
}

/// Acumula errores y warnings de una validación.
final class _Context {
  _Context(this.clampOutOfRange);

  final bool clampOutOfRange;
  final List<RecipeIssue> errors = [];
  final List<RecipeIssue> warnings = [];

  void error(String path, String message) => errors.add(RecipeIssue(path, message));

  /// Objeto con claves cerradas ([allowed]) y [required]. Devuelve null si no
  /// es un objeto JSON; las claves extra o faltantes se reportan sin cortar.
  Map<String, Object?>? object(Object? value, String path, Set<String> allowed, Set<String> required) {
    if (value is! Map) {
      error(path, 'debe ser un objeto');
      return null;
    }
    final map = <String, Object?>{};
    for (final entry in value.entries) {
      final key = entry.key;
      if (key is! String) {
        error(path, 'clave no textual: $key');
        continue;
      }
      if (!allowed.contains(key)) {
        error('$path.$key', 'propiedad no permitida');
        continue;
      }
      map[key] = entry.value;
    }
    for (final key in required) {
      if (!value.containsKey(key)) error('$path.$key', 'es obligatorio');
    }
    return map;
  }

  String? name(Map<String, Object?> map, String key, String path) {
    if (!map.containsKey(key)) return null; // ya reportado como obligatorio
    final value = map[key];
    if (value is! String) {
      error(path, 'debe ser texto');
      return null;
    }
    // El esquema cuenta code points, no unidades UTF-16.
    final length = value.runes.length;
    if (length < 1) {
      error(path, 'no puede estar vacío');
      return null;
    }
    if (length > RecipeLimits.nameMaxLength) {
      error(path, 'máximo ${RecipeLimits.nameMaxLength} caracteres (tiene $length)');
      return null;
    }
    return value;
  }

  // color/unit/enumValue: si la clave falta devuelven null; que sea obligatoria
  // ya lo reportó object().
  RecipeColor? color(Map<String, Object?> map, String key, String parent) {
    if (!map.containsKey(key)) return null;
    final path = '$parent.$key';
    final value = map[key];
    if (value is! String) {
      error(path, 'debe ser un color "#RRGGBB"');
      return null;
    }
    final parsed = RecipeColor.tryParse(value);
    if (parsed == null) error(path, 'color inválido "$value" (se espera "#RRGGBB")');
    return parsed;
  }

  /// Número en [0, 1]. Con [clampOutOfRange], recorta y avisa.
  double? unit(Map<String, Object?> map, String key, String parent) {
    if (!map.containsKey(key)) return null;
    final path = '$parent.$key';
    final value = map[key];
    if (value is! num || !value.isFinite) {
      error(path, 'debe ser un número');
      return null;
    }
    final asDouble = value.toDouble();
    if (asDouble >= 0 && asDouble <= 1) return asDouble;
    if (clampOutOfRange) {
      final clamped = asDouble.clamp(0.0, 1.0);
      warnings.add(RecipeIssue(path, '$asDouble fuera de [0, 1], recortado a $clamped'));
      return clamped;
    }
    error(path, '$asDouble fuera de [0, 1]');
    return null;
  }

  T? enumValue<T extends WireEnum>(
    Map<String, Object?> map,
    String key,
    String parent,
    List<T> values,
    T? Function(Object?) fromWire,
  ) {
    if (!map.containsKey(key)) return null;
    final path = '$parent.$key';
    final parsed = fromWire(map[key]);
    if (parsed == null) {
      final allowed = values.map((v) => v.wireName).join('|');
      error(path, 'valor "${map[key]}" no permitido ($allowed)');
    }
    return parsed;
  }

  List<T>? array<T>(
    Object? value,
    String path,
    int maxItems,
    T? Function(_Context ctx, Object? json, String path) parseItem,
  ) {
    if (value is! List) {
      error(path, 'debe ser una lista');
      return null;
    }
    if (value.length > maxItems) {
      error(path, 'máximo $maxItems elementos (tiene ${value.length})');
      return null;
    }
    final items = <T>[];
    for (var i = 0; i < value.length; i++) {
      final item = parseItem(this, value[i], '$path[$i]');
      if (item != null) items.add(item);
    }
    return items;
  }
}

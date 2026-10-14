/// Ediciones del Studio sobre una receta (F3): cambiar color, opacidad,
/// acabado, nombre, quitar una capa o agregarla con un color de la paleta de
/// un producto (F4). Dominio puro.
///
/// Cada edición pasa por el JSON y vuelve por [RecipeValidator] (recortando
/// números a rango): una edición nunca produce una receta inválida. Si algo
/// no valida, se devuelve la receta sin cambios.
library;

import '../../ar/domain/makeup_recipe.dart';
import '../../ar/domain/recipe_validator.dart';

/// Capa editable de una receta: dónde está en el JSON y cómo se llama su
/// cantidad (`opacity` o `coverage`).
enum RecipeLayer {
  lips(['lips']),
  lipLiner(['lips', 'liner']),
  cheeks(['cheeks']),
  foundation(['skin', 'foundation'], amountKey: 'coverage'),
  contour(['skin', 'contour']),
  highlight(['skin', 'highlight']),
  eyeLiner(['eyes', 'liner']),
  // Las pestañas no traen color (kLashColor del motor).
  lashes(['eyes', 'lashes'], hasColor: false),
  shadow0(['eyes', 'shadow', 0]),
  shadow1(['eyes', 'shadow', 1]),
  shadow2(['eyes', 'shadow', 2]),
  shadow3(['eyes', 'shadow', 3]);

  const RecipeLayer(this.path, {this.amountKey = 'opacity', this.hasColor = true});

  /// Claves (String) e índices (int) desde la raíz del JSON.
  final List<Object> path;
  final String amountKey;
  final bool hasColor;
}

/// Lectura de una capa para el editor.
final class LayerValue {
  const LayerValue({required this.color, required this.amount});

  /// null en las pestañas.
  final RecipeColor? color;
  final double amount;
}

abstract final class RecipeEdits {
  static const RecipeValidator _validator = RecipeValidator(clampOutOfRange: true);

  /// Capas presentes en [recipe], en el orden de [RecipeLayer].
  static List<RecipeLayer> layersOf(MakeupRecipe recipe) =>
      [for (final layer in RecipeLayer.values) if (valueOf(recipe, layer) != null) layer];

  static LayerValue? valueOf(MakeupRecipe recipe, RecipeLayer layer) {
    final node = _find(recipe.toJson(), layer.path);
    if (node is! Map) return null;
    final amount = node[layer.amountKey];
    final color = node['color'];
    return LayerValue(
      color: color is String ? RecipeColor.tryParse(color) : null,
      amount: amount is num ? amount.toDouble() : 0,
    );
  }

  static MakeupRecipe withColor(MakeupRecipe recipe, RecipeLayer layer, RecipeColor color) {
    if (!layer.hasColor) return recipe;
    return _edit(recipe, layer, (node) => node['color'] = color.toHex());
  }

  /// Pone [color] en [layer] y, si la capa no existe, la agrega con valores
  /// por defecto (paleta de producto, F4). Una sombra nueva tiene que ser la
  /// siguiente libre (shadowN con N = cantidad actual) y va a la primera región
  /// que no esté usada. Sin cambios si no se puede: pestañas (no tienen
  /// color), delineado de labios sin labial o sombras de más.
  static MakeupRecipe withColorOrAdd(MakeupRecipe recipe, RecipeLayer layer, RecipeColor color) {
    if (!layer.hasColor) return recipe;
    if (valueOf(recipe, layer) != null) return withColor(recipe, layer, color);
    final json = _mutable(recipe.toJson()) as Map<String, Object?>;
    final hex = color.toHex();
    Map<String, Object?> region(String key) {
      final existing = json[key];
      if (existing is Map<String, Object?>) return existing;
      final created = <String, Object?>{};
      json[key] = created;
      return created;
    }

    switch (layer) {
      case RecipeLayer.lips:
        json['lips'] = {'color': hex, 'opacity': 0.85, 'finish': LipFinish.satin.wireName};
      case RecipeLayer.lipLiner:
        final lips = json['lips'];
        if (lips is! Map<String, Object?>) return recipe;
        lips['liner'] = {'color': hex, 'opacity': 0.9};
      case RecipeLayer.cheeks:
        json['cheeks'] = {'color': hex, 'opacity': 0.35, 'spread': 0.5, 'placement': CheekPlacement.apple.wireName};
      case RecipeLayer.foundation:
        region('skin')['foundation'] = {'color': hex, 'coverage': 0.3};
      case RecipeLayer.contour:
        region('skin')['contour'] = {'color': hex, 'opacity': 0.3};
      case RecipeLayer.highlight:
        region('skin')['highlight'] = {'color': hex, 'opacity': 0.3};
      case RecipeLayer.eyeLiner:
        region('eyes')['liner'] = {'color': hex, 'opacity': 0.9, 'thickness': 0.5, 'wing': 0.0};
      case RecipeLayer.shadow0 || RecipeLayer.shadow1 || RecipeLayer.shadow2 || RecipeLayer.shadow3:
        final eyes = region('eyes');
        final shadows = (eyes['shadow'] as List<Object?>?) ?? <Object?>[];
        if (layer.path.last != shadows.length || shadows.length >= RecipeLimits.maxShadowLayers) return recipe;
        final used = {for (final s in shadows) if (s is Map) s['region']};
        final free = ShadowRegion.values.firstWhere((r) => !used.contains(r.wireName), orElse: () => ShadowRegion.lid);
        eyes['shadow'] = [
          ...shadows,
          {'color': hex, 'opacity': 0.5, 'region': free.wireName, 'finish': ShadowFinish.matte.wireName},
        ];
      case RecipeLayer.lashes:
        return recipe;
    }
    return _validator.validate(json).recipe ?? recipe;
  }

  /// La sombra que [withColorOrAdd] agregaría a [recipe], o null si ya hay 4.
  static RecipeLayer? nextShadow(MakeupRecipe recipe) {
    final count = recipe.eyes?.shadow?.length ?? 0;
    return count < RecipeLimits.maxShadowLayers ? RecipeLayer.values[RecipeLayer.shadow0.index + count] : null;
  }

  static MakeupRecipe withAmount(MakeupRecipe recipe, RecipeLayer layer, double amount) =>
      _edit(recipe, layer, (node) => node[layer.amountKey] = amount.clamp(0.0, 1.0));

  static MakeupRecipe withLipFinish(MakeupRecipe recipe, LipFinish finish) =>
      _edit(recipe, RecipeLayer.lips, (node) {
        node['finish'] = finish.wireName;
        // Mate sin brillo; brillo con al menos 0,5 (vocabulario del prompt §10.4).
        if (finish == LipFinish.matte) node['gloss'] = 0.0;
        if (finish == LipFinish.gloss) node['gloss'] = ((node['gloss'] as num?)?.toDouble() ?? 0.0).clamp(0.5, 1.0);
      });

  static MakeupRecipe withName(MakeupRecipe recipe, String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return recipe;
    final json = recipe.toJson()..['name'] = trimmed.runes.length > RecipeLimits.nameMaxLength
        ? String.fromCharCodes(trimmed.runes.take(RecipeLimits.nameMaxLength))
        : trimmed;
    return _validator.validate(json).recipe ?? recipe;
  }

  /// Saca la capa; si su región queda vacía, también la región.
  static MakeupRecipe without(MakeupRecipe recipe, RecipeLayer layer) {
    final json = _mutable(recipe.toJson()) as Map<String, Object?>;
    final parent = _find(json, layer.path.sublist(0, layer.path.length - 1));
    final last = layer.path.last;
    if (parent is Map && last is String) {
      parent.remove(last);
    } else if (parent is List && last is int && last < parent.length) {
      parent.removeAt(last);
    } else {
      return recipe;
    }
    _pruneEmpty(json);
    return _validator.validate(json).recipe ?? recipe;
  }

  static MakeupRecipe _edit(MakeupRecipe recipe, RecipeLayer layer, void Function(Map<String, Object?> node) change) {
    final json = _mutable(recipe.toJson()) as Map<String, Object?>;
    final node = _find(json, layer.path);
    if (node is! Map<String, Object?>) return recipe;
    change(node);
    return _validator.validate(json).recipe ?? recipe;
  }

  static Object? _find(Object? root, List<Object> path) {
    Object? node = root;
    for (final key in path) {
      if (key is String && node is Map) {
        node = node[key];
      } else if (key is int && node is List && key < node.length) {
        node = node[key];
      } else {
        return null;
      }
    }
    return node;
  }

  /// Copia profunda con mapas y listas modificables.
  static Object? _mutable(Object? value) => switch (value) {
        Map() => <String, Object?>{for (final entry in value.entries) '${entry.key}': _mutable(entry.value)},
        List() => [for (final item in value) _mutable(item)],
        _ => value,
      };

  /// Regiones (y listas de sombras) que quedaron vacías.
  static void _pruneEmpty(Map<String, Object?> json) {
    final eyes = json['eyes'];
    if (eyes is Map && eyes['shadow'] is List && (eyes['shadow'] as List).isEmpty) eyes.remove('shadow');
    for (final region in ['lips', 'cheeks', 'eyes', 'skin']) {
      final value = json[region];
      if (value is Map && value.isEmpty) json.remove(region);
    }
  }
}

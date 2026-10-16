/// Respaldo local cuando la IA no devuelve variantes (caída, cuota, sin
/// Blaze): el preset más cercano al prompt ([RecipePresets.closestTo]) con
/// los colores y el acabado que pide el texto encima. "labios azules" da
/// labios azules, no el nude de "Natural". Dominio puro, sin red.
///
/// Entiende colores y zonas en es/en/pt/fr. Cada color va a la palabra de zona
/// más cercana (empate: la anterior); sin ninguna zona, a los labios. No
/// entiende cantidades ni comparativos ("más oscuro"). Cada edición pasa por
/// [RecipeEdits], que valida: nunca sale una receta inválida.
library;

import '../../ar/domain/makeup_recipe.dart';
import '../../ar/domain/recipe_presets.dart';
import 'recipe_edits.dart';

enum _Zone { lips, liner, shadow, cheeks, iris }

/// Palabras que significan [value]: las que empiezan con un prefijo o son
/// exactamente una de [exact] (para raíces cortas o ambiguas: "red" no es
/// "redondo", "plata" no es "plátano").
final class _Term<T> {
  const _Term(this.value, {this.prefixes = const [], this.exact = const []});

  final T value;
  final List<String> prefixes;
  final List<String> exact;

  bool matches(String word) => exact.contains(word) || prefixes.any(word.startsWith);
}

abstract final class PromptFallback {
  /// Opacidades mínimas cuando el texto pide un color explícito: si el preset
  /// lo tenía muy tenue, el color pedido no se vería.
  static const double minLipsOpacity = 0.8;
  static const double minShadowOpacity = 0.5;
  static const double minCheeksOpacity = 0.3;

  /// Sombras que puede pedir el texto (la primera y la segunda que nombra).
  static const int maxShadowColors = 2;

  static MakeupRecipe recipeFor(String prompt) {
    final base = RecipePresets.closestTo(prompt).recipe;
    final words = RecipePresets.normalize(prompt).split(_separator).where((w) => w.isNotEmpty).toList(growable: false);

    final zones = <(int, _Zone)>[];
    final colors = <(int, RecipeColor)>[];
    LipFinish? finish;
    var finishAt = -1;
    for (var i = 0; i < words.length; i++) {
      final word = words[i];
      final zone = _find(_zones, word);
      if (zone != null) {
        zones.add((i, zone));
        continue;
      }
      final color = _find(_colors, word);
      if (color != null) {
        colors.add((i, color));
        continue;
      }
      final wordFinish = _find(_finishes, word);
      if (wordFinish != null && finish == null) {
        finish = wordFinish;
        finishAt = i;
      }
    }
    if (colors.isEmpty && finish == null) return base;

    var recipe = base;
    var changed = false;
    var shadows = 0;
    final colored = <_Zone>{};
    for (final (index, color) in colors) {
      final zone = _zoneFor(index, zones);
      switch (zone) {
        case _Zone.shadow:
          if (shadows >= maxShadowColors) continue;
          final layer = RecipeLayer.values[RecipeLayer.shadow0.index + shadows];
          recipe = _atLeast(RecipeEdits.withColorOrAdd(recipe, layer, color), layer, minShadowOpacity);
          shadows++;
          changed = true;
        case _Zone.lips || _Zone.liner || _Zone.cheeks || _Zone.iris:
          // Un color por zona: el primero que nombra el texto.
          if (!colored.add(zone)) continue;
          final layer = _layers[zone] ?? RecipeLayer.lips;
          recipe = RecipeEdits.withColorOrAdd(recipe, layer, color);
          recipe = switch (zone) {
            _Zone.lips => _atLeast(recipe, layer, minLipsOpacity),
            _Zone.cheeks => _atLeast(recipe, layer, minCheeksOpacity),
            _ => recipe,
          };
          changed = true;
      }
    }
    if (finish != null && _zoneFor(finishAt, zones) == _Zone.lips) {
      recipe = RecipeEdits.withLipFinish(recipe, finish);
      changed = true;
    }
    return changed ? RecipeEdits.withName(recipe, _title(prompt)) : base;
  }

  static T? _find<T>(List<_Term<T>> terms, String word) {
    for (final term in terms) {
      if (term.matches(word)) return term.value;
    }
    return null;
  }

  /// La zona nombrada más cerca de la palabra [index]; empate: la anterior.
  /// Sin zonas en el texto: labios.
  static _Zone _zoneFor(int index, List<(int, _Zone)> zones) {
    _Zone? best;
    var bestDistance = 1 << 30;
    for (final (at, zone) in zones) {
      final distance = (at - index).abs();
      if (distance < bestDistance) {
        best = zone;
        bestDistance = distance;
      }
    }
    return best ?? _Zone.lips;
  }

  static MakeupRecipe _atLeast(MakeupRecipe recipe, RecipeLayer layer, double minimum) {
    final value = RecipeEdits.valueOf(recipe, layer);
    if (value == null || value.amount >= minimum) return recipe;
    return RecipeEdits.withAmount(recipe, layer, minimum);
  }

  /// El texto del usuario como nombre (withName recorta a 60).
  static String _title(String prompt) {
    final trimmed = prompt.trim();
    if (trimmed.isEmpty) return trimmed;
    return trimmed[0].toUpperCase() + trimmed.substring(1);
  }

  static final RegExp _separator = RegExp(r'[^a-z0-9-]+');

  static const Map<_Zone, RecipeLayer> _layers = {
    _Zone.lips: RecipeLayer.lips,
    _Zone.liner: RecipeLayer.eyeLiner,
    _Zone.cheeks: RecipeLayer.cheeks,
    _Zone.iris: RecipeLayer.iris,
  };

  // Delineado antes que sombra: "eyeliner" no es "eye".
  static const List<_Term<_Zone>> _zones = [
    _Term(_Zone.lips, prefixes: ['labio', 'labial', 'lips', 'lipstick', 'batom', 'levre'], exact: ['lip', 'boca', 'bocas']),
    _Term(_Zone.liner, prefixes: ['delinea', 'eyeliner', 'liner', 'kohl']),
    _Term(_Zone.shadow,
        prefixes: ['sombra', 'parpad', 'eyeshadow', 'shadow', 'olho', 'ombre', 'paupier', 'palpebr'],
        exact: ['ojo', 'ojos', 'eye', 'eyes', 'yeux', 'oeil']),
    _Term(_Zone.cheeks, prefixes: ['mejilla', 'cheek', 'rubor', 'blush', 'bochecha', 'joue', 'pomulo', 'colorete']),
    // "lente" exacto: "lentejuelas" son lentejuelas, no lentes.
    _Term(_Zone.iris, prefixes: ['iris', 'lentes', 'lentill', 'contact'], exact: ['lente']),
  ];

  static const List<_Term<RecipeColor>> _colors = [
    _Term(RecipeColor(0xB3122D), prefixes: ['rojo', 'roja', 'vermelh', 'rouge'], exact: ['red', 'reds']),
    _Term(RecipeColor(0xD9577F), prefixes: ['rosa', 'rosad', 'pink', 'rose', 'fucsia', 'fuchsia', 'magenta']),
    _Term(RecipeColor(0xE8705A), prefixes: ['coral', 'corail', 'naranj', 'orang', 'laranj']),
    _Term(RecipeColor(0xB9786E), prefixes: ['nude', 'beige']),
    _Term(RecipeColor(0x7A4A32), prefixes: ['marron', 'cafe', 'brown', 'castan', 'chocolat', 'terracot']),
    _Term(RecipeColor(0x5E1224), prefixes: ['bordo', 'burgund', 'borgon', 'bordeaux', 'vino', 'wine', 'granate', 'grenat']),
    _Term(RecipeColor(0x6B2E8C),
        prefixes: ['violet', 'morad', 'purpur', 'purple', 'roxo', 'roxa', 'lila', 'lilac', 'lavand', 'malva', 'mauve']),
    _Term(RecipeColor(0x1F4FB0), prefixes: ['azul', 'blue', 'bleu']),
    _Term(RecipeColor(0x2AA7B8), prefixes: ['celest', 'turques', 'turquoi', 'cyan', 'aqua']),
    _Term(RecipeColor(0x2E7D4F), prefixes: ['verde', 'green', 'esmerald', 'emerald'], exact: ['vert', 'verte', 'verts', 'vertes']),
    _Term(RecipeColor(0xC9A13B), prefixes: ['dorad', 'golden', 'dourad'], exact: ['gold', 'oro', 'ouro', 'dore', 'doree', 'dores']),
    _Term(RecipeColor(0xB8BCC4), prefixes: ['platead', 'silver', 'pratead', 'argent'], exact: ['plata', 'prata']),
    _Term(RecipeColor(0x141414), prefixes: ['negr', 'black', 'noir'], exact: ['preto', 'preta', 'pretos', 'pretas']),
  ];

  static const List<_Term<LipFinish>> _finishes = [
    _Term(LipFinish.matte, exact: ['mate', 'mates', 'matte', 'mat', 'mats', 'fosco']),
    _Term(LipFinish.gloss, prefixes: ['gloss', 'brillo', 'brilh', 'brillant', 'jugos']),
    _Term(LipFinish.satin, prefixes: ['satin', 'acetinad']),
    _Term(LipFinish.shimmer, prefixes: ['shimmer', 'glitter', 'escarch', 'purpurin', 'paillett', 'metalic', 'metallic']),
  ];
}

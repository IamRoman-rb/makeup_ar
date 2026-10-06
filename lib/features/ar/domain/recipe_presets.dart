/// Presets locales de recetas: el respaldo cuando la IA falla, no responde o
/// devuelve algo que no valida.
///
/// Se definen como JSON y pasan por [RecipeValidator] igual que cualquier
/// receta externa, así un preset mal escrito nunca llega al motor (y el test
/// lo detecta).
library;

import 'makeup_recipe.dart';
import 'recipe_validator.dart';

final class RecipePreset {
  const RecipePreset._(this.id, this.recipe, this._keywords);

  /// Identificador estable (no se traduce).
  final String id;
  final MakeupRecipe recipe;

  /// Palabras clave en minúsculas y sin acentos (es/en/pt/fr).
  final List<String> _keywords;
}

abstract final class RecipePresets {
  static const String fallbackId = 'natural';

  static final List<RecipePreset> all = List.unmodifiable([
    for (final entry in _definitions) _build(entry),
  ]);

  static RecipePreset byId(String id) =>
      all.firstWhere((preset) => preset.id == id, orElse: () => all.firstWhere((p) => p.id == fallbackId));

  /// Preset más cercano a [prompt] por palabras clave; [fallbackId] si ninguna
  /// coincide. Determinista: ante empate gana el primero de [all].
  ///
  /// Una palabra clave simple coincide si alguna palabra del prompt empieza
  /// con ella ("gotico" → "góticos"); una con espacios, si aparece tal cual.
  static RecipePreset closestTo(String prompt) {
    final normalized = _normalize(prompt);
    final words = normalized.split(_nonLetters).where((w) => w.isNotEmpty).toList(growable: false);
    RecipePreset? best;
    var bestScore = 0;
    for (final preset in all) {
      var score = 0;
      for (final keyword in preset._keywords) {
        final matches = keyword.contains(' ')
            ? normalized.contains(keyword)
            : words.any((word) => word.startsWith(keyword));
        if (matches) score++;
      }
      if (score > bestScore) {
        best = preset;
        bestScore = score;
      }
    }
    return best ?? byId(fallbackId);
  }

  static RecipePreset _build(_PresetDefinition definition) {
    final result = const RecipeValidator().validate(definition.json);
    final recipe = result.recipe;
    if (recipe == null) {
      throw StateError('Preset "${definition.id}" inválido: ${result.errors.join('; ')}');
    }
    return RecipePreset._(definition.id, recipe, definition.keywords);
  }

  static final RegExp _nonLetters = RegExp(r'[^a-z0-9-]+');

  static const Map<String, String> _accents = {
    'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a',
    'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
    'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
    'ó': 'o', 'ò': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o',
    'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
    'ç': 'c', 'ñ': 'n',
  };

  static String _normalize(String text) {
    final buffer = StringBuffer();
    for (final char in text.toLowerCase().split('')) {
      buffer.write(_accents[char] ?? char);
    }
    return buffer.toString();
  }

  static const List<_PresetDefinition> _definitions = [
    _PresetDefinition(
      id: 'natural',
      keywords: ['natural', 'nude', 'sutil', 'subtle', 'suave', 'soft', 'day', 'diario', 'everyday', 'sin maquillaje', 'no-makeup', 'no makeup', 'leve', 'naturel', 'leger'],
      json: {
        'schema': kMakeupRecipeSchemaV2,
        'name': 'Natural',
        'lips': {'color': '#B9786E', 'opacity': 0.6, 'finish': 'satin', 'gloss': 0.2, 'lumaFollow': 0.2},
        'cheeks': {'color': '#E39A8C', 'opacity': 0.2, 'spread': 0.7, 'placement': 'apple'},
        'eyes': {
          'shadow': [
            {'color': '#A57B66', 'opacity': 0.25, 'region': 'lid', 'finish': 'matte'},
          ],
          'lashes': {'opacity': 0.5, 'length': 0.4, 'volume': 0.3},
        },
      },
    ),
    _PresetDefinition(
      id: 'classic_red',
      keywords: ['rojo', 'red', 'vermelho', 'rouge', 'clasico', 'classic', 'classico', 'classique', 'noche', 'night', 'elegante', 'elegant'],
      json: {
        'schema': kMakeupRecipeSchemaV2,
        'name': 'Rojo clásico',
        'lips': {'color': '#B3122D', 'opacity': 0.85, 'finish': 'satin', 'gloss': 0.3, 'lumaFollow': 0.35},
        'cheeks': {'color': '#E8837A', 'opacity': 0.25, 'spread': 0.7},
        'eyes': {
          'liner': {'color': '#111111', 'opacity': 0.9, 'thickness': 0.5, 'wing': 0.4},
          'lashes': {'opacity': 0.8, 'length': 0.6, 'volume': 0.6},
        },
      },
    ),
    _PresetDefinition(
      id: 'gothic',
      keywords: ['gotico', 'gothic', 'goth', 'gotique', 'oscuro', 'dark', 'escuro', 'sombre', 'negro', 'black', 'preto', 'noir', 'vampiro', 'vampire', 'bordo', 'burgundy'],
      json: {
        'schema': kMakeupRecipeSchemaV2,
        'name': 'Gótico',
        'lips': {'color': '#3B0A1E', 'opacity': 0.9, 'finish': 'matte', 'gloss': 0.0, 'lumaFollow': 0.5},
        'eyes': {
          'shadow': [
            {'color': '#2B1B2E', 'opacity': 0.6, 'region': 'lid', 'finish': 'matte'},
            {'color': '#120A12', 'opacity': 0.55, 'region': 'outer_v', 'finish': 'matte'},
          ],
          'liner': {'color': '#000000', 'opacity': 1.0, 'thickness': 0.7, 'wing': 0.6},
          'lashes': {'opacity': 0.9, 'length': 0.7, 'volume': 0.8},
        },
        'skin': {
          'contour': {'color': '#6E5A5A', 'opacity': 0.3},
        },
      },
    ),
    _PresetDefinition(
      id: 'golden_glam',
      keywords: ['glam', 'dorado', 'gold', 'golden', 'dourado', 'dore', 'brillo', 'glitter', 'brilho', 'paillettes', 'fiesta', 'party', 'festa', 'fete', 'shimmer'],
      json: {
        'schema': kMakeupRecipeSchemaV2,
        'name': 'Glam dorado',
        'lips': {'color': '#A4544A', 'opacity': 0.75, 'finish': 'gloss', 'gloss': 0.6, 'lumaFollow': 0.25},
        'cheeks': {'color': '#D9826B', 'opacity': 0.3, 'spread': 0.6, 'placement': 'high'},
        'eyes': {
          'shadow': [
            {'color': '#C9A15A', 'opacity': 0.5, 'region': 'lid', 'finish': 'shimmer'},
            {'color': '#6B4423', 'opacity': 0.45, 'region': 'crease', 'finish': 'matte'},
            {'color': '#F1D9A6', 'opacity': 0.4, 'region': 'inner_corner', 'finish': 'shimmer'},
          ],
          'liner': {'color': '#2A1A12', 'opacity': 0.85, 'thickness': 0.4, 'wing': 0.3},
          'lashes': {'opacity': 0.85, 'length': 0.6, 'volume': 0.7},
        },
        'skin': {
          'highlight': {'color': '#F6E3C2', 'opacity': 0.35},
        },
        'effects': [
          {'type': 'glitter', 'intensity': 0.3, 'region': 'eyes'},
        ],
      },
    ),
    _PresetDefinition(
      id: 'fresh_pink',
      keywords: ['rosa', 'pink', 'rose', 'fresco', 'fresh', 'frais', 'romantico', 'romantic', 'romantique', 'primavera', 'spring', 'printemps', 'chicle', 'gloss', 'brillante', 'glossy'],
      json: {
        'schema': kMakeupRecipeSchemaV2,
        'name': 'Rosado fresco',
        'lips': {'color': '#D9607E', 'opacity': 0.7, 'finish': 'gloss', 'gloss': 0.7, 'lumaFollow': 0.2},
        'cheeks': {'color': '#F08A9B', 'opacity': 0.32, 'spread': 0.75, 'placement': 'apple'},
        'eyes': {
          'shadow': [
            {'color': '#D9A0A8', 'opacity': 0.3, 'region': 'lid', 'finish': 'satin'},
          ],
          'lashes': {'opacity': 0.6, 'length': 0.5, 'volume': 0.4},
        },
        'effects': [
          {'type': 'sheen', 'intensity': 0.25, 'region': 'cheeks_nose'},
        ],
      },
    ),
  ];
}

final class _PresetDefinition {
  const _PresetDefinition({required this.id, required this.keywords, required this.json});

  final String id;
  final List<String> keywords;
  final Map<String, Object?> json;
}

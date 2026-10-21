import 'package:flutter/material.dart';

import 'package:ar_makeup_app/features/ar/domain/makeup_recipe.dart';

/// Portada de un look del catálogo: la imagen cargada por el admin o, si no
/// tiene (o no carga), un degradé con los colores de la receta. Antes se usaba
/// una foto de Unsplash: cada apertura del catálogo le pedía una imagen a un
/// servicio externo.
class LookCover extends StatelessWidget {
  const LookCover({super.key, required this.imageUrl, required this.recipe, this.height = 350});

  final String? imageUrl;
  final MakeupRecipe? recipe;
  final double height;

  /// Colores de la receta para el degradé: labios, rubor y sombras (hasta 3).
  static List<Color> coverColors(MakeupRecipe? recipe) {
    if (recipe == null) return const [];
    final colors = <RecipeColor>[
      ?recipe.lips?.color,
      ?recipe.cheeks?.color,
      for (final layer in recipe.eyes?.shadow ?? const <EyeShadowLayer>[]) layer.color,
    ];
    return [for (final color in colors.take(3)) Color(0xFF000000 | color.rgb)];
  }

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    final placeholder = _placeholder();
    if (url == null || !(url.startsWith('https://') || url.startsWith('http://'))) return placeholder;
    return Image.network(
      url,
      height: height,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => placeholder,
    );
  }

  Widget _placeholder() {
    final colors = coverColors(recipe);
    final gradient = switch (colors.length) {
      0 => const [Color(0xFFF5EFE6), Color(0xFFE8D9C5)],
      1 => [colors.first.withValues(alpha: 0.55), colors.first],
      _ => colors,
    };
    return Container(
      key: const ValueKey('look-cover-placeholder'),
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: gradient),
      ),
      child: Icon(Icons.auto_awesome, size: 48, color: Colors.white.withValues(alpha: 0.85)),
    );
  }
}

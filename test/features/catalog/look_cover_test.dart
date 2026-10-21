import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ar_makeup_app/features/ar/domain/makeup_recipe.dart';
import 'package:ar_makeup_app/features/catalog/presentation/look_cover.dart';

void main() {
  final recipe = MakeupRecipe(
    name: 'Rojo',
    lips: const LipsSpec(color: RecipeColor(0xB3122D), opacity: 0.8),
    cheeks: const CheeksSpec(color: RecipeColor(0xE07A7A), opacity: 0.4),
  );

  test('los colores de la portada salen de la receta (labios, rubor, sombras)', () {
    expect(LookCover.coverColors(recipe), const [Color(0xFFB3122D), Color(0xFFE07A7A)]);
    expect(LookCover.coverColors(null), isEmpty);
  });

  testWidgets('sin imagen: degradé local, sin pedir nada a la red', (tester) async {
    await tester.pumpWidget(MaterialApp(home: LookCover(imageUrl: null, recipe: recipe)));
    expect(find.byKey(const ValueKey('look-cover-placeholder')), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('una imagen que no es URL tampoco se pide', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LookCover(imageUrl: 'portada.jpg', recipe: null)));
    expect(find.byKey(const ValueKey('look-cover-placeholder')), findsOneWidget);
  });
}

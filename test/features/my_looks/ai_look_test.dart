import 'package:ar_makeup_app/features/ar/domain/makeup_recipe.dart';
import 'package:ar_makeup_app/features/my_looks/domain/ai_look.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const recipe = {
    'schema': 'makeup-recipe/2',
    'name': 'Rojo',
    'lips': {'color': '#B3122D', 'opacity': 0.85},
    'eyes': {
      'iris': {'color': '#3A7BD5', 'opacity': 0.6},
    },
  };

  test('fromMap: receta válida sí, rota o ausente no', () {
    final look = AiLook.fromMap('a', {'recipe': recipe, 'name': 'Rojo'});
    expect(look?.recipe.name, 'Rojo');
    expect(AiLook.fromMap('b', {'name': 'x'}), isNull);
    expect(AiLook.fromMap('c', {'recipe': {...recipe, 'shader': 'x'}}), isNull);
  });

  test('códigos de las callables', () {
    expect(AiLookFailure.fromCode('resource-exhausted'), AiLookFailure.full);
    expect(AiLookFailure.fromCode('not-found'), AiLookFailure.notFound);
    expect(AiLookFailure.fromCode('failed-precondition'), AiLookFailure.appCheck);
    expect(AiLookFailure.fromCode('unauthenticated'), AiLookFailure.unauthenticated);
    expect(AiLookFailure.fromCode('raro'), AiLookFailure.unknown);
  });

  test('muestras: labios, iris y sin repetir', () {
    final look = AiLook.fromMap('a', {'recipe': recipe});
    expect(look, isNotNull);
    if (look == null) return;
    expect(swatchesOf(look.recipe), [const RecipeColor(0xB3122D), const RecipeColor(0x3A7BD5)]);
    final same = MakeupRecipe(
      name: 'x',
      lips: const LipsSpec(color: RecipeColor(0x111111), opacity: 1),
      cheeks: const CheeksSpec(color: RecipeColor(0x111111), opacity: 1),
    );
    expect(swatchesOf(same), hasLength(1));
  });
}

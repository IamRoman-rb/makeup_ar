import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../shared/data/local_db/app_database.dart';
import '../../ar/domain/makeup_recipe.dart';
import '../../ar/domain/recipe_presets.dart';
import '../../studio/domain/studio_look.dart';

/// Catálogo inicial de una base nueva: un look por preset local
/// ([RecipePresets.all]), con receta para "Probar en AR" y sin tutorial.
///
/// Los ids son estables (`preset-<id>`): cuando haya servidor, el mismo preset
/// sembrado en dos teléfonos es el mismo look, no dos.
abstract final class CatalogSeed {
  static String idFor(String presetId) => 'preset-$presetId';

  static Future<void> insertPresets(AppDatabase db, {DateTime? now}) async {
    final ms = (now ?? DateTime.now()).millisecondsSinceEpoch;
    final presets = RecipePresets.all;
    await db.batch((batch) {
      batch.insertAll(db.looks, [
        for (var i = 0; i < presets.length; i++)
          LooksCompanion.insert(
            id: idFor(presets[i].id),
            name: presets[i].recipe.name,
            category: LookCategory.of(presets[i].recipe).wireName,
            recipe: Value(jsonEncode(presets[i].recipe.toJson())),
            recipeSchema: const Value(kMakeupRecipeSchemaV2),
            minEngine: const Value(kMakeupEngineVersion),
            source: Value(jsonEncode({'type': LookSourceType.manual.wireName})),
            // Enteros chicos: los presets van primero en el catálogo.
            sortOrder: Value(i),
            createdAt: ms,
            updatedAt: ms,
            // Contenido de la app, no un cambio del usuario: nada que subir.
            dirty: const Value(false),
          ),
      ]);
    });
  }
}

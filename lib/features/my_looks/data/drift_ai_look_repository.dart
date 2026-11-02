import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../shared/data/local_db/app_database.dart';
import '../../../shared/data/local_db/ids.dart';
import '../../../shared/data/local_db/json_columns.dart';
import '../../ar/domain/makeup_recipe.dart';
import '../../ar/domain/recipe_validator.dart';
import '../domain/ai_look.dart';

/// [IAiLookRepository] sobre `ai_looks`. Hace lo que hacían las callables
/// `saveAiLook` y `deleteAiLook`: valida la receta y pone el tope
/// [AiLookLimits.maxSaved] por usuario.
final class DriftAiLookRepository implements IAiLookRepository {
  DriftAiLookRepository(this._db, {required this.userId, this._clock = DateTime.now});

  final String userId;
  final AppDatabase _db;
  final DateTime Function() _clock;

  SimpleSelectStatement<$AiLooksTable, AiLookRow> _alive() =>
      _db.select(_db.aiLooks)..where((a) => a.userId.equals(userId) & a.deletedAt.isNull());

  @override
  Stream<List<AiLook>> watch() => (_alive()
        ..orderBy([(a) => OrderingTerm.desc(a.createdAt)])
        ..limit(AiLookLimits.maxSaved))
      .watch()
      .map((rows) => [
            for (final row in rows)
              ?AiLook.fromMap(
                row.id,
                {'recipe': decodeJsonColumn(row.recipe)},
                createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
              ),
          ]);

  @override
  Future<AiLookFailure?> save(MakeupRecipe recipe, {AiLookSource source = AiLookSource.prompt}) async {
    final json = recipe.toJson();
    // Misma validación que la callable: lo que se guarda vuelve a validar.
    if (const RecipeValidator().validate(json).recipe == null) return AiLookFailure.invalid;
    return _db.transaction(() async {
      final count = (await _alive().get()).length;
      if (count >= AiLookLimits.maxSaved) return AiLookFailure.full;
      final now = _clock().millisecondsSinceEpoch;
      await _db.into(_db.aiLooks).insert(AiLooksCompanion.insert(
            id: newId(),
            userId: userId,
            recipe: jsonEncode(json),
            source: source.wireName,
            createdAt: now,
            updatedAt: now,
          ));
      return null;
    });
  }

  @override
  Future<AiLookFailure?> delete(String id) async {
    final now = _clock().millisecondsSinceEpoch;
    final updated = await (_db.update(_db.aiLooks)
          ..where((a) => a.id.equals(id) & a.userId.equals(userId) & a.deletedAt.isNull()))
        .write(AiLooksCompanion(deletedAt: Value(now), updatedAt: Value(now), dirty: const Value(true)));
    return updated == 0 ? AiLookFailure.notFound : null;
  }
}

import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../shared/data/local_db/app_database.dart';
import '../../../shared/data/local_db/ids.dart';
import '../../../shared/data/local_db/json_columns.dart';
import '../domain/studio_look.dart';

/// [ILookRepository] sobre `look_drafts` y `looks`. Solo lo abre un admin
/// (el catálogo muestra el Studio solo si AppUser.isAdmin).
final class DriftLookRepository implements ILookRepository {
  DriftLookRepository(this._db, {required this.uid, this._clock = DateTime.now});

  /// Admin que guarda o publica (`createdBy`).
  final String uid;
  final AppDatabase _db;
  final DateTime Function() _clock;

  /// Tope de borradores que se listan (igual que con Firestore).
  static const int maxDrafts = 50;

  @override
  Future<String> saveDraft(StudioLook look) async {
    final now = _clock().millisecondsSinceEpoch;
    final data = look.toMap();
    final fields = LookDraftsCompanion(
      name: Value(look.name),
      category: Value(look.category.wireName),
      image: Value(look.image?.isNotEmpty == true ? look.image : null),
      recipe: Value(jsonEncode(data['recipe'])),
      recipeSchema: Value(data['recipeSchema'] as String? ?? ''),
      minEngine: Value(data['minEngine'] as int? ?? 0),
      source: Value(jsonEncode(data['source'])),
      updatedAt: Value(now),
      deletedAt: const Value(null),
      dirty: const Value(true),
    );
    final id = look.id;
    if (id != null) {
      final updated = await (_db.update(_db.lookDrafts)..where((d) => d.id.equals(id))).write(fields);
      if (updated > 0) return id;
    }
    final draftId = id ?? newId();
    await _db.into(_db.lookDrafts).insert(fields.copyWith(
          id: Value(draftId),
          createdBy: Value(uid),
          createdAt: Value(now),
        ));
    return draftId;
  }

  @override
  Future<List<StudioLook>> drafts() async {
    final rows = await (_db.select(_db.lookDrafts)
          ..where((d) => d.deletedAt.isNull())
          ..orderBy([(d) => OrderingTerm.desc(d.updatedAt)])
          ..limit(maxDrafts))
        .get();
    // Los que no validan (receta rota o de un motor más nuevo) se omiten.
    return [for (final row in rows) ?StudioLook.fromMap(row.id, _draftMap(row))];
  }

  @override
  Future<void> deleteDraft(String id) async {
    final now = _clock().millisecondsSinceEpoch;
    await (_db.update(_db.lookDrafts)..where((d) => d.id.equals(id)))
        .write(LookDraftsCompanion(deletedAt: Value(now), updatedAt: Value(now), dirty: const Value(true)));
  }

  @override
  Future<String> publish(StudioLook look) async {
    final now = _clock().millisecondsSinceEpoch;
    final data = look.toMap();
    final lookId = newId();
    await _db.transaction(() async {
      await _db.into(_db.looks).insert(LooksCompanion.insert(
            id: lookId,
            name: look.name,
            category: look.category.wireName,
            image: Value(look.image?.isNotEmpty == true ? look.image : null),
            recipe: Value(jsonEncode(data['recipe'])),
            recipeSchema: Value(data['recipeSchema'] as String?),
            minEngine: Value(data['minEngine'] as int?),
            source: Value(jsonEncode(data['source'])),
            // Mismo criterio que el editor de looks: al final del catálogo.
            sortOrder: Value(now),
            createdBy: Value(uid),
            createdAt: now,
            updatedAt: now,
          ));
      final draftId = look.id;
      if (draftId != null) await deleteDraft(draftId);
    });
    return lookId;
  }

  static Map<String, Object?> _draftMap(LookDraftRow row) => {
        'name': row.name,
        'category': row.category,
        'recipe': decodeJsonColumn(row.recipe),
        'recipeSchema': row.recipeSchema,
        'minEngine': row.minEngine,
        'source': decodeJsonColumn(row.source),
        'image': row.image,
      };
}

import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../shared/data/local_db/app_database.dart';
import '../../../shared/data/local_db/ids.dart';
import '../../../shared/data/local_db/json_columns.dart';
import '../../studio/domain/studio_look.dart';
import '../domain/catalog_look.dart';
import '../domain/catalog_order.dart';

/// [ICatalogRepository] sobre la tabla `looks`. Borrar deja lápida
/// (deleted_at) para la sincronización futura.
final class DriftCatalogRepository implements ICatalogRepository {
  DriftCatalogRepository(this._db, {this._clock = DateTime.now});

  final AppDatabase _db;
  final DateTime Function() _clock;

  SimpleSelectStatement<$LooksTable, LookRow> _alive() => _db.select(_db.looks)..where((l) => l.deletedAt.isNull());

  SimpleSelectStatement<$LooksTable, LookRow> _byId(String id) => _alive()..where((l) => l.id.equals(id));

  @override
  Stream<List<CatalogLook>> watchLooks() => _alive().watch().map((rows) => sortCatalog(
        rows.map(toCatalogLook),
        keyOf: (look) => look.sortKey,
        idOf: (look) => look.id,
      ));

  @override
  Stream<CatalogLook?> watchLook(String id) =>
      _byId(id).watchSingleOrNull().map((row) => row == null ? null : toCatalogLook(row));

  @override
  Future<CatalogLook?> look(String id) async {
    final row = await _byId(id).getSingleOrNull();
    return row == null ? null : toCatalogLook(row);
  }

  @override
  Future<String> saveTutorial(TutorialEdit edit, {String? id, required String userId}) async {
    final now = _clock().millisecondsSinceEpoch;
    final image = edit.image?.trim();
    final video = edit.videoUrl?.trim();
    final fields = LooksCompanion(
      name: Value(edit.name),
      category: Value(edit.category),
      image: Value(image == null || image.isEmpty ? null : image),
      videoUrl: Value(video == null || video.isEmpty ? null : video),
      steps: Value(jsonEncode([for (final step in edit.steps) if (!step.isEmpty) step.toJson()])),
      updatedAt: Value(now),
      dirty: const Value(true),
    );
    if (id != null) {
      final updated = await (_db.update(_db.looks)..where((l) => l.id.equals(id) & l.deletedAt.isNull())).write(fields);
      if (updated > 0) return id;
    }
    final newLookId = id ?? newId();
    await _db.into(_db.looks).insert(fields.copyWith(
          id: Value(newLookId),
          // Al final del catálogo, como hacía el editor (ms de creación).
          sortOrder: Value(now),
          createdBy: Value(userId),
          createdAt: Value(now),
        ));
    return newLookId;
  }

  @override
  Future<void> deleteLook(String id) async {
    final now = _clock().millisecondsSinceEpoch;
    await (_db.update(_db.looks)..where((l) => l.id.equals(id))).write(LooksCompanion(
      deletedAt: Value(now),
      updatedAt: Value(now),
      dirty: const Value(true),
    ));
  }

  @override
  Future<String?> videoUrl(String id) async {
    final row = await _byId(id).getSingleOrNull();
    final url = row?.videoUrl;
    return url == null || url.isEmpty ? null : url;
  }

  /// Fila → dominio. La receta pasa por [lookRecipe]: valida y respeta
  /// minEngine, igual que con Firestore.
  static CatalogLook toCatalogLook(LookRow row) {
    final steps = decodeJsonColumn(row.steps);
    return CatalogLook(
      id: row.id,
      name: row.name,
      category: row.category,
      image: row.image,
      sortKey: catalogSortKey(
        order: row.sortOrder,
        createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
      ),
      steps: steps is List ? [for (final raw in steps) ?TutorialStep.fromJson(raw)] : const [],
      recipe: lookRecipe({'recipe': decodeJsonColumn(row.recipe), 'minEngine': row.minEngine}),
    );
  }
}

/// [ISavedLooksRepository] sobre `saved_looks`. Quitar un guardado deja
/// lápida; volver a guardarlo la levanta.
final class DriftSavedLooksRepository implements ISavedLooksRepository {
  DriftSavedLooksRepository(this._db, {this._clock = DateTime.now});

  final AppDatabase _db;
  final DateTime Function() _clock;

  @override
  Stream<Set<String>> watchSavedIds(String userId) =>
      (_db.select(_db.savedLooks)..where((s) => s.userId.equals(userId) & s.deletedAt.isNull()))
          .watch()
          .map((rows) => {for (final row in rows) row.lookId});

  @override
  Future<void> toggle({required String userId, required String lookId}) => _db.transaction(() async {
        final now = _clock().millisecondsSinceEpoch;
        final existing = await (_db.select(_db.savedLooks)
              ..where((s) => s.userId.equals(userId) & s.lookId.equals(lookId)))
            .getSingleOrNull();
        if (existing != null && existing.deletedAt == null) {
          await (_db.update(_db.savedLooks)..where((s) => s.userId.equals(userId) & s.lookId.equals(lookId)))
              .write(SavedLooksCompanion(deletedAt: Value(now), updatedAt: Value(now), dirty: const Value(true)));
          return;
        }
        await _db.into(_db.savedLooks).insertOnConflictUpdate(SavedLooksCompanion.insert(
              userId: userId,
              lookId: lookId,
              createdAt: now,
              updatedAt: now,
              deletedAt: const Value(null),
              dirty: const Value(true),
            ));
      });
}

import 'dart:convert';

import 'package:ar_makeup_app/features/ar/domain/recipe_presets.dart';
import 'package:ar_makeup_app/features/ar/domain/recipe_validator.dart';
import 'package:ar_makeup_app/features/catalog/data/catalog_seed.dart';
import 'package:ar_makeup_app/shared/data/local_db/app_database.dart';
import 'package:ar_makeup_app/shared/data/local_db/ids.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

AppDatabase _memory({DatabaseSeed? seed}) => AppDatabase(NativeDatabase.memory(), seed: seed);

UsersCompanion _user(String id, String email) => UsersCompanion.insert(
      id: id,
      email: email,
      passwordHash: 'h',
      passwordSalt: 's',
      passwordIterations: 1,
      name: 'Ana',
      createdAt: 1,
      updatedAt: 1,
    );

void main() {
  test('newId: UUID v4 bien formado y sin repetir', () {
    final ids = {for (var i = 0; i < 1000; i++) newId()};
    expect(ids, hasLength(1000));
    final uuid = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$');
    expect(ids.every(uuid.hasMatch), isTrue);
  });

  test('una base nueva siembra un look por preset, con receta válida', () async {
    final db = _memory(seed: CatalogSeed.insertPresets);
    addTearDown(db.close);

    final looks = await db.select(db.looks).get();
    expect(looks, hasLength(RecipePresets.all.length));
    for (final row in looks) {
      expect(row.id, startsWith('preset-'));
      expect(row.dirty, isFalse, reason: 'contenido de la app, nada que subir');
      final recipe = row.recipe;
      expect(recipe, isNotNull);
      expect(const RecipeValidator().validate(jsonDecode(recipe ?? 'null')).recipe, isNotNull, reason: row.id);
    }
    expect(looks.map((l) => l.sortOrder).toSet(), hasLength(looks.length), reason: 'orden estable');
  });

  test('sin seed, la base arranca vacía', () async {
    final db = _memory();
    addTearDown(db.close);
    expect(await db.select(db.looks).get(), isEmpty);
  });

  test('el email es único', () async {
    final db = _memory();
    addTearDown(db.close);
    await db.into(db.users).insert(_user('u1', 'ana@mail.com'));
    await expectLater(db.into(db.users).insert(_user('u2', 'ana@mail.com')), throwsA(isA<SqliteException>()));
  });

  test('borrar un usuario borra en cascada su sesión, guardados y Mis looks', () async {
    final db = _memory();
    addTearDown(db.close);
    await db.into(db.users).insert(_user('u1', 'ana@mail.com'));
    await db.into(db.users).insert(_user('u2', 'bea@mail.com'));
    await db.into(db.sessions).insert(SessionsCompanion.insert(userId: 'u1'));
    await db.into(db.savedLooks).insert(SavedLooksCompanion.insert(userId: 'u1', lookId: 'l1', createdAt: 1, updatedAt: 1));
    await db.into(db.savedLooks).insert(SavedLooksCompanion.insert(userId: 'u2', lookId: 'l1', createdAt: 1, updatedAt: 1));
    await db.into(db.aiLooks).insert(AiLooksCompanion.insert(id: 'a1', userId: 'u1', recipe: '{}', source: 'prompt', createdAt: 1, updatedAt: 1));

    await (db.delete(db.users)..where((u) => u.id.equals('u1'))).go();

    expect(await db.select(db.sessions).get(), isEmpty);
    expect((await db.select(db.savedLooks).get()).map((s) => s.userId), ['u2']);
    expect(await db.select(db.aiLooks).get(), isEmpty);
  });

  test('las referencias se aplican: no hay guardados de un usuario inexistente', () async {
    final db = _memory();
    addTearDown(db.close);
    await expectLater(
      db.into(db.savedLooks).insert(SavedLooksCompanion.insert(userId: 'nadie', lookId: 'l1', createdAt: 1, updatedAt: 1)),
      throwsA(isA<SqliteException>()),
    );
  });

  test('las filas nuevas quedan dirty (para subir) y sin lápida', () async {
    final db = _memory();
    addTearDown(db.close);
    await db.into(db.users).insert(_user('u1', 'ana@mail.com'));
    final row = await (db.select(db.users)..where((u) => u.id.equals('u1'))).getSingle();
    expect(row.dirty, isTrue);
    expect(row.deletedAt, isNull);
    expect(row.preferences, '[]');
    expect(row.isAdmin, isFalse);
  });

  test('una sola sesión: el slot es la clave', () async {
    final db = _memory();
    addTearDown(db.close);
    await db.into(db.users).insert(_user('u1', 'ana@mail.com'));
    await db.into(db.users).insert(_user('u2', 'bea@mail.com'));
    await db.into(db.sessions).insertOnConflictUpdate(SessionsCompanion.insert(userId: 'u1'));
    await db.into(db.sessions).insertOnConflictUpdate(SessionsCompanion.insert(userId: 'u2'));
    final sessions = await db.select(db.sessions).get();
    expect(sessions.map((s) => s.userId), ['u2']);
    expect(sessions.single.slot, kSessionSlot);
  });
}

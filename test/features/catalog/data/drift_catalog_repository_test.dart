import 'dart:convert';

import 'package:ar_makeup_app/features/ar/domain/recipe_presets.dart';
import 'package:ar_makeup_app/features/catalog/data/catalog_seed.dart';
import 'package:ar_makeup_app/features/catalog/data/drift_catalog_repository.dart';
import 'package:ar_makeup_app/features/catalog/domain/catalog_look.dart';
import 'package:ar_makeup_app/shared/data/local_db/app_database.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late DriftCatalogRepository catalog;
  late DriftSavedLooksRepository saved;
  var now = DateTime(2026, 11, 2);

  setUp(() async {
    now = DateTime(2026, 11, 2);
    db = AppDatabase(NativeDatabase.memory(), seed: CatalogSeed.insertPresets);
    catalog = DriftCatalogRepository(db, clock: () => now);
    saved = DriftSavedLooksRepository(db, clock: () => now);
    await db.into(db.users).insert(UsersCompanion.insert(
          id: 'u1',
          email: 'ana@mail.com',
          passwordHash: 'h',
          passwordSalt: 's',
          passwordIterations: 1,
          name: 'Ana',
          createdAt: 1,
          updatedAt: 1,
        ));
  });
  tearDown(() => db.close());

  test('el catálogo sembrado trae los presets en orden y con receta', () async {
    final looks = await catalog.watchLooks().first;
    expect(looks.map((l) => l.id), [for (final p in RecipePresets.all) CatalogSeed.idFor(p.id)]);
    expect(looks.every((l) => l.recipe != null), isTrue);
    expect(looks.first.name, RecipePresets.all.first.recipe.name);
  });

  test('un tutorial nuevo va al final; editarlo conserva la receta', () async {
    const edit = TutorialEdit(
      name: 'Ojos ahumados',
      category: 'Eyes',
      image: ' https://img/portada.jpg ',
      videoUrl: 'https://video/1.mp4',
      steps: [TutorialStep(title: 'Base'), TutorialStep(), TutorialStep(description: 'Difuminar')],
    );
    final id = await catalog.saveTutorial(edit, userId: 'u1');
    var looks = await catalog.watchLooks().first;
    expect(looks.last.id, id);
    final created = await catalog.look(id);
    expect(created?.image, 'https://img/portada.jpg');
    expect(created?.steps.map((s) => s.title), ['Base', ''], reason: 'los pasos vacíos no se guardan');
    expect(await catalog.videoUrl(id), 'https://video/1.mp4');

    final presetId = CatalogSeed.idFor(RecipePresets.all.first.id);
    await catalog.saveTutorial(const TutorialEdit(name: 'Natural editado', category: 'Lips', videoUrl: ''), id: presetId, userId: 'u1');
    final edited = await catalog.look(presetId);
    expect(edited?.name, 'Natural editado');
    expect(edited?.recipe, isNotNull, reason: 'el editor no toca la receta');
    expect(await catalog.videoUrl(presetId), isNull);
    looks = await catalog.watchLooks().first;
    expect(looks.first.id, presetId, reason: 'editar no cambia el orden');
  });

  test('borrar deja lápida: desaparece del catálogo pero la fila queda para sincronizar', () async {
    final id = CatalogSeed.idFor(RecipePresets.all.first.id);
    await catalog.deleteLook(id);
    expect(await catalog.look(id), isNull);
    expect((await catalog.watchLooks().first).any((l) => l.id == id), isFalse);
    final row = await (db.select(db.looks)..where((l) => l.id.equals(id))).getSingle();
    expect(row.deletedAt, isNotNull);
    expect(row.dirty, isTrue);
  });

  test('una receta rota o de un motor más nuevo no rompe el catálogo', () async {
    await db.into(db.looks).insert(LooksCompanion.insert(
          id: 'roto',
          name: 'Roto',
          category: 'Lips',
          recipe: const Value('{no es json'),
          createdAt: 1,
          updatedAt: 1,
        ));
    await db.into(db.looks).insert(LooksCompanion.insert(
          id: 'futuro',
          name: 'Futuro',
          category: 'Lips',
          // JSON válido: solo minEngine lo deja afuera.
          recipe: Value(jsonEncode(RecipePresets.all.first.recipe.toJson())),
          minEngine: const Value(999),
          createdAt: 2,
          updatedAt: 2,
        ));
    final looks = await catalog.watchLooks().first;
    expect(looks.firstWhere((l) => l.id == 'roto').recipe, isNull);
    expect(looks.firstWhere((l) => l.id == 'futuro').recipe, isNull);
  });

  test('guardados: toggle agrega, quita (lápida) y vuelve a agregar', () async {
    final id = CatalogSeed.idFor(RecipePresets.all.first.id);
    expect(await saved.watchSavedIds('u1').first, isEmpty);
    await saved.toggle(userId: 'u1', lookId: id);
    expect(await saved.watchSavedIds('u1').first, {id});
    await saved.toggle(userId: 'u1', lookId: id);
    expect(await saved.watchSavedIds('u1').first, isEmpty);
    expect((await db.select(db.savedLooks).getSingle()).deletedAt, isNotNull);
    await saved.toggle(userId: 'u1', lookId: id);
    expect(await saved.watchSavedIds('u1').first, {id});
    expect(await db.select(db.savedLooks).get(), hasLength(1));
  });
}

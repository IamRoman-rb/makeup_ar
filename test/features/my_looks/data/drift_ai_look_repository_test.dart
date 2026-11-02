import 'package:ar_makeup_app/features/ar/domain/recipe_presets.dart';
import 'package:ar_makeup_app/features/my_looks/data/drift_ai_look_repository.dart';
import 'package:ar_makeup_app/features/my_looks/domain/ai_look.dart';
import 'package:ar_makeup_app/shared/data/local_db/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

UsersCompanion _user(String id) => UsersCompanion.insert(
      id: id,
      email: '$id@mail.com',
      passwordHash: 'h',
      passwordSalt: 's',
      passwordIterations: 1,
      name: id,
      createdAt: 1,
      updatedAt: 1,
    );

void main() {
  late AppDatabase db;
  late DriftAiLookRepository ana;
  var tick = 0;

  final red = RecipePresets.byId('classic_red').recipe;

  setUp(() async {
    tick = 0;
    db = AppDatabase(NativeDatabase.memory());
    await db.into(db.users).insert(_user('ana'));
    await db.into(db.users).insert(_user('bea'));
    // Cada guardado un ms después: el orden por fecha es determinista.
    ana = DriftAiLookRepository(db, userId: 'ana', clock: () => DateTime.fromMillisecondsSinceEpoch(++tick));
  });
  tearDown(() => db.close());

  test('guardar y ver, del más nuevo al más viejo', () async {
    expect(await ana.save(red), isNull);
    expect(await ana.save(RecipePresets.byId('natural').recipe, source: AiLookSource.remix), isNull);
    final looks = await ana.watch().first;
    expect(looks.map((l) => l.recipe.name), ['Natural', red.name]);
    expect(looks.last.createdAt, DateTime.fromMillisecondsSinceEpoch(1));
    final rows = await db.select(db.aiLooks).get();
    expect(rows.map((r) => r.source).toSet(), {'prompt', 'remix'});
  });

  test('cada usuario ve solo los suyos', () async {
    await ana.save(red);
    final bea = DriftAiLookRepository(db, userId: 'bea');
    expect(await bea.watch().first, isEmpty);
    final id = (await ana.watch().first).single.id;
    expect(await bea.delete(id), AiLookFailure.notFound, reason: 'no puede borrar uno ajeno');
  });

  test('tope de guardados', () async {
    for (var i = 0; i < AiLookLimits.maxSaved; i++) {
      expect(await ana.save(red), isNull);
    }
    expect(await ana.save(red), AiLookFailure.full);
    final first = (await ana.watch().first).first;
    expect(await ana.delete(first.id), isNull);
    expect(await ana.save(red), isNull, reason: 'borrar libera lugar');
  });

  test('borrar deja lápida y un segundo borrado da notFound', () async {
    await ana.save(red);
    final id = (await ana.watch().first).single.id;
    expect(await ana.delete(id), isNull);
    expect(await ana.watch().first, isEmpty);
    expect(await ana.delete(id), AiLookFailure.notFound);
    expect((await db.select(db.aiLooks).getSingle()).deletedAt, isNotNull);
  });
}

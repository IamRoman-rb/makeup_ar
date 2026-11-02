import 'package:ar_makeup_app/features/ar/domain/recipe_presets.dart';
import 'package:ar_makeup_app/features/catalog/data/drift_catalog_repository.dart';
import 'package:ar_makeup_app/features/studio/data/drift_look_repository.dart';
import 'package:ar_makeup_app/features/studio/domain/studio_look.dart';
import 'package:ar_makeup_app/shared/data/local_db/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late DriftLookRepository repo;
  var now = DateTime(2026, 11, 2, 10);

  final red = RecipePresets.byId('classic_red').recipe;
  final natural = RecipePresets.byId('natural').recipe;

  setUp(() {
    now = DateTime(2026, 11, 2, 10);
    db = AppDatabase(NativeDatabase.memory());
    repo = DriftLookRepository(db, uid: 'admin', clock: () => now);
  });
  tearDown(() => db.close());

  test('borradores: guardar, actualizar y listar del más reciente al más viejo', () async {
    final a = await repo.saveDraft(StudioLook(
      recipe: red,
      category: LookCategory.lips,
      sourceType: LookSourceType.prompt,
      sourcePrompt: 'labios rojos',
      image: 'https://img/a.jpg',
    ));
    now = now.add(const Duration(minutes: 1));
    final b = await repo.saveDraft(StudioLook(recipe: natural, category: LookCategory.complexion));

    var drafts = await repo.drafts();
    expect(drafts.map((d) => d.id), [b, a]);
    final first = drafts.last;
    expect(first.sourceType, LookSourceType.prompt);
    expect(first.sourcePrompt, 'labios rojos');
    expect(first.image, 'https://img/a.jpg');
    expect(first.recipe.toJson(), red.toJson());

    now = now.add(const Duration(minutes: 1));
    expect(await repo.saveDraft(first.copyWith(category: LookCategory.eyes)), a);
    drafts = await repo.drafts();
    expect(drafts.map((d) => d.id), [a, b]);
    expect(drafts.first.category, LookCategory.eyes);
  });

  test('borrar un borrador deja lápida', () async {
    final id = await repo.saveDraft(StudioLook(recipe: red, category: LookCategory.lips));
    await repo.deleteDraft(id);
    expect(await repo.drafts(), isEmpty);
    expect((await db.select(db.lookDrafts).getSingle()).deletedAt, isNotNull);
  });

  test('publicar crea el look del catálogo (con receta) y borra el borrador', () async {
    final draftId = await repo.saveDraft(StudioLook(recipe: red, category: LookCategory.lips));
    final draft = (await repo.drafts()).single;
    final lookId = await repo.publish(draft);

    expect(lookId, isNot(draftId));
    expect(await repo.drafts(), isEmpty);
    final look = await DriftCatalogRepository(db).look(lookId);
    expect(look?.name, red.name);
    expect(look?.category, 'Lips');
    expect(look?.recipe?.toJson(), red.toJson());
    expect(look?.steps, isEmpty);
    final row = await db.select(db.looks).getSingle();
    expect(row.createdBy, 'admin');
    expect(row.sortOrder, now.millisecondsSinceEpoch);
  });

  test('publicar sin borrador previo', () async {
    final lookId = await repo.publish(StudioLook(recipe: natural, category: LookCategory.complexion));
    expect(await DriftCatalogRepository(db).look(lookId), isNotNull);
  });
}

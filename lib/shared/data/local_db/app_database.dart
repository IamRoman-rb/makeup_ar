import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables.dart';

export 'tables.dart';

part 'app_database.g.dart';

/// Se llama una sola vez, al crear la base (primera apertura en el teléfono).
typedef DatabaseSeed = Future<void> Function(AppDatabase db);

/// Base local SQLite (drift). La abre AppServices al arrancar; los tests usan
/// `AppDatabase(NativeDatabase.memory())`.
@DriftDatabase(tables: [Users, Sessions, Looks, LookDrafts, SavedLooks, AiLooks])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor, {this._seed});

  /// Archivo `makeup_ar.sqlite` en la carpeta de la app, abierto en un
  /// isolate de fondo (drift_flutter): las consultas no bloquean la UI.
  factory AppDatabase.open({DatabaseSeed? seed}) =>
      AppDatabase(driftDatabase(name: 'makeup_ar'), seed: seed);

  final DatabaseSeed? _seed;

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          final seed = _seed;
          if (seed != null) await seed(this);
        },
        beforeOpen: (details) async {
          // Sin esto SQLite ignora las referencias (y el borrado en cascada).
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}

import 'package:ar_makeup_app/shared/data/local_db/app_database.dart';
import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';

/// Base en memoria para widget tests. Cierra los streams en el momento: si
/// no, drift deja un Timer pendiente al desmontar la pantalla y testWidgets
/// falla (el tiempo falso nunca lo corre).
AppDatabase memoryDatabaseForWidgets({DatabaseSeed? seed}) => AppDatabase(
      DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
      seed: seed,
    );

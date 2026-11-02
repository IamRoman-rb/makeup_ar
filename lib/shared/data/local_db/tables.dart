/// Tablas de la base local (docs/ar_engine/LOCAL_DB.md).
///
/// Fechas en ms desde epoch (UTC). Los campos JSON van como texto y se
/// validan al leer (las recetas, con RecipeValidator).
library;

import 'package:drift/drift.dart';

/// Columnas para la sincronización futura con el servidor: [updatedAt] para
/// last-write-wins, [deletedAt] como lápida (los borrados no se pierden antes
/// de subir) y [dirty] como "outbox" (cambiado localmente, sin subir).
mixin SyncColumns on Table {
  IntColumn get updatedAt => integer()();
  IntColumn get deletedAt => integer().nullable()();
  BoolColumn get dirty => boolean().withDefault(const Constant(true))();
}

/// Cuentas locales. Sin lápida: borrar la cuenta borra los datos personales.
@DataClassName('UserRow')
class Users extends Table with SyncColumns {
  TextColumn get id => text()();

  /// En minúsculas y sin espacios.
  TextColumn get email => text().unique()();

  /// PBKDF2-HMAC-SHA256 en base64, con su sal y sus iteraciones.
  TextColumn get passwordHash => text()();
  TextColumn get passwordSalt => text()();
  IntColumn get passwordIterations => integer()();

  TextColumn get name => text()();

  /// yyyy-MM-dd.
  TextColumn get birthDate => text().nullable()();
  IntColumn get age => integer().withDefault(const Constant(0))();
  TextColumn get skinType => text().withDefault(const Constant('Combined'))();
  TextColumn get skinTone => text().withDefault(const Constant('Light'))();

  /// Lista JSON de gustos ('Natural', 'Glamour'...).
  TextColumn get preferences => text().withDefault(const Constant('[]'))();

  /// Foto de perfil en la carpeta de documentos de la app.
  TextColumn get photoPath => text().nullable()();
  BoolColumn get isAdmin => boolean().withDefault(const Constant(false))();

  /// Vencimiento del VIP (entitlement de RevenueCat).
  IntColumn get premiumUntil => integer().nullable()();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Único valor de [Sessions.slot].
const String kSessionSlot = 'current';

/// Sesión abierta en el dispositivo: una sola fila ([slot] = [kSessionSlot]).
///
/// Clave de texto a propósito: una INTEGER PRIMARY KEY es alias del rowid,
/// sin valor toma uno nuevo (no el default) y habría varias sesiones.
@DataClassName('SessionRow')
class Sessions extends Table {
  TextColumn get slot => text().withDefault(const Constant(kSessionSlot))();
  TextColumn get userId => text().references(Users, #id, onDelete: KeyAction.cascade)();

  @override
  Set<Column> get primaryKey => {slot};
}

/// Catálogo: looks del editor admin y del Studio.
@DataClassName('LookRow')
class Looks extends Table with SyncColumns {
  TextColumn get id => text()();
  TextColumn get name => text()();

  /// LookCategory.wireName ('Lips', 'Eyes', 'Complexion').
  TextColumn get category => text()();
  TextColumn get image => text().nullable()();

  /// Lista JSON de pasos del tutorial ({title, image, description}).
  TextColumn get steps => text().withDefault(const Constant('[]'))();

  /// Clave de orden explícita (catalogSortKey); sin ella, [createdAt].
  IntColumn get sortOrder => integer().nullable()();

  /// Receta makeup-recipe/2 en JSON; null en looks solo de tutorial.
  TextColumn get recipe => text().nullable()();
  TextColumn get recipeSchema => text().nullable()();
  IntColumn get minEngine => integer().nullable()();

  /// Origen de la receta en JSON ({type, prompt?, model?}).
  TextColumn get source => text().nullable()();

  /// Video del tutorial (contenido VIP).
  TextColumn get videoUrl => text().nullable()();
  TextColumn get createdBy => text().nullable()();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Borradores del Studio (solo admins).
@DataClassName('LookDraftRow')
class LookDrafts extends Table with SyncColumns {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get category => text()();
  TextColumn get image => text().nullable()();
  TextColumn get recipe => text()();
  TextColumn get recipeSchema => text()();
  IntColumn get minEngine => integer()();
  TextColumn get source => text().nullable()();
  TextColumn get createdBy => text()();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Looks del catálogo que un usuario guardó. Quitar uno deja lápida.
@DataClassName('SavedLookRow')
class SavedLooks extends Table with SyncColumns {
  TextColumn get userId => text().references(Users, #id, onDelete: KeyAction.cascade)();
  TextColumn get lookId => text()();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {userId, lookId};
}

/// "Mis looks": recetas que generó y guardó un usuario final.
@DataClassName('AiLookRow')
class AiLooks extends Table with SyncColumns {
  TextColumn get id => text()();
  TextColumn get userId => text().references(Users, #id, onDelete: KeyAction.cascade)();
  TextColumn get recipe => text()();

  /// AiLookSource.wireName ('prompt' o 'remix').
  TextColumn get source => text()();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

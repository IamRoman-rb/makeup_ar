import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../shared/data/local_db/app_database.dart';
import '../../../shared/data/local_db/ids.dart';
import '../../../shared/data/local_db/json_columns.dart';
import '../domain/app_user.dart';
import '../domain/password_hasher.dart';

/// [IAuthRepository] sobre la base local: cuentas con contraseña hasheada
/// ([PasswordHasher]) y una sesión abierta por dispositivo.
final class DriftAuthRepository implements IAuthRepository {
  DriftAuthRepository(this._db, {this._hasher = const PasswordHasher(), this._clock = DateTime.now});

  final AppDatabase _db;
  final PasswordHasher _hasher;
  final DateTime Function() _clock;

  AppUser? _current;

  @override
  AppUser? get currentUser => _current;

  JoinedSelectStatement<HasResultSet, dynamic> _sessionUser() =>
      _db.select(_db.sessions).join([innerJoin(_db.users, _db.users.id.equalsExp(_db.sessions.userId))]);

  @override
  Stream<AppUser?> watchCurrentUser() => _sessionUser().watchSingleOrNull().map((row) {
        final user = row == null ? null : _toUser(row.readTable(_db.users));
        _current = user;
        return user;
      });

  @override
  Future<AppUser?> restoreSession() async {
    final row = await _sessionUser().getSingleOrNull();
    return _current = row == null ? null : _toUser(row.readTable(_db.users));
  }

  @override
  Future<AuthFailure?> signUp({required String email, required String password, required UserProfile profile}) async {
    final normalized = AuthRules.normalizeEmail(email);
    if (!AuthRules.isValidEmail(normalized)) return AuthFailure.invalidEmail;
    if (!AuthRules.isStrongEnough(password)) return AuthFailure.weakPassword;
    if (await _findByEmail(normalized) != null) return AuthFailure.emailInUse;

    // Fuera de la transacción: corre en otro isolate y tarda.
    final hash = await _hasher.hash(password);
    final now = _clock().millisecondsSinceEpoch;
    final id = newId();
    final failure = await _db.transaction(() async {
      if (await _findByEmail(normalized) != null) return AuthFailure.emailInUse;
      // Sin servidor que lo decida, la primera cuenta del dispositivo es admin.
      final isFirst = (await (_db.select(_db.users)..limit(1)).get()).isEmpty;
      await _db.into(_db.users).insert(UsersCompanion.insert(
            id: id,
            email: normalized,
            passwordHash: hash.hash,
            passwordSalt: hash.salt,
            passwordIterations: hash.iterations,
            name: profile.name,
            birthDate: Value(_date(profile.birthDate)),
            age: Value(profile.age),
            skinType: Value(profile.skinType),
            skinTone: Value(profile.skinTone),
            preferences: Value(jsonEncode(profile.preferences)),
            photoPath: Value(profile.photoPath),
            isAdmin: Value(isFirst),
            createdAt: now,
            updatedAt: now,
          ));
      await _openSession(id);
      return null;
    });
    if (failure == null) await restoreSession();
    return failure;
  }

  @override
  Future<AuthFailure?> signIn({required String email, required String password}) async {
    final row = await _findByEmail(AuthRules.normalizeEmail(email));
    if (row == null || !await _hasher.verify(password, _storedHash(row))) return AuthFailure.wrongCredentials;
    // Iteraciones viejas: se rehace el hash con las actuales (ya sabemos la contraseña).
    if (row.passwordIterations != _hasher.iterations) await _storePassword(row.id, password);
    await _openSession(row.id);
    await restoreSession();
    return null;
  }

  @override
  Future<void> signOut() async {
    await _db.delete(_db.sessions).go();
    _current = null;
  }

  @override
  Future<AuthFailure?> changePassword({required String current, required String next}) async {
    final user = _current;
    if (user == null) return AuthFailure.notSignedIn;
    final row = await _findById(user.id);
    if (row == null) return AuthFailure.notSignedIn;
    if (!await _hasher.verify(current, _storedHash(row))) return AuthFailure.wrongCredentials;
    if (!AuthRules.isStrongEnough(next)) return AuthFailure.weakPassword;
    await _storePassword(row.id, next);
    return null;
  }

  @override
  Future<AuthFailure?> updateProfile(UserProfile profile) async {
    final user = _current;
    if (user == null) return AuthFailure.notSignedIn;
    await (_db.update(_db.users)..where((u) => u.id.equals(user.id))).write(UsersCompanion(
      name: Value(profile.name),
      birthDate: Value(_date(profile.birthDate)),
      age: Value(profile.age),
      skinType: Value(profile.skinType),
      skinTone: Value(profile.skinTone),
      preferences: Value(jsonEncode(profile.preferences)),
      photoPath: Value(profile.photoPath),
      updatedAt: Value(_clock().millisecondsSinceEpoch),
      dirty: const Value(true),
    ));
    await restoreSession();
    return null;
  }

  @override
  Future<void> setPremiumUntil(DateTime? until) async {
    final user = _current;
    if (user == null) return;
    await (_db.update(_db.users)..where((u) => u.id.equals(user.id))).write(UsersCompanion(
      premiumUntil: Value(until?.millisecondsSinceEpoch),
      updatedAt: Value(_clock().millisecondsSinceEpoch),
      dirty: const Value(true),
    ));
    await restoreSession();
  }

  @override
  Future<void> deleteAccount() async {
    final user = _current;
    if (user == null) return;
    // La sesión, los guardados y Mis looks se borran en cascada.
    await (_db.delete(_db.users)..where((u) => u.id.equals(user.id))).go();
    _current = null;
  }

  Future<UserRow?> _findByEmail(String email) =>
      (_db.select(_db.users)..where((u) => u.email.equals(email))).getSingleOrNull();

  Future<UserRow?> _findById(String id) => (_db.select(_db.users)..where((u) => u.id.equals(id))).getSingleOrNull();

  Future<void> _openSession(String userId) =>
      _db.into(_db.sessions).insertOnConflictUpdate(SessionsCompanion.insert(userId: userId));

  Future<void> _storePassword(String userId, String password) async {
    final hash = await _hasher.hash(password);
    await (_db.update(_db.users)..where((u) => u.id.equals(userId))).write(UsersCompanion(
      passwordHash: Value(hash.hash),
      passwordSalt: Value(hash.salt),
      passwordIterations: Value(hash.iterations),
      updatedAt: Value(_clock().millisecondsSinceEpoch),
      dirty: const Value(true),
    ));
  }

  static PasswordHash _storedHash(UserRow row) =>
      PasswordHash(hash: row.passwordHash, salt: row.passwordSalt, iterations: row.passwordIterations);

  static String? _date(DateTime? date) => date == null ? null : formatIsoDate(date);

  static AppUser _toUser(UserRow row) {
    final premiumUntil = row.premiumUntil;
    return AppUser(
      id: row.id,
      email: row.email,
      isAdmin: row.isAdmin,
      premiumUntil: premiumUntil == null ? null : DateTime.fromMillisecondsSinceEpoch(premiumUntil),
      profile: UserProfile(
        name: row.name,
        birthDate: parseIsoDate(row.birthDate),
        age: row.age,
        skinType: row.skinType,
        skinTone: row.skinTone,
        preferences: decodeStringList(row.preferences),
        photoPath: row.photoPath,
      ),
    );
  }
}

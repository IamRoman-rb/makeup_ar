import 'dart:io';

import 'package:ar_makeup_app/features/auth/data/account_deletion.dart';
import 'package:ar_makeup_app/features/auth/data/drift_auth_repository.dart';
import 'package:ar_makeup_app/features/auth/data/profile_photo_store.dart';
import 'package:ar_makeup_app/features/auth/domain/app_user.dart';
import 'package:ar_makeup_app/features/auth/domain/password_hasher.dart';
import 'package:ar_makeup_app/shared/data/local_db/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Fotos sin decodificar: el test mira solo los archivos.
final class _FilesOnlyPhotos extends ProfilePhotoStore {
  _FilesOnlyPhotos(Directory root, {this.fail = false}) : super(baseDirectory: () async => root);

  final bool fail;

  @override
  Future<int> deleteAllFor(String userId) async {
    if (fail) throw const FileSystemException('sin permiso');
    return super.deleteAllFor(userId);
  }
}

/// Repositorio cuya transacción de borrado falla; el resto delega.
final class _FailingDelete implements IAuthRepository {
  _FailingDelete(AppDatabase db) : _inner = DriftAuthRepository(db, hasher: const PasswordHasher(iterations: 1));

  final DriftAuthRepository _inner;

  @override
  Future<void> deleteAccount() async => throw StateError('disco lleno');

  @override
  AppUser? get currentUser => _inner.currentUser;

  @override
  Stream<AppUser?> watchCurrentUser() => _inner.watchCurrentUser();

  @override
  Future<AppUser?> restoreSession() => _inner.restoreSession();

  @override
  Future<AuthFailure?> signUp({required String email, required String password, required UserProfile profile}) =>
      _inner.signUp(email: email, password: password, profile: profile);

  @override
  Future<AuthFailure?> signIn({required String email, required String password}) =>
      _inner.signIn(email: email, password: password);

  @override
  Future<void> signOut() => _inner.signOut();

  @override
  Future<AuthFailure?> changePassword({required String current, required String next}) =>
      _inner.changePassword(current: current, next: next);

  @override
  Future<AuthFailure?> updateProfile(UserProfile profile) => _inner.updateProfile(profile);

  @override
  Future<void> setPremiumUntil(DateTime? until) => _inner.setPremiumUntil(until);
}

void main() {
  late AppDatabase db;
  late Directory root;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    root = Directory.systemTemp.createTempSync('account_deletion_test');
  });
  tearDown(() async {
    await db.close();
    root.deleteSync(recursive: true);
  });

  Future<String> signUp(IAuthRepository auth) async {
    await auth.signUp(email: 'ana@mail.com', password: 'secreta', profile: const UserProfile(name: 'Ana'));
    final id = auth.currentUser?.id ?? '';
    final photos = Directory(p.join(root.path, 'profile_photos'))..createSync();
    File(p.join(photos.path, '$id-1.png')).writeAsStringSync('x');
    File(p.join(photos.path, '$id-2.png')).writeAsStringSync('x');
    return id;
  }

  test('borra la base, todas las fotos y desata RevenueCat', () async {
    final auth = DriftAuthRepository(db, hasher: const PasswordHasher(iterations: 1));
    await signUp(auth);
    var loggedOut = false;
    final result = await AccountDeletion(
      auth: auth,
      photos: _FilesOnlyPhotos(root),
      logOutPurchases: () async => loggedOut = true,
    ).run();
    expect(result, AccountDeletionResult.deleted);
    expect(await db.select(db.users).get(), isEmpty);
    expect(Directory(p.join(root.path, 'profile_photos')).listSync(), isEmpty);
    expect(loggedOut, isTrue);
  });

  test('si quedan fotos, la cuenta igual se borra y se informa', () async {
    final auth = DriftAuthRepository(db, hasher: const PasswordHasher(iterations: 1));
    await signUp(auth);
    final result = await AccountDeletion(
      auth: auth,
      photos: _FilesOnlyPhotos(root, fail: true),
      logOutPurchases: () async => false,
    ).run();
    expect(result, AccountDeletionResult.deletedWithLeftovers);
    expect(await db.select(db.users).get(), isEmpty);
  });

  test('si falla la base no se toca nada más', () async {
    final auth = _FailingDelete(db);
    await signUp(auth);
    var loggedOut = false;
    final result = await AccountDeletion(
      auth: auth,
      photos: _FilesOnlyPhotos(root),
      logOutPurchases: () async => loggedOut = true,
    ).run();
    expect(result, AccountDeletionResult.failed);
    expect(await db.select(db.users).get(), hasLength(1));
    expect(Directory(p.join(root.path, 'profile_photos')).listSync(), hasLength(2));
    expect(loggedOut, isFalse);
  });

  test('sin sesión no hace nada', () async {
    final auth = DriftAuthRepository(db, hasher: const PasswordHasher(iterations: 1));
    final result = await AccountDeletion(auth: auth, photos: _FilesOnlyPhotos(root), logOutPurchases: () async => true).run();
    expect(result, AccountDeletionResult.notSignedIn);
  });
}

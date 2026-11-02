import 'package:ar_makeup_app/features/auth/data/drift_auth_repository.dart';
import 'package:ar_makeup_app/features/auth/domain/app_user.dart';
import 'package:ar_makeup_app/features/auth/domain/password_hasher.dart';
import 'package:ar_makeup_app/shared/data/local_db/app_database.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

const _profile = UserProfile(name: 'Ana', age: 30, skinType: 'Dry', skinTone: 'Tan', preferences: ['Bold']);

void main() {
  late AppDatabase db;
  late DriftAuthRepository repo;

  DriftAuthRepository newRepo({int iterations = 1}) =>
      DriftAuthRepository(db, hasher: PasswordHasher(iterations: iterations), clock: () => DateTime(2026, 11, 2));

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = newRepo();
  });
  tearDown(() => db.close());

  group('AuthRules', () {
    test('normaliza y valida el email', () {
      expect(AuthRules.normalizeEmail('  Ana@Mail.COM '), 'ana@mail.com');
      expect(AuthRules.isValidEmail('ana@mail.com'), isTrue);
      expect(AuthRules.isValidEmail('ana@mail'), isFalse);
      expect(AuthRules.isValidEmail('ana mail.com'), isFalse);
    });

    test('contraseña de al menos 6', () {
      expect(AuthRules.isStrongEnough('12345'), isFalse);
      expect(AuthRules.isStrongEnough('123456'), isTrue);
    });
  });

  test('registro: abre sesión, guarda el perfil y la primera cuenta es admin', () async {
    expect(await repo.signUp(email: ' Ana@Mail.com', password: 'secreta', profile: _profile), isNull);
    final user = repo.currentUser;
    expect(user, isNotNull);
    expect(user?.email, 'ana@mail.com');
    expect(user?.isAdmin, isTrue);
    expect(user?.profile.skinTone, 'Tan');
    expect(user?.profile.preferences, ['Bold']);

    await repo.signOut();
    expect(await repo.signUp(email: 'bea@mail.com', password: 'secreta', profile: _profile), isNull);
    expect(repo.currentUser?.isAdmin, isFalse, reason: 'solo la primera');
  });

  test('registro: email inválido, contraseña corta y email repetido', () async {
    expect(await repo.signUp(email: 'ana', password: 'secreta', profile: _profile), AuthFailure.invalidEmail);
    expect(await repo.signUp(email: 'ana@mail.com', password: '123', profile: _profile), AuthFailure.weakPassword);
    expect(await repo.signUp(email: 'ana@mail.com', password: 'secreta', profile: _profile), isNull);
    await repo.signOut();
    expect(await repo.signUp(email: 'ANA@mail.com', password: 'otra123', profile: _profile), AuthFailure.emailInUse);
    expect(repo.currentUser, isNull);
  });

  test('login: correcto, contraseña mala y email inexistente dan el mismo error', () async {
    await repo.signUp(email: 'ana@mail.com', password: 'secreta', profile: _profile);
    await repo.signOut();
    expect(await repo.signIn(email: 'ana@mail.com', password: 'mala123'), AuthFailure.wrongCredentials);
    expect(await repo.signIn(email: 'nadie@mail.com', password: 'secreta'), AuthFailure.wrongCredentials);
    expect(repo.currentUser, isNull);
    expect(await repo.signIn(email: 'ANA@mail.com ', password: 'secreta'), isNull);
    expect(repo.currentUser?.email, 'ana@mail.com');
  });

  test('la sesión sobrevive a un "reinicio" (repositorio nuevo sobre la misma base)', () async {
    await repo.signUp(email: 'ana@mail.com', password: 'secreta', profile: _profile);
    final restarted = newRepo();
    expect(restarted.currentUser, isNull);
    expect((await restarted.restoreSession())?.email, 'ana@mail.com');
    await restarted.signOut();
    expect(await newRepo().restoreSession(), isNull);
  });

  test('login con iteraciones viejas rehace el hash con las actuales', () async {
    await repo.signUp(email: 'ana@mail.com', password: 'secreta', profile: _profile);
    await repo.signOut();
    final stronger = newRepo(iterations: 3);
    expect(await stronger.signIn(email: 'ana@mail.com', password: 'secreta'), isNull);
    final row = await db.select(db.users).getSingle();
    expect(row.passwordIterations, 3);
    await stronger.signOut();
    expect(await stronger.signIn(email: 'ana@mail.com', password: 'secreta'), isNull);
  });

  test('cambiar contraseña pide la actual', () async {
    expect(await repo.changePassword(current: 'x', next: 'nueva123'), AuthFailure.notSignedIn);
    await repo.signUp(email: 'ana@mail.com', password: 'secreta', profile: _profile);
    expect(await repo.changePassword(current: 'mala', next: 'nueva123'), AuthFailure.wrongCredentials);
    expect(await repo.changePassword(current: 'secreta', next: '123'), AuthFailure.weakPassword);
    expect(await repo.changePassword(current: 'secreta', next: 'nueva123'), isNull);
    await repo.signOut();
    expect(await repo.signIn(email: 'ana@mail.com', password: 'secreta'), AuthFailure.wrongCredentials);
    expect(await repo.signIn(email: 'ana@mail.com', password: 'nueva123'), isNull);
  });

  test('editar el perfil y el stream del usuario', () async {
    final seen = <String?>[];
    final sub = repo.watchCurrentUser().listen((user) => seen.add(user?.profile.name));
    addTearDown(sub.cancel);

    await repo.signUp(email: 'ana@mail.com', password: 'secreta', profile: _profile);
    expect(
      await repo.updateProfile(UserProfile(name: 'Ana María', birthDate: DateTime(1996, 3, 9), photoPath: '/fotos/a.jpg')),
      isNull,
    );
    expect(repo.currentUser?.profile.birthDate, DateTime(1996, 3, 9));
    expect(repo.currentUser?.profile.photoPath, '/fotos/a.jpg');
    await repo.signOut();
    await pumpEventQueue();
    expect(seen, containsAllInOrder(<String?>['Ana', 'Ana María', null]));
  });

  test('VIP: vencimiento guardado y admin siempre ve el contenido', () async {
    await repo.signUp(email: 'ana@mail.com', password: 'secreta', profile: _profile);
    await repo.signOut();
    await repo.signUp(email: 'bea@mail.com', password: 'secreta', profile: _profile);
    final now = DateTime(2026, 11, 2);
    expect(repo.currentUser?.canSeePremiumAt(now), isFalse);
    await repo.setPremiumUntil(DateTime(2026, 12, 1));
    expect(repo.currentUser?.isPremiumAt(now), isTrue);
    expect(repo.currentUser?.isPremiumAt(DateTime(2027)), isFalse, reason: 'vence solo');

    // Mismo vencimiento (refreshVip en cada arranque): no escribe ni marca dirty.
    await (db.update(db.users)..where((u) => u.email.equals('bea@mail.com')))
        .write(const UsersCompanion(dirty: Value(false)));
    await repo.setPremiumUntil(DateTime(2026, 12, 1));
    final row = await (db.select(db.users)..where((u) => u.email.equals('bea@mail.com'))).getSingle();
    expect(row.dirty, isFalse);

    await repo.signOut();
    await repo.signIn(email: 'ana@mail.com', password: 'secreta');
    expect(repo.currentUser?.canSeePremiumAt(now), isTrue, reason: 'admin');
  });

  test('borrar la cuenta borra los datos y cierra la sesión', () async {
    await repo.signUp(email: 'ana@mail.com', password: 'secreta', profile: _profile);
    await repo.deleteAccount();
    expect(repo.currentUser, isNull);
    expect(await db.select(db.users).get(), isEmpty);
    expect(await db.select(db.sessions).get(), isEmpty);
    expect(await repo.signIn(email: 'ana@mail.com', password: 'secreta'), AuthFailure.wrongCredentials);
  });
}

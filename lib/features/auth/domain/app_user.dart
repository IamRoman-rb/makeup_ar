/// Cuentas locales (docs/ar_engine/LOCAL_DB.md). Dominio puro: sin Flutter ni
/// base de datos.
library;

/// Datos del perfil que el usuario carga y edita.
final class UserProfile {
  const UserProfile({
    required this.name,
    this.birthDate,
    this.age = 0,
    this.skinType = 'Combined',
    this.skinTone = 'Light',
    this.preferences = const [],
    this.photoPath,
  });

  final String name;
  final DateTime? birthDate;
  final int age;

  /// Valores internos en inglés ('Combined', 'Light'...): se traducen al mostrar.
  final String skinType;
  final String skinTone;
  final List<String> preferences;

  /// Foto en la carpeta de documentos de la app; null sin foto.
  final String? photoPath;

  UserProfile copyWith({String? photoPath}) => UserProfile(
        name: name,
        birthDate: birthDate,
        age: age,
        skinType: skinType,
        skinTone: skinTone,
        preferences: preferences,
        photoPath: photoPath ?? this.photoPath,
      );
}

final class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.profile,
    this.isAdmin = false,
    this.premiumUntil,
  });

  final String id;
  final String email;
  final UserProfile profile;

  /// Puede usar el Studio y el editor del catálogo y ve los videos VIP. Sin
  /// servidor, lo es la primera cuenta creada en el dispositivo, y solo en
  /// builds internos ([LocalAdminPolicy]).
  final bool isAdmin;

  /// Vencimiento del VIP (entitlement de RevenueCat); null sin VIP.
  final DateTime? premiumUntil;

  bool isPremiumAt(DateTime now) {
    final until = premiumUntil;
    return until != null && until.isAfter(now);
  }

  /// Ve los videos de los tutoriales: VIP vigente o admin.
  bool canSeePremiumAt(DateTime now) => isAdmin || isPremiumAt(now);
}

/// Quién puede ser admin sin servidor (docs/compliance/LEGAL_MATRIX.md, H1).
///
/// En un build de tienda la primera cuenta de cada teléfono sería admin: vería
/// el Studio, el editor y los videos VIP sin pagar. Por eso el admin local
/// solo existe en debug y profile (medir en el E20) o con
/// `--dart-define=LOCAL_ADMIN=true` en un build interno. Cuando haya
/// servidor, el rol vuelve a decidirlo el servidor.
abstract final class LocalAdminPolicy {
  static const bool enabled =
      bool.fromEnvironment('LOCAL_ADMIN', defaultValue: !bool.fromEnvironment('dart.vm.product'));
}

/// Por qué falló una operación de la cuenta.
enum AuthFailure {
  invalidEmail,

  /// Menos de [AuthRules.minPasswordLength] caracteres.
  weakPassword,
  emailInUse,

  /// Email o contraseña incorrectos (no se distingue cuál, a propósito).
  wrongCredentials,
  notSignedIn,
}

abstract final class AuthRules {
  static const int minPasswordLength = 6;
  static final RegExp _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  /// Email normalizado: sin espacios alrededor y en minúsculas.
  static String normalizeEmail(String email) => email.trim().toLowerCase();

  static bool isValidEmail(String email) => _email.hasMatch(normalizeEmail(email));
  static bool isStrongEnough(String password) => password.length >= minPasswordLength;
}

abstract interface class IAuthRepository {
  /// Usuario con sesión abierta (el último leído); null sin sesión.
  AppUser? get currentUser;

  /// Cambios del usuario con sesión (perfil, VIP, cierre de sesión).
  Stream<AppUser?> watchCurrentUser();

  /// Lee la sesión guardada al arrancar.
  Future<AppUser?> restoreSession();

  /// Crea la cuenta y abre sesión. null si salió bien.
  Future<AuthFailure?> signUp({required String email, required String password, required UserProfile profile});

  /// null si salió bien.
  Future<AuthFailure?> signIn({required String email, required String password});

  Future<void> signOut();

  /// Pide la contraseña actual. null si salió bien.
  Future<AuthFailure?> changePassword({required String current, required String next});

  Future<AuthFailure?> updateProfile(UserProfile profile);

  /// Guarda el vencimiento del VIP que informó RevenueCat.
  Future<void> setPremiumUntil(DateTime? until);

  /// Borra la cuenta y sus datos de la base en una transacción (sesión,
  /// guardados, Mis looks, borradores del Studio; los looks que publicó
  /// quedan sin autor) y cierra la sesión. La foto de perfil es un archivo:
  /// la borra quien llama (ProfilePhotoStore.deleteAllFor).
  Future<void> deleteAccount();
}

/// Hash de contraseñas de las cuentas locales: PBKDF2-HMAC-SHA256 con sal
/// aleatoria. Dart puro, sin Flutter.
///
/// Las cuentas locales no son seguridad real (la base está en el teléfono);
/// el hash evita que la contraseña quede en claro en la base o en un backup.
/// Las iteraciones se guardan por usuario: se pueden subir más adelante sin
/// invalidar las cuentas existentes.
library;

import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

final class PasswordHash {
  const PasswordHash({required this.hash, required this.salt, required this.iterations});

  /// Base64.
  final String hash;
  final String salt;
  final int iterations;
}

final class PasswordHasher {
  const PasswordHasher({this.iterations = defaultIterations});

  /// Medir en el E20 (tiempo de login): PBKDF2 en Dart puro es lento en un
  /// núcleo de gama baja. Si pasa de ~300 ms, bajar.
  static const int defaultIterations = 20000;
  static const int saltLength = 16;
  static const int keyLength = 32;

  final int iterations;

  /// Hash nuevo con sal aleatoria. Corre en otro isolate: no traba la UI.
  Future<PasswordHash> hash(String password) {
    final salt = _randomSalt();
    final rounds = iterations;
    return Isolate.run(() => PasswordHash(
          hash: base64Encode(pbkdf2(utf8.encode(password), salt, rounds, keyLength)),
          salt: base64Encode(salt),
          iterations: rounds,
        ));
  }

  /// true si [password] corresponde a [stored]. Comparación en tiempo constante.
  Future<bool> verify(String password, PasswordHash stored) {
    final List<int> salt;
    final List<int> expected;
    try {
      salt = base64Decode(stored.salt);
      expected = base64Decode(stored.hash);
    } on FormatException {
      return Future.value(false);
    }
    final rounds = stored.iterations;
    if (rounds < 1 || expected.isEmpty) return Future.value(false);
    return Isolate.run(() => _constantTimeEquals(pbkdf2(utf8.encode(password), salt, rounds, expected.length), expected));
  }

  /// PBKDF2-HMAC-SHA256 (RFC 8018 §5.2).
  static Uint8List pbkdf2(List<int> password, List<int> salt, int iterations, int length) {
    final hmac = Hmac(sha256, password);
    final out = Uint8List(length);
    const blockSize = 32;
    final blocks = (length + blockSize - 1) ~/ blockSize;
    final saltBlock = Uint8List(salt.length + 4)..setRange(0, salt.length, salt);
    for (var block = 1; block <= blocks; block++) {
      saltBlock
        ..[salt.length] = (block >> 24) & 0xff
        ..[salt.length + 1] = (block >> 16) & 0xff
        ..[salt.length + 2] = (block >> 8) & 0xff
        ..[salt.length + 3] = block & 0xff;
      var u = hmac.convert(saltBlock).bytes;
      final t = Uint8List.fromList(u);
      for (var i = 1; i < iterations; i++) {
        u = hmac.convert(u).bytes;
        for (var j = 0; j < t.length; j++) {
          t[j] ^= u[j];
        }
      }
      final offset = (block - 1) * blockSize;
      final take = min(blockSize, length - offset);
      out.setRange(offset, offset + take, t);
    }
    return out;
  }

  static List<int> _randomSalt() {
    final random = Random.secure();
    return List<int>.generate(saltLength, (_) => random.nextInt(256), growable: false);
  }

  static bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}

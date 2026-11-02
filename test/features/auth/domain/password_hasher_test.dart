import 'dart:convert';

import 'package:ar_makeup_app/features/auth/domain/password_hasher.dart';
import 'package:flutter_test/flutter_test.dart';

String _hex(List<int> bytes) => [for (final b in bytes) b.toRadixString(16).padLeft(2, '0')].join();

void main() {
  group('PBKDF2-HMAC-SHA256 (vectores conocidos)', () {
    final password = utf8.encode('password');
    final salt = utf8.encode('salt');

    test('1 iteración', () {
      expect(
        _hex(PasswordHasher.pbkdf2(password, salt, 1, 32)),
        '120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b',
      );
    });

    test('4096 iteraciones', () {
      expect(
        _hex(PasswordHasher.pbkdf2(password, salt, 4096, 32)),
        'c5e478d59288c841aa530db6845c4c8d962893a001ce4e11a4963873aa98134a',
      );
    });

    test('largo mayor a un bloque: el primer bloque no cambia', () {
      final long = PasswordHasher.pbkdf2(password, salt, 2, 40);
      final short = PasswordHasher.pbkdf2(password, salt, 2, 32);
      expect(long.length, 40);
      expect(long.sublist(0, 32), short);
    });
  });

  group('hash y verify', () {
    const hasher = PasswordHasher(iterations: 10);

    test('la contraseña correcta verifica y la incorrecta no', () async {
      final stored = await hasher.hash('secreta123');
      expect(stored.iterations, 10);
      expect(await hasher.verify('secreta123', stored), isTrue);
      expect(await hasher.verify('secreta124', stored), isFalse);
      expect(await hasher.verify('', stored), isFalse);
    });

    test('la sal es aleatoria: la misma contraseña da otro hash', () async {
      final a = await hasher.hash('igual');
      final b = await hasher.hash('igual');
      expect(a.salt, isNot(b.salt));
      expect(a.hash, isNot(b.hash));
    });

    test('verifica con las iteraciones guardadas, no con las actuales', () async {
      final stored = await hasher.hash('vieja');
      expect(await const PasswordHasher(iterations: 99).verify('vieja', stored), isTrue);
    });

    test('datos corruptos no tiran: dan false', () async {
      const broken = PasswordHash(hash: 'no es base64!', salt: '???', iterations: 10);
      expect(await hasher.verify('x', broken), isFalse);
      const zero = PasswordHash(hash: 'AAAA', salt: 'AAAA', iterations: 0);
      expect(await hasher.verify('x', zero), isFalse);
    });
  });
}

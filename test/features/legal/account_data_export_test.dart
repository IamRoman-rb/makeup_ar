import 'dart:convert';

import 'package:ar_makeup_app/features/auth/domain/app_user.dart';
import 'package:ar_makeup_app/features/legal/domain/account_data_export.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('exporta el perfil sin hash, sal ni ruta interna de la foto', () {
    final user = AppUser(
      id: 'u1',
      email: 'ana@mail.com',
      premiumUntil: DateTime.utc(2027, 1, 1),
      profile: UserProfile(
        name: 'Ana',
        birthDate: DateTime(2000, 3, 4),
        skinType: 'Dry',
        skinTone: 'Tan',
        preferences: const ['Bold'],
        photoPath: '/data/user/0/app/files/profile_photos/u1-1.png',
      ),
    );
    final json = AccountDataExport.toJson(user, savedLooks: 2, myLooks: 1, now: DateTime.utc(2026, 11, 2));
    final map = jsonDecode(json) as Map<String, Object?>;
    expect(map['email'], 'ana@mail.com');
    expect(map['birth_date'], '2000-03-04');
    expect(map['preferences'], ['Bold']);
    expect(map['has_profile_photo'], isTrue);
    expect(map['saved_looks'], 2);
    expect(map['my_looks'], 1);
    expect(map['vip_until'], '2027-01-01T00:00:00.000Z');
    expect(json, isNot(contains('profile_photos')));
    expect(json.toLowerCase(), isNot(contains('password')));
    expect(json.toLowerCase(), isNot(contains('salt')));
  });
}

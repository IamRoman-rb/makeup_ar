import 'dart:convert';

import '../../auth/domain/app_user.dart';

/// Copia legible de los datos de la cuenta que guarda el teléfono (derecho
/// de acceso, art. 14 Ley 25.326). Nunca incluye el hash ni la sal de la
/// contraseña, ni la ruta interna de la foto.
abstract final class AccountDataExport {
  static Map<String, Object?> toMap(
    AppUser user, {
    required int savedLooks,
    required int myLooks,
    required DateTime now,
  }) {
    final profile = user.profile;
    final birthDate = profile.birthDate;
    final photo = profile.photoPath;
    final premiumUntil = user.premiumUntil;
    return {
      'exported_at': now.toUtc().toIso8601String(),
      'account_id': user.id,
      'email': user.email,
      'name': profile.name,
      'birth_date': birthDate == null ? null : _date(birthDate),
      'skin_type': profile.skinType,
      'skin_tone': profile.skinTone,
      'preferences': profile.preferences,
      'has_profile_photo': photo != null && photo.isNotEmpty,
      'vip_until': premiumUntil?.toUtc().toIso8601String(),
      'saved_looks': savedLooks,
      'my_looks': myLooks,
      'stored_on': 'this_device_only',
    };
  }

  static String toJson(AppUser user, {required int savedLooks, required int myLooks, required DateTime now}) =>
      const JsonEncoder.withIndent('  ').convert(toMap(user, savedLooks: savedLooks, myLooks: myLooks, now: now));

  static String _date(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

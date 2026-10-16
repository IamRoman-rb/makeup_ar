import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// VIP vigente según `users/{uid}` (AUDIT.md §5.2): `premium_until`, que
/// escribe solo el webhook de RevenueCat (o un admin desde la consola), es
/// posterior a [now]. `is_premium` viejo no cuenta: cualquiera lo pudo
/// escribir. Las reglas aplican lo mismo con `request.time`.
bool isPremiumUser(Map<String, dynamic>? userData, {DateTime? now}) {
  final until = switch (userData?['premium_until']) {
    final Timestamp timestamp => timestamp.toDate(),
    final DateTime date => date,
    _ => null,
  };
  return until != null && until.isAfter(now ?? DateTime.now());
}

/// Contenido pago de un look: `looks/{id}/premium/content`, que leen solo VIP
/// vigentes y admins (firestore.rules). Antes `video_url` estaba en el look,
/// de lectura pública; los looks sin migrar (no vueltos a guardar desde el
/// editor) lo siguen teniendo ahí y se usa como respaldo.
abstract final class PremiumContent {
  static DocumentReference<Map<String, dynamic>> ref(String lookId, {FirebaseFirestore? db}) =>
      (db ?? FirebaseFirestore.instance).collection('looks').doc(lookId).collection('premium').doc('content');

  /// URL del video, o null si no hay o si las reglas no lo dejan leer.
  static Future<String?> videoUrl(String lookId, {FirebaseFirestore? db}) async {
    try {
      final snapshot = await ref(lookId, db: db).get();
      final url = snapshot.data()?['video_url'];
      return url is String && url.isNotEmpty ? url : null;
    } on FirebaseException catch (e) {
      debugPrint('PremiumContent.videoUrl: ${e.code}');
      return null;
    }
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/studio_look.dart';

/// [ILookRepository] sobre Firestore. Las reglas (firestore.rules) dejan
/// leer y escribir `look_drafts` y escribir `looks` solo a admins.
final class FirestoreLookRepository implements ILookRepository {
  FirestoreLookRepository({required this.uid, FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  /// Admin que guarda o publica (`createdBy`).
  final String uid;
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _drafts => _db.collection('look_drafts');
  CollectionReference<Map<String, dynamic>> get _looks => _db.collection('looks');

  @override
  Future<String> saveDraft(StudioLook look) async {
    final id = look.id;
    final ref = id == null ? _drafts.doc() : _drafts.doc(id);
    await ref.set({
      ...look.toFirestore(),
      'createdBy': uid,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  @override
  Future<List<StudioLook>> drafts() async {
    final snapshot = await _drafts.orderBy('updatedAt', descending: true).limit(50).get();
    // Los que no validan (receta rota o de un motor más nuevo) se omiten.
    return [for (final doc in snapshot.docs) ?StudioLook.fromFirestore(doc.id, doc.data())];
  }

  @override
  Future<void> deleteDraft(String id) => _drafts.doc(id).delete();

  @override
  Future<String> publish(StudioLook look) async {
    final ref = _looks.doc();
    final batch = _db.batch()
      ..set(ref, {
        ...look.toFirestore(),
        // Lo que el catálogo y el paso a paso ya leen.
        'steps': const <Object?>[],
        'createdBy': uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
    final draftId = look.id;
    if (draftId != null) batch.delete(_drafts.doc(draftId));
    await batch.commit();
    return ref.id;
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

import '../../ar/domain/makeup_recipe.dart';
import '../../studio/data/cloud_recipe_generator.dart';
import '../domain/ai_look.dart';

/// Llamada a una callable por nombre: devuelve `result.data` o tira
/// [RecipeCallException]. Inyectable para los tests.
typedef LookCallable = Future<Object?> Function(String name, Map<String, Object?> payload);

/// [IAiLookRepository]: lee `users/{uid}/ai_looks` de Firestore (las reglas
/// dejan leer solo al dueño) y escribe por las callables `saveAiLook` /
/// `deleteAiLook` (functions/src/aiLooks.ts).
final class FirestoreAiLookRepository implements IAiLookRepository {
  FirestoreAiLookRepository({required this.uid, FirebaseFirestore? db, LookCallable? callable})
      : _db = db ?? FirebaseFirestore.instance,
        _callable = callable ?? _firebaseCallable();

  final String uid;
  final FirebaseFirestore _db;
  final LookCallable _callable;

  static LookCallable _firebaseCallable() {
    final functions = FirebaseFunctions.instanceFor(region: CloudRecipeGenerator.region);
    const emulator = String.fromEnvironment('FUNCTIONS_EMULATOR');
    final separator = emulator.lastIndexOf(':');
    if (separator > 0) {
      final port = int.tryParse(emulator.substring(separator + 1));
      // Sin el mapeo automático a 10.0.2.2 (eso es solo para el emulador de
      // Android): en el teléfono, 127.0.0.1 llega a la PC por adb reverse.
      if (port != null) {
        functions.useFunctionsEmulator(emulator.substring(0, separator), port, automaticHostMapping: false);
      }
    }
    return (name, payload) async {
      try {
        return (await functions.httpsCallable(name).call<Object?>(payload)).data;
      } on FirebaseFunctionsException catch (e) {
        throw RecipeCallException(e.code);
      }
    };
  }

  @override
  Stream<List<AiLook>> watch() => _db
      .collection('users')
      .doc(uid)
      .collection('ai_looks')
      .orderBy('createdAt', descending: true)
      .limit(AiLookLimits.maxSaved)
      .snapshots()
      .map((snapshot) => [
            for (final doc in snapshot.docs)
              ?AiLook.fromMap(doc.id, doc.data(), createdAt: (doc.data()['createdAt'] as Timestamp?)?.toDate()),
          ]);

  @override
  Future<AiLookFailure?> save(MakeupRecipe recipe, {AiLookSource source = AiLookSource.prompt}) =>
      _call('saveAiLook', {'recipe': recipe.toJson(), 'source': source.wireName});

  @override
  Future<AiLookFailure?> delete(String id) => _call('deleteAiLook', {'id': id});

  Future<AiLookFailure?> _call(String name, Map<String, Object?> payload) async {
    try {
      await _callable(name, payload);
      return null;
    } on RecipeCallException catch (e) {
      debugPrint('$name: ${e.code}');
      return AiLookFailure.fromCode(e.code);
    } catch (e) {
      debugPrint('$name: $e');
      return AiLookFailure.unavailable;
    }
  }
}

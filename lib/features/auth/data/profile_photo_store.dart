import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Fotos de perfil en la carpeta de documentos de la app (antes, Firebase
/// Storage). Las fotos no salen del teléfono.
class ProfilePhotoStore {
  ProfilePhotoStore({Future<Directory> Function()? baseDirectory})
      : _baseDirectory = baseDirectory ?? getApplicationDocumentsDirectory;

  final Future<Directory> Function() _baseDirectory;

  /// Copia [sourcePath] (lo que devolvió el selector de imágenes, que puede
  /// estar en una carpeta temporal) y devuelve la ruta nueva. El nombre lleva
  /// la hora: una foto nueva no reutiliza la imagen cacheada de la anterior.
  Future<String> save(String userId, String sourcePath) async {
    final directory = Directory(p.join((await _baseDirectory()).path, 'profile_photos'));
    await directory.create(recursive: true);
    final extension = p.extension(sourcePath).isEmpty ? '.jpg' : p.extension(sourcePath);
    final target = p.join(directory.path, '$userId-${DateTime.now().millisecondsSinceEpoch}$extension');
    await File(sourcePath).copy(target);
    return target;
  }

  /// Borra una foto vieja; no falla si ya no está.
  Future<void> delete(String? path) async {
    if (path == null || path.isEmpty) return;
    final file = File(path);
    if (await file.exists()) await file.delete();
  }
}

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Borra la copia que deja image_picker en la caché de la app después de
/// usarla. Solo borra si [path] está dentro del directorio temporal de la app:
/// nunca toca el archivo original de la galería. No falla nunca (es limpieza).
Future<void> discardPickedFile(String path, {Future<Directory> Function()? temporaryDirectory}) async {
  try {
    final file = File(path);
    if (!await file.exists()) return;
    final temp = await (temporaryDirectory ?? getTemporaryDirectory)();
    // Rutas reales: en Android /data/user/0 es un enlace a /data/data, y el
    // selector y path_provider pueden devolver una u otra.
    final tempPath = p.canonicalize(await temp.resolveSymbolicLinks());
    final filePath = p.canonicalize(await file.resolveSymbolicLinks());
    if (!p.isWithin(tempPath, filePath)) return;
    await file.delete();
  } catch (_) {
    // La caché la vacía el sistema igual; no vale la pena interrumpir al usuario.
  }
}

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Fotos de perfil en la carpeta de documentos de la app (antes, Firebase
/// Storage). Las fotos no salen del teléfono.
///
/// La foto elegida no se copia tal cual: se decodifica y se vuelve a
/// codificar en PNG de [maxSide] px como máximo. Así no quedan metadatos
/// EXIF (ubicación GPS, modelo de cámara, fecha) y el avatar no ocupa ~48 MB
/// de memoria al decodificarse (docs/compliance/DATA_INVENTORY.md).
class ProfilePhotoStore {
  ProfilePhotoStore({Future<Directory> Function()? baseDirectory, this.maxSide = 512})
      : _baseDirectory = baseDirectory ?? getApplicationDocumentsDirectory;

  final Future<Directory> Function() _baseDirectory;

  /// Lado mayor de la foto guardada, en px.
  final int maxSide;

  Future<Directory> _directory() async => Directory(p.join((await _baseDirectory()).path, 'profile_photos'));

  /// Guarda una versión limpia de [sourcePath] (lo que devolvió el selector de
  /// imágenes) y devuelve la ruta nueva. El nombre lleva la hora: una foto
  /// nueva no reutiliza la imagen cacheada de la anterior.
  Future<String> save(String userId, String sourcePath) async {
    final png = await sanitize(await File(sourcePath).readAsBytes(), maxSide: maxSide);
    final directory = await _directory();
    await directory.create(recursive: true);
    final target = p.join(directory.path, '$userId-${DateTime.now().millisecondsSinceEpoch}.png');
    await File(target).writeAsBytes(png, flush: true);
    return target;
  }

  /// Decodifica [bytes] (JPEG, PNG, HEIC... lo que soporte el motor de
  /// Flutter), achica al lado mayor [maxSide] y devuelve un PNG nuevo, sin
  /// metadatos. Tira si la imagen no se puede decodificar.
  static Future<Uint8List> sanitize(Uint8List bytes, {int maxSide = 512}) async {
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    ui.ImageDescriptor? descriptor;
    ui.Codec? codec;
    ui.Image? image;
    try {
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      final longest = math.max(descriptor.width, descriptor.height);
      final scale = longest > maxSide ? maxSide / longest : 1.0;
      codec = await descriptor.instantiateCodec(
        targetWidth: math.max(1, (descriptor.width * scale).round()),
        targetHeight: math.max(1, (descriptor.height * scale).round()),
      );
      image = (await codec.getNextFrame()).image;
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw const FormatException('No se pudo codificar la foto de perfil.');
      return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    } finally {
      image?.dispose();
      codec?.dispose();
      descriptor?.dispose();
      buffer.dispose();
    }
  }

  /// Borra una foto vieja; no falla si ya no está.
  Future<void> delete(String? path) async {
    if (path == null || path.isEmpty) return;
    final file = File(path);
    if (await file.exists()) await file.delete();
  }

  /// Borra todas las fotos de [userId] (también las que hayan quedado de un
  /// cambio de foto que falló a mitad de camino). Devuelve cuántas borró.
  Future<int> deleteAllFor(String userId) async {
    final directory = await _directory();
    if (!await directory.exists()) return 0;
    var deleted = 0;
    await for (final entity in directory.list()) {
      if (entity is File && p.basename(entity.path).startsWith('$userId-')) {
        await entity.delete();
        deleted++;
      }
    }
    return deleted;
  }
}

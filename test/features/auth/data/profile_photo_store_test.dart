import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:ar_makeup_app/features/auth/data/profile_photo_store.dart';
import 'package:ar_makeup_app/shared/data/picked_files.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// PNG de [width]x[height] dibujado con dart:ui.
Future<Uint8List> _png(int width, int height) async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(
    ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    ui.Paint()..color = const ui.Color(0xFFB3122D),
  );
  final image = await recorder.endRecording().toImage(width, height);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}

int _crc32(List<int> bytes) {
  var crc = 0xFFFFFFFF;
  for (final byte in bytes) {
    crc ^= byte;
    for (var k = 0; k < 8; k++) {
      crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xEDB88320 : crc >> 1;
    }
  }
  return crc ^ 0xFFFFFFFF;
}

/// Inserta un chunk tEXt (metadato) antes de IEND, como haría una cámara con
/// la ubicación.
Uint8List _withTextChunk(Uint8List png, String text) {
  final body = [...'tEXt'.codeUnits, ...text.codeUnits];
  final chunk = BytesBuilder()
    ..add((ByteData(4)..setUint32(0, text.length)).buffer.asUint8List())
    ..add(body)
    ..add((ByteData(4)..setUint32(0, _crc32(body))).buffer.asUint8List());
  final iend = png.length - 12;
  return Uint8List.fromList([...png.sublist(0, iend), ...chunk.takeBytes(), ...png.sublist(iend)]);
}

Future<(int, int)> _size(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  final image = (await codec.getNextFrame()).image;
  final size = (image.width, image.height);
  image.dispose();
  codec.dispose();
  return size;
}

void main() {
  late Directory root;

  setUp(() => root = Directory.systemTemp.createTempSync('photo_store_test'));
  tearDown(() => root.deleteSync(recursive: true));

  testWidgets('sanitize: achica al lado mayor y no conserva metadatos', (tester) async {
    await tester.runAsync(() async {
      final source = _withTextChunk(await _png(1200, 600), 'GPSLatitude=-34.6');
      expect(String.fromCharCodes(source), contains('GPSLatitude'));
      final clean = await ProfilePhotoStore.sanitize(source, maxSide: 300);
      expect(String.fromCharCodes(clean), isNot(contains('GPSLatitude')));
      expect(await _size(clean), (300, 150));
    });
  });

  testWidgets('save guarda un PNG limpio; deleteAllFor borra solo las fotos de ese usuario', (tester) async {
    await tester.runAsync(() async {
      final store = ProfilePhotoStore(baseDirectory: () async => root, maxSide: 64);
      final source = File(p.join(root.path, 'picked.jpg'))..writeAsBytesSync(await _png(200, 200));
      final mine = await store.save('u1', source.path);
      await store.save('u1', source.path);
      final other = await store.save('u2', source.path);
      expect(p.extension(mine), '.png');
      expect(await _size(File(mine).readAsBytesSync()), (64, 64));

      expect(await store.deleteAllFor('u1'), 2);
      expect(File(mine).existsSync(), isFalse);
      expect(File(other).existsSync(), isTrue);
      expect(await store.deleteAllFor('nadie'), 0);
    });
  });

  test('discardPickedFile borra solo dentro del directorio temporal', () async {
    final temp = Directory(p.join(root.path, 'cache'))..createSync();
    final inside = File(p.join(temp.path, 'image_picker_1.jpg'))..writeAsStringSync('x');
    final outside = File(p.join(root.path, 'DCIM.jpg'))..writeAsStringSync('x');
    await discardPickedFile(inside.path, temporaryDirectory: () async => temp);
    await discardPickedFile(outside.path, temporaryDirectory: () async => temp);
    expect(inside.existsSync(), isFalse);
    expect(outside.existsSync(), isTrue);
  });
}

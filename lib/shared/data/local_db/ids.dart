import 'dart:math';

final Random _random = Random.secure();

/// UUID v4 aleatorio (RFC 4122), para los ids de la base local: no chocan
/// cuando más adelante se mezclen con los de otros dispositivos en el servidor.
String newId() {
  final bytes = List<int>.generate(16, (_) => _random.nextInt(256), growable: false);
  bytes[6] = (bytes[6] & 0x0f) | 0x40; // versión 4
  bytes[8] = (bytes[8] & 0x3f) | 0x80; // variante RFC 4122
  final hex = [for (final b in bytes) b.toRadixString(16).padLeft(2, '0')].join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-'
      '${hex.substring(16, 20)}-${hex.substring(20)}';
}

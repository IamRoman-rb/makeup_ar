import 'dart:convert';

/// JSON de una columna de texto; null si está vacía o no es JSON válido (una
/// fila rota no tira la pantalla entera).
Object? decodeJsonColumn(String? source) {
  if (source == null || source.isEmpty) return null;
  try {
    return jsonDecode(source);
  } on FormatException {
    return null;
  }
}

/// Lista de strings guardada como JSON; vacía si no lo es.
List<String> decodeStringList(String? source) {
  final value = decodeJsonColumn(source);
  return value is List ? [for (final item in value) if (item is String) item] : const [];
}

/// Fecha `yyyy-MM-dd` (sin hora ni zona); null si no se puede leer.
DateTime? parseIsoDate(String? source) {
  if (source == null || source.length != 10) return null;
  final parts = source.split('-');
  if (parts.length != 3) return null;
  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final day = int.tryParse(parts[2]);
  if (year == null || month == null || day == null) return null;
  return DateTime(year, month, day);
}

String formatIsoDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

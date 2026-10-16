/// Orden del catálogo de looks.
///
/// El catálogo antes pedía `looks` con `orderBy('order')`, y Firestore deja
/// fuera de esa consulta a los documentos sin el campo: los looks publicados
/// desde el Studio (que no escribía `order`) no aparecían. Ahora se trae la
/// colección entera y se ordena acá, con una clave que siempre existe.
library;

/// Al final: documentos sin `order` ni `createdAt` (2^53 - 1, entero exacto
/// también en web).
const int kCatalogUnorderedKey = 9007199254740991;

/// Clave de orden de un look: `order` si es un número (el editor guarda el
/// momento de creación en ms; los looks de ejemplo, enteros chicos), si no la
/// fecha de creación en ms, y si tampoco hay, al final.
int catalogSortKey({Object? order, DateTime? createdAt}) {
  if (order is num && order.isFinite) return order.toInt();
  if (createdAt != null) return createdAt.millisecondsSinceEpoch;
  return kCatalogUnorderedKey;
}

/// Copia de [items] ordenada por [catalogSortKey]; a igual clave, por [idOf]
/// para que el orden no salte entre snapshots.
List<T> sortCatalog<T>(
  Iterable<T> items, {
  required int Function(T item) keyOf,
  required String Function(T item) idOf,
}) {
  final keyed = [for (final item in items) (key: keyOf(item), id: idOf(item), item: item)];
  keyed.sort((a, b) {
    final byKey = a.key.compareTo(b.key);
    return byKey != 0 ? byKey : a.id.compareTo(b.id);
  });
  return [for (final entry in keyed) entry.item];
}

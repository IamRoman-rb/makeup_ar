import 'package:flutter_test/flutter_test.dart';

import 'package:ar_makeup_app/features/catalog/domain/catalog_order.dart';

typedef _Look = ({String id, Object? order, DateTime? createdAt});

List<String> _sorted(List<_Look> looks) => [
      for (final look in sortCatalog(
        looks,
        keyOf: (l) => catalogSortKey(order: l.order, createdAt: l.createdAt),
        idOf: (l) => l.id,
      ))
        look.id,
    ];

void main() {
  group('catalogSortKey', () {
    test('usa order si es un número', () {
      expect(catalogSortKey(order: 3), 3);
      expect(catalogSortKey(order: 2.9), 2);
      expect(catalogSortKey(order: 5, createdAt: DateTime.utc(2026)), 5);
    });

    test('sin order (look publicado desde el Studio) usa la fecha de creación', () {
      final created = DateTime.utc(2026, 10, 16);
      expect(catalogSortKey(createdAt: created), created.millisecondsSinceEpoch);
      expect(catalogSortKey(order: 'x', createdAt: created), created.millisecondsSinceEpoch);
      expect(catalogSortKey(order: double.nan, createdAt: created), created.millisecondsSinceEpoch);
    });

    test('sin order ni fecha (escritura pendiente) va al final', () {
      expect(catalogSortKey(), kCatalogUnorderedKey);
    });
  });

  group('sortCatalog', () {
    test('los looks sin order aparecen, ordenados con el resto', () {
      final looks = <_Look>[
        (id: 'studio', order: null, createdAt: DateTime.fromMillisecondsSinceEpoch(2000000)),
        (id: 'pending', order: null, createdAt: null),
        (id: 'editor', order: 1000000, createdAt: null),
        (id: 'seed', order: 1, createdAt: null),
      ];
      expect(_sorted(looks), ['seed', 'editor', 'studio', 'pending']);
    });

    test('a igual clave desempata por id (orden estable entre snapshots)', () {
      final looks = <_Look>[
        (id: 'b', order: 7, createdAt: null),
        (id: 'a', order: 7, createdAt: null),
      ];
      expect(_sorted(looks), ['a', 'b']);
    });

    test('no modifica la lista original', () {
      final looks = <_Look>[(id: 'b', order: 2, createdAt: null), (id: 'a', order: 1, createdAt: null)];
      _sorted(looks);
      expect(looks.first.id, 'b');
    });
  });
}

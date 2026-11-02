import 'package:ar_makeup_app/features/legal/domain/legal_info.dart';
import 'package:flutter_test/flutter_test.dart';

const _complete = LegalInfo(
  controllerName: 'Empresa de Prueba SA',
  controllerTaxId: '00-00000000-0',
  controllerAddress: 'Calle Falsa 123',
  privacyEmail: 'privacidad@ejemplo.test',
  supportContact: 'soporte@ejemplo.test',
  jurisdiction: 'Ley de prueba',
  effectiveDate: '2026-11-02',
  minimumAge: 16,
);

void main() {
  group('LegalInfo', () {
    test('sin datos: todo falta, es borrador y los marcadores quedan a la vista', () {
      const info = LegalInfo();
      expect(info.missingFields, hasLength(info.fields.length));
      expect(info.isFinal, isFalse);
      final text = info.render('Responsable: {{controllerName}} ({{privacyEmail}}), {{minimumAge}} años.');
      expect(text, contains('[COMPLETAR: razón social o nombre del responsable]'));
      expect(text, contains('[COMPLETAR: email para ejercer derechos sobre datos personales]'));
      expect(text, contains('[COMPLETAR: edad mínima'));
      expect(text, isNot(contains('{{')));
    });

    test('con todos los datos pero sin revisión legal sigue siendo borrador', () {
      expect(_complete.missingFields, isEmpty);
      expect(_complete.isFinal, isFalse);
      const reviewed = LegalInfo(
        controllerName: 'Empresa de Prueba SA',
        controllerTaxId: '00-00000000-0',
        controllerAddress: 'Calle Falsa 123',
        privacyEmail: 'privacidad@ejemplo.test',
        supportContact: 'soporte@ejemplo.test',
        jurisdiction: 'Ley de prueba',
        effectiveDate: '2026-11-02',
        minimumAge: 16,
        reviewedByCounsel: true,
      );
      expect(reviewed.isFinal, isTrue);
    });

    test('reemplaza los valores y una clave desconocida queda como marcador', () {
      final text = _complete.render('{{controllerName}} · {{minimumAge}} · {{inventada}}');
      expect(text, 'Empresa de Prueba SA · 16 · [COMPLETAR: inventada]');
    });

    test('un valor con solo espacios cuenta como faltante', () {
      const info = LegalInfo(controllerName: '   ');
      expect(info.missingFields.map((f) => f.key), contains('controllerName'));
    });
  });

  group('AgePolicy', () {
    final now = DateTime(2026, 11, 2);

    test('edad cumplida según el día del cumpleaños', () {
      expect(AgePolicy.ageAt(DateTime(2010, 11, 2), now), 16);
      expect(AgePolicy.ageAt(DateTime(2010, 11, 3), now), 15);
      expect(AgePolicy.ageAt(DateTime(2010, 12, 1), now), 15);
      expect(AgePolicy.ageAt(DateTime(2030, 1, 1), now), 0);
    });

    test('sin edad mínima definida no bloquea; con edad mínima, sí', () {
      expect(AgePolicy.check(birthDate: DateTime(2020, 1, 1), now: now, minimumAge: 0), AgeCheck.allowed);
      expect(AgePolicy.check(birthDate: DateTime(2010, 11, 3), now: now, minimumAge: 16), AgeCheck.underMinimum);
      expect(AgePolicy.check(birthDate: DateTime(2010, 11, 2), now: now, minimumAge: 16), AgeCheck.allowed);
      expect(AgePolicy.check(birthDate: null, now: now, minimumAge: 16), AgeCheck.missingBirthDate);
    });
  });
}

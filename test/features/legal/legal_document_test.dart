import 'dart:io';

import 'package:ar_makeup_app/features/legal/domain/legal_document.dart';
import 'package:ar_makeup_app/features/legal/domain/legal_info.dart';
import 'package:flutter_test/flutter_test.dart';

final RegExp _marker = RegExp(r'\{\{(\w+)\}\}');

void main() {
  test('parse: título, secciones, viñetas y párrafos de varias líneas', () {
    final blocks = LegalDocuments.parse('# Título\n\nIntro\nsigue.\n\n## Sección\n\n- uno\n- dos\n\nFin');
    expect(blocks, const [
      LegalBlock(LegalBlockType.title, 'Título'),
      LegalBlock(LegalBlockType.paragraph, 'Intro sigue.'),
      LegalBlock(LegalBlockType.heading, 'Sección'),
      LegalBlock(LegalBlockType.bullet, 'uno'),
      LegalBlock(LegalBlockType.bullet, 'dos'),
      LegalBlock(LegalBlockType.paragraph, 'Fin'),
    ]);
  });

  test('idioma sin texto propio usa el español', () {
    expect(LegalDocuments.assetPath(LegalDocumentKind.terms, 'de'), 'assets/legal/terms_es.md');
    expect(LegalDocuments.assetPath(LegalDocumentKind.privacy, 'pt'), 'assets/legal/privacy_pt.md');
  });

  group('borradores en assets/legal', () {
    final keys = {for (final field in const LegalInfo().fields) field.key};

    for (final kind in LegalDocumentKind.values) {
      test('${kind.name}: los 4 idiomas existen, tienen las mismas secciones y solo marcadores conocidos', () {
        final reference = LegalDocuments.parse(File(LegalDocuments.assetPath(kind, 'es')).readAsStringSync());
        final headings = reference.where((b) => b.type == LegalBlockType.heading).length;
        for (final language in LegalDocuments.languages) {
          final text = File(LegalDocuments.assetPath(kind, language)).readAsStringSync();
          final used = {for (final m in _marker.allMatches(text)) m.group(1)};
          expect(used.difference(keys), isEmpty, reason: '$language: marcadores desconocidos');
          final blocks = LegalDocuments.parse(text);
          expect(blocks.first.type, LegalBlockType.title, reason: language);
          expect(blocks.where((b) => b.type == LegalBlockType.heading).length, headings, reason: '$language: secciones');
          // Sin datos del operador, el texto muestra los marcadores (nunca vacío).
          expect(const LegalInfo().render(text), contains('[COMPLETAR:'), reason: language);
        }
      });
    }

    test('la política describe lo que hace el código: local, sin analítica y con RevenueCat y Google Fonts', () {
      final es = File(LegalDocuments.assetPath(LegalDocumentKind.privacy, 'es')).readAsStringSync();
      expect(es, contains('solo en este teléfono'));
      expect(es, contains('RevenueCat'));
      expect(es, contains('Google Fonts'));
      expect(es, contains('no se usan para reconocer'));
      expect(es, contains('[REVISAR:'));
    });
  });
}

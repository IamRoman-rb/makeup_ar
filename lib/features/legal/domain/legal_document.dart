/// Política de privacidad y términos: plantillas en `assets/legal/` con
/// marcadores `{{clave}}` ([LegalInfo.render]) y un formato mínimo de texto
/// (`#` título, `##` sección, `- ` viñeta, línea en blanco entre párrafos).
library;

enum LegalDocumentKind { privacy, terms }

enum LegalBlockType { title, heading, paragraph, bullet }

final class LegalBlock {
  const LegalBlock(this.type, this.text);

  final LegalBlockType type;
  final String text;

  @override
  bool operator ==(Object other) => other is LegalBlock && other.type == type && other.text == text;

  @override
  int get hashCode => Object.hash(type, text);

  @override
  String toString() => '${type.name}: $text';
}

abstract final class LegalDocuments {
  /// Idiomas con texto propio; el resto usa el español (la versión que prevalece).
  static const List<String> languages = ['es', 'en', 'pt', 'fr'];
  static const String fallbackLanguage = 'es';

  static String assetPath(LegalDocumentKind kind, String languageCode) {
    final language = languages.contains(languageCode) ? languageCode : fallbackLanguage;
    return 'assets/legal/${kind.name}_$language.md';
  }

  /// Bloques del documento. Las líneas seguidas de un párrafo se unen con un
  /// espacio; una viñeta es siempre de una línea.
  static List<LegalBlock> parse(String text) {
    final blocks = <LegalBlock>[];
    final paragraph = StringBuffer();

    void flush() {
      if (paragraph.isEmpty) return;
      blocks.add(LegalBlock(LegalBlockType.paragraph, paragraph.toString()));
      paragraph.clear();
    }

    for (final raw in text.split('\n')) {
      final line = raw.trimRight();
      if (line.trim().isEmpty) {
        flush();
      } else if (line.startsWith('## ')) {
        flush();
        blocks.add(LegalBlock(LegalBlockType.heading, line.substring(3).trim()));
      } else if (line.startsWith('# ')) {
        flush();
        blocks.add(LegalBlock(LegalBlockType.title, line.substring(2).trim()));
      } else if (line.startsWith('- ')) {
        flush();
        blocks.add(LegalBlock(LegalBlockType.bullet, line.substring(2).trim()));
      } else {
        if (paragraph.isNotEmpty) paragraph.write(' ');
        paragraph.write(line.trim());
      }
    }
    flush();
    return blocks;
  }
}

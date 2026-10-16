import 'dart:convert';
import 'dart:io';

import 'package:ar_makeup_app/features/catalog/presentation/catalog_labels.dart';
import 'package:ar_makeup_app/features/profile/presentation/profile_labels.dart';
import 'package:ar_makeup_app/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> _arb(String lang) =>
    jsonDecode(File('lib/l10n/app_$lang.arb').readAsStringSync()) as Map<String, Object?>;

Set<String> _messages(Map<String, Object?> arb) => {for (final key in arb.keys) if (!key.startsWith('@')) key};

final RegExp _placeholder = RegExp(r'\{(\w+)\}');

void main() {
  const languages = ['en', 'es', 'pt', 'fr'];

  test('los 4 idiomas tienen las mismas claves, sin textos vacíos ni placeholders distintos', () {
    final template = _arb('en');
    final keys = _messages(template);
    for (final lang in languages) {
      final arb = _arb(lang);
      expect(_messages(arb), keys, reason: lang);
      for (final key in keys) {
        final text = arb[key];
        expect(text is String && text.trim().isNotEmpty, isTrue, reason: '$lang.$key vacío');
        final expected = {for (final m in _placeholder.allMatches(template[key] as String)) m.group(1)};
        final actual = {for (final m in _placeholder.allMatches(text as String)) m.group(1)};
        expect(actual, expected, reason: '$lang.$key: placeholders');
      }
    }
  });

  test('etiquetas: los valores guardados en inglés se traducen; los desconocidos quedan igual', () async {
    final es = await AppLocalizations.delegate.load(const Locale('es'));
    expect(lookCategoryLabel(es, 'Lips'), es.categoryLips);
    expect(lookCategoryLabel(es, 'complexion'), es.categoryComplexion);
    expect(lookCategoryLabel(es, 'Otra'), 'Otra');
    expect(skinTypeLabel(es, 'Oily'), 'Grasa');
    expect(skinToneLabel(es, 'Deep'), 'Oscura');
    expect(preferenceLabel(es, 'Skincare Focus'), 'Cuidado de la piel');
    expect(skinTypeLabel(es, '-'), '-');
  });
}

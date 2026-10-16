import 'package:ar_makeup_app/l10n/app_localizations.dart';

/// Etiqueta traducida de la categoría de un look. En Firestore la categoría se
/// guarda en inglés ('Lips', 'Eyes', 'Complexion'; ver kFilterCategories) y así
/// sigue: esto solo cambia lo que se muestra. Una desconocida se muestra tal cual.
String lookCategoryLabel(AppLocalizations l10n, String category) => switch (category.toLowerCase()) {
      'lips' => l10n.categoryLips,
      'eyes' => l10n.categoryEyes,
      'complexion' => l10n.categoryComplexion,
      _ => category,
    };

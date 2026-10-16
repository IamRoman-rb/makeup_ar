import 'package:ar_makeup_app/l10n/app_localizations.dart';

// Etiquetas traducidas de los datos del perfil. En users/{uid} se guardan en
// inglés (tipo_piel, tono_piel, gustos_personales) y así siguen: esto solo
// cambia lo que se muestra. Un valor desconocido se muestra tal cual.

String skinTypeLabel(AppLocalizations l10n, String value) => switch (value) {
      'Combined' => l10n.skinTypeCombined,
      'Oily' => l10n.skinTypeOily,
      'Dry' => l10n.skinTypeDry,
      'Sensitive' => l10n.skinTypeSensitive,
      _ => value,
    };

String skinToneLabel(AppLocalizations l10n, String value) => switch (value) {
      'Light' => l10n.skinToneLight,
      'Medium' => l10n.skinToneMedium,
      'Tan' => l10n.skinToneTan,
      'Deep' => l10n.skinToneDeep,
      _ => value,
    };

String preferenceLabel(AppLocalizations l10n, String value) => switch (value) {
      'Natural' => l10n.prefNatural,
      'Glamour' => l10n.prefGlamour,
      'Minimalist' => l10n.prefMinimalist,
      'Bold' => l10n.prefBold,
      'Skincare Focus' => l10n.prefSkincare,
      _ => value,
    };

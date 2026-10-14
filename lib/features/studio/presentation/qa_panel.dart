import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../domain/recipe_qa.dart';
import 'recipe_editor_panel.dart';

/// Semáforo del QA automático (F5, §10.10): un renglón por chequeo con su
/// estado y el primer motivo. Con algo en rojo, el Studio no deja publicar.
class QaPanel extends StatelessWidget {
  const QaPanel({super.key, required this.report});

  final QaReport report;

  static String kindLabel(AppLocalizations l10n, QaCheckKind kind) => switch (kind) {
        QaCheckKind.visibility => l10n.studioQaVisibility,
        QaCheckKind.clipping => l10n.studioQaClipping,
        QaCheckKind.consistency => l10n.studioQaConsistency,
        QaCheckKind.coverage => l10n.studioQaCoverage,
        QaCheckKind.cost => l10n.studioQaCost,
      };

  static String reasonText(AppLocalizations l10n, QaIssue issue) {
    final layer = issue.layer;
    final name = layer == null ? '' : RecipeEditorPanel.layerLabel(l10n, layer);
    return switch (issue.reason) {
      QaReason.invisible => l10n.studioQaInvisible(name),
      QaReason.subtle => l10n.studioQaSubtle(name),
      QaReason.washedOut => l10n.studioQaWashedOut(name),
      QaReason.chalky => l10n.studioQaChalky(name),
      QaReason.ashy => l10n.studioQaAshy(name),
      QaReason.fadesOnTone => l10n.studioQaFades(name),
      QaReason.extremeLiner => l10n.studioQaExtremeLiner,
      QaReason.maskFoundation => l10n.studioQaMaskFoundation,
      QaReason.heavyBlush => l10n.studioQaHeavyBlush,
      QaReason.effectsUnmeasured => l10n.studioQaEffects,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.studioQaTitle, style: Theme.of(context).textTheme.titleSmall),
          for (final kind in QaCheckKind.values)
            _QaRow(
              key: ValueKey('qa-${kind.name}'),
              level: report.levelOf(kind),
              label: kindLabel(l10n, kind),
              detail: switch (report.issuesOf(kind)) {
                [] => kind == QaCheckKind.cost ? l10n.studioQaCostOk : l10n.studioQaOk,
                final issues => issues.map((i) => reasonText(l10n, i)).join(' · '),
              },
            ),
          if (report.blocksPublish)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(l10n.studioQaBlocked, style: TextStyle(color: scheme.error)),
            ),
        ],
      ),
    );
  }
}

class _QaRow extends StatelessWidget {
  const _QaRow({super.key, required this.level, required this.label, required this.detail});

  final QaLevel level;
  final String label;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (level) {
      QaLevel.pass => (Icons.check_circle, Colors.green),
      QaLevel.warn => (Icons.warning_amber_rounded, Colors.amber.shade800),
      QaLevel.fail => (Icons.cancel, Theme.of(context).colorScheme.error),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 6),
          SizedBox(width: 96, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
          Expanded(child: Text(detail)),
        ],
      ),
    );
  }
}

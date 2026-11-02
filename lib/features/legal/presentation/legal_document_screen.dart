import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/app_localizations.dart';
import '../domain/legal_document.dart';
import '../domain/legal_info.dart';

/// Carga el texto de un asset (rootBundle en la app; un mapa en los tests).
typedef LegalTextLoader = Future<String> Function(String assetPath);

Future<String> _bundleLoader(String path) => rootBundle.loadString(path);

/// Política de privacidad o términos en el idioma de la app, con los datos del
/// responsable de [LegalInfo]. Mientras falten datos o la revisión legal se
/// ve el banner de BORRADOR (docs/compliance/RELEASE_CHECKLIST.md).
class LegalDocumentScreen extends StatefulWidget {
  const LegalDocumentScreen({
    super.key,
    required this.kind,
    this.info = const LegalInfo.fromEnvironment(),
    this.loader = _bundleLoader,
  });

  final LegalDocumentKind kind;
  final LegalInfo info;
  final LegalTextLoader loader;

  @override
  State<LegalDocumentScreen> createState() => _LegalDocumentScreenState();
}

class _LegalDocumentScreenState extends State<LegalDocumentScreen> {
  Future<List<LegalBlock>>? _blocks;
  String? _language;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final language = Localizations.localeOf(context).languageCode;
    if (language == _language) return;
    _language = language;
    _blocks = widget
        .loader(LegalDocuments.assetPath(widget.kind, language))
        .then((text) => LegalDocuments.parse(widget.info.render(text)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final title = switch (widget.kind) {
      LegalDocumentKind.privacy => l10n.privacyPolicy,
      LegalDocumentKind.terms => l10n.termsOfService,
    };
    return Scaffold(
      backgroundColor: const Color(0xFFFDF7F8),
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.transparent,
        foregroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
      ),
      body: FutureBuilder<List<LegalBlock>>(
        future: _blocks,
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text(l10n.legalLoadError));
          final blocks = snapshot.data;
          if (blocks == null) return const Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37)));
          return SelectionArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                if (!widget.info.isFinal) LegalDraftBanner(text: l10n.legalDraftBanner),
                for (final block in blocks) _LegalBlockView(block: block),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Aviso visible de que los textos legales son un borrador.
class LegalDraftBanner extends StatelessWidget {
  const LegalDraftBanner({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3CD),
        border: Border.all(color: const Color(0xFF8A6D00)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Color(0xFF5C4800)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: const Color(0xFF3D3000), fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegalBlockView extends StatelessWidget {
  const _LegalBlockView({required this.block});

  final LegalBlock block;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    const ink = Color(0xFF1A1A1A);
    return switch (block.type) {
      LegalBlockType.title => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Semantics(header: true, child: Text(block.text, style: theme.headlineSmall?.copyWith(color: ink))),
        ),
      LegalBlockType.heading => Padding(
          padding: const EdgeInsets.only(top: 18, bottom: 6),
          child: Semantics(
            header: true,
            child: Text(block.text, style: theme.titleMedium?.copyWith(color: ink, fontWeight: FontWeight.bold)),
          ),
        ),
      LegalBlockType.paragraph => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(block.text, style: theme.bodyMedium?.copyWith(color: ink, height: 1.45)),
        ),
      LegalBlockType.bullet => Padding(
          padding: const EdgeInsets.only(bottom: 6, left: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('•  ', style: theme.bodyMedium?.copyWith(color: ink)),
              Expanded(child: Text(block.text, style: theme.bodyMedium?.copyWith(color: ink, height: 1.45))),
            ],
          ),
        ),
    };
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app_services.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/domain/app_user.dart';
import '../../profile/presentation/account_settings_screen.dart';
import '../../profile/presentation/edit_profile_screen.dart';
import '../../profile/presentation/profile_labels.dart';
import '../../vip/presentation/manage_subscription_screen.dart';
import '../domain/account_data_export.dart';
import '../domain/legal_document.dart';
import '../domain/legal_info.dart';
import 'legal_document_screen.dart';

/// Privacidad y datos: qué guarda la app, copia de los datos (acceso),
/// accesos a corregir y borrar, documentos legales, contacto del responsable
/// y gestión de la suscripción (Ley 25.326 arts. 14–16).
class PrivacyCenterScreen extends StatelessWidget {
  const PrivacyCenterScreen({super.key, this.info = const LegalInfo.fromEnvironment()});

  final LegalInfo info;

  Future<void> _copyData(BuildContext context, AppUser user) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final saved = await AppServices.savedLooks.watchSavedIds(user.id).first;
    final mine = await AppServices.aiLooks(user.id).watch().first;
    final json = AccountDataExport.toJson(user, savedLooks: saved.length, myLooks: mine.length, now: DateTime.now());
    await Clipboard.setData(ClipboardData(text: json));
    messenger.showSnackBar(SnackBar(content: Text(l10n.privacyDataCopied)));
  }

  void _open(BuildContext context, Widget screen) =>
      Navigator.push(context, MaterialPageRoute<void>(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context).textTheme;
    const ink = Color(0xFF1A1A1A);
    final user = AppServices.auth.currentUser;
    final contact = info.fields.firstWhere((field) => field.key == 'privacyEmail').display;

    return Scaffold(
      backgroundColor: const Color(0xFFFDF7F8),
      appBar: AppBar(
        title: Text(l10n.privacyCenterTitle),
        backgroundColor: Colors.transparent,
        foregroundColor: ink,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (!info.isFinal) LegalDraftBanner(text: l10n.legalDraftBanner),
          Text(l10n.privacyCenterIntro, style: theme.bodyLarge?.copyWith(color: ink, height: 1.4)),
          if (user != null) ...[
            const SizedBox(height: 24),
            Semantics(header: true, child: Text(l10n.privacyYourData, style: theme.titleMedium?.copyWith(color: ink, fontWeight: FontWeight.bold))),
            const SizedBox(height: 8),
            _DataRow(label: l10n.email, value: user.email),
            _DataRow(label: l10n.fullName, value: user.profile.name),
            _DataRow(label: l10n.dob, value: _date(user.profile.birthDate)),
            _DataRow(label: l10n.skinTypeLabel, value: skinTypeLabel(l10n, user.profile.skinType)),
            _DataRow(label: l10n.toneLabel, value: skinToneLabel(l10n, user.profile.skinTone)),
            _DataRow(
              label: l10n.personalTastes,
              value: user.profile.preferences.isEmpty ? '—' : user.profile.preferences.map((p) => preferenceLabel(l10n, p)).join(', '),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.copy),
                  label: Text(l10n.privacyCopyData),
                  onPressed: () => _copyData(context, user),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.edit_outlined),
                  label: Text(l10n.editProfile),
                  onPressed: () => _open(context, const EditProfileScreen()),
                ),
              ],
            ),
          ],
          const SizedBox(height: 24),
          Semantics(header: true, child: Text(l10n.privacyRightsTitle, style: theme.titleMedium?.copyWith(color: ink, fontWeight: FontWeight.bold))),
          const SizedBox(height: 8),
          Text(l10n.privacyRightsBody(contact), style: theme.bodyMedium?.copyWith(color: ink, height: 1.4)),
          const SizedBox(height: 16),
          _LinkTile(icon: Icons.privacy_tip_outlined, label: l10n.privacyPolicy,
              onTap: () => _open(context, LegalDocumentScreen(kind: LegalDocumentKind.privacy, info: info))),
          _LinkTile(icon: Icons.description_outlined, label: l10n.termsOfService,
              onTap: () => _open(context, LegalDocumentScreen(kind: LegalDocumentKind.terms, info: info))),
          _LinkTile(icon: Icons.workspace_premium_outlined, label: l10n.manageSubscription,
              onTap: () => _open(context, const ManageSubscriptionScreen())),
          _LinkTile(icon: Icons.person_remove_outlined, label: l10n.deleteAccount,
              onTap: () => _open(context, const AccountSettingsScreen())),
          _LinkTile(icon: Icons.article_outlined, label: l10n.thirdPartyLicenses,
              onTap: () => showLicensePage(context: context, applicationName: l10n.appTitle)),
        ],
      ),
    );
  }

  static String _date(DateTime? date) => date == null
      ? '—'
      : '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

class _DataRow extends StatelessWidget {
  const _DataRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: MergeSemantics(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 2, child: Text(label, style: theme.bodyMedium?.copyWith(color: const Color(0xFF555555)))),
            Expanded(flex: 3, child: Text(value.isEmpty ? '—' : value, style: theme.bodyMedium?.copyWith(color: const Color(0xFF1A1A1A)))),
          ],
        ),
      ),
    );
  }
}

class _LinkTile extends StatelessWidget {
  const _LinkTile({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: const Color(0xFF444444)),
      title: Text(label, style: const TextStyle(color: Color(0xFF1A1A1A))),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

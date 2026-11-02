import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ar_makeup_app/app_services.dart';
import 'package:ar_makeup_app/features/auth/data/account_deletion.dart';
import 'package:ar_makeup_app/features/auth/presentation/auth_messages.dart';
import 'package:ar_makeup_app/features/auth/presentation/login_screen.dart';
import 'package:ar_makeup_app/l10n/app_localizations.dart'; // <-- Importación del traductor

class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  bool _deleting = false;

  /// Sin servidor no hay mail de recuperación: se cambia con la actual.
  Future<void> _changePassword() async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final passwords = await showDialog<({String current, String next})>(
      context: context,
      builder: (_) => const ChangePasswordDialog(),
    );
    if (passwords == null) return;
    final failure = await AppServices.auth.changePassword(current: passwords.current, next: passwords.next);
    if (!mounted) return;
    messenger.showSnackBar(SnackBar(
      content: Text(failure == null ? l10n.passwordChanged : authFailureText(l10n, failure), style: GoogleFonts.inter()),
      backgroundColor: failure == null ? const Color(0xFF1A1A1A) : null,
    ));
  }

  Future<void> _deleteAccountConfirmation() async {
    final l10n = AppLocalizations.of(context)!; // Traductor para el diálogo

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(l10n.deleteAccount, style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold, color: Colors.red.shade700)),
          content: Text(
            l10n.deleteAccountDesc,
            style: GoogleFonts.inter(color: Colors.grey.shade700, height: 1.5),
          ),
          actions: [
            TextButton(
              // Usamos la traducción nativa de Flutter para "Cancel"
              child: Text(MaterialLocalizations.of(context).cancelButtonLabel, style: GoogleFonts.inter(color: Colors.grey)),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
              ),
              onPressed: () async {
                Navigator.of(context).pop();
                await _performAccountDeletion();
              },
              child: Text(l10n.deleteAccount, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  /// Base, fotos y RevenueCat (AccountDeletion). Si la base falla no se
  /// borró nada y se avisa; si queda algún archivo, la cuenta igual se borró
  /// y se dice qué quedó.
  Future<void> _performAccountDeletion() async {
    if (_deleting) return;
    setState(() => _deleting = true);
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final result = await AppServices.accountDeletion().run();
    if (!mounted) return;
    setState(() => _deleting = false);
    switch (result) {
      case AccountDeletionResult.failed:
        messenger.showSnackBar(SnackBar(content: Text(l10n.deleteAccountError)));
      case AccountDeletionResult.deleted || AccountDeletionResult.deletedWithLeftovers || AccountDeletionResult.notSignedIn:
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
        if (result == AccountDeletionResult.deletedWithLeftovers) {
          messenger.showSnackBar(SnackBar(content: Text(l10n.deleteAccountPartial)));
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = AppServices.auth.currentUser;
    final l10n = AppLocalizations.of(context)!; // <-- Instancia del traductor para toda la vista

    return Scaffold(
      backgroundColor: const Color(0xFFFDF7F8),
      appBar: AppBar(
        title: Text(l10n.accountSettings, style: GoogleFonts.playfairDisplay(color: const Color(0xFF1A1A1A), fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1A1A1A)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(25.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // SECCIÓN: SEGURIDAD
            Text(l10n.security, style: GoogleFonts.playfairDisplay(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF1A1A1A))),
            const SizedBox(height: 15),

            _buildInfoRow(l10n.email, user?.email ?? 'No email'),
            const Divider(height: 30),

            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.changePassword, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w500, color: const Color(0xFF1A1A1A))),
              subtitle: Text(l10n.changePasswordDesc, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600)),
              trailing: ElevatedButton(
                onPressed: _changePassword,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF1A1A1A),
                  side: BorderSide(color: Colors.grey.shade300),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  elevation: 0,
                ),
                child: Text(l10n.changeBtn),
              ),
            ),
            // Sin sección de notificaciones: la app no manda notificaciones ni
            // mails, y unos interruptores que no hacen nada serían engañosos.
            const SizedBox(height: 50),

            // SECCIÓN: PELIGRO
            Text(l10n.dangerZone, style: GoogleFonts.playfairDisplay(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red.shade700)),
            const SizedBox(height: 15),

            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.red.shade100),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.deleteAccount, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red.shade700)),
                  const SizedBox(height: 10),
                  Text(
                    l10n.deleteAccountDesc,
                    // red.shade300 sobre red.shade50 no llegaba al contraste 4,5:1 (WCAG AA).
                    style: GoogleFonts.inter(fontSize: 13, color: Colors.red.shade900, height: 1.4),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _deleting ? null : _deleteAccountConfirmation,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red.shade700,
                        side: BorderSide(color: Colors.red.shade200),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                      ),
                      child: Text(l10n.deleteMyAccountBtn, style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return _InfoRow(label: label, value: value);
  }
}

/// Pide la contraseña actual y la nueva. Devuelve las dos, o null si se
/// canceló. La validación (largo, que la actual sea correcta) la hace el
/// repositorio.
class ChangePasswordDialog extends StatefulWidget {
  const ChangePasswordDialog({super.key});

  @override
  State<ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<ChangePasswordDialog> {
  final _current = TextEditingController();
  final _next = TextEditingController();

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(l10n.changePassword, style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const ValueKey('current-password'),
            controller: _current,
            obscureText: true,
            decoration: InputDecoration(labelText: l10n.currentPassword),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('new-password'),
            controller: _next,
            obscureText: true,
            decoration: InputDecoration(labelText: l10n.newPassword),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel, style: GoogleFonts.inter(color: Colors.grey)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A1A1A)),
          onPressed: () => Navigator.pop(context, (current: _current.text.trim(), next: _next.text.trim())),
          child: Text(l10n.changeBtn, style: GoogleFonts.inter(color: Colors.white)),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 15, color: Colors.grey.shade600)),
        const SizedBox(width: 15),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: const Color(0xFF1A1A1A)),
          ),
        ),
      ],
    );
  }
}
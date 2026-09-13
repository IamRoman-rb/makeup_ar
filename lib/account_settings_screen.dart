import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_screen.dart';
import 'l10n/app_localizations.dart'; // <-- Importación del traductor

class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  bool _pushNotifications = true;
  bool _emailNewsletters = false;

  Future<void> _sendPasswordResetEmail() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.email != null) {
      try {
        await FirebaseAuth.instance.sendPasswordResetEmail(email: user.email!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Email sent to ${user.email}', style: GoogleFonts.inter()),
              backgroundColor: const Color(0xFF1A1A1A),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error sending email', style: GoogleFonts.inter())),
          );
        }
      }
    }
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

  Future<void> _performAccountDeletion() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).delete();
        await user.delete();

        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()),
                (route) => false,
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log out and log in again before deleting your account.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.message}')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
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
                onPressed: _sendPasswordResetEmail,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF1A1A1A),
                  side: BorderSide(color: Colors.grey.shade300),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  elevation: 0,
                ),
                child: Text(l10n.sendLink),
              ),
            ),
            const SizedBox(height: 40),

            // SECCIÓN: NOTIFICACIONES
            Text(l10n.notifications, style: GoogleFonts.playfairDisplay(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF1A1A1A))),
            const SizedBox(height: 15),

            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.pushNotif, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w500)),
              subtitle: Text(l10n.pushNotifDesc, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600)),
              activeColor: const Color(0xFFD4AF37),
              value: _pushNotifications,
              onChanged: (val) => setState(() => _pushNotifications = val),
            ),
            const Divider(height: 20),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.emailNotif, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w500)),
              subtitle: Text(l10n.emailNotifDesc, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600)),
              activeColor: const Color(0xFFD4AF37),
              value: _emailNewsletters,
              onChanged: (val) => setState(() => _emailNewsletters = val),
            ),
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
                    style: GoogleFonts.inter(fontSize: 13, color: Colors.red.shade300, height: 1.4),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _deleteAccountConfirmation,
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
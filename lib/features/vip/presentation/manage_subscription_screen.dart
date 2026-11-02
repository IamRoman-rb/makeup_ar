import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/app_localizations.dart';
import '../data/vip_service.dart';

/// Cómo cancelar o gestionar el VIP (Ley 24.240 y Res. SC 316/2018: la baja
/// tiene que ser tan fácil de encontrar como el alta; App Store 3.1.2).
///
/// La suscripción vive en la tienda: la app explica los pasos y, si
/// RevenueCat lo informa, muestra el enlace de gestión para copiarlo. No se
/// abre el navegador porque eso pediría agregar url_launcher (pendiente,
/// docs/compliance/RELEASE_CHECKLIST.md).
class ManageSubscriptionScreen extends StatefulWidget {
  const ManageSubscriptionScreen({super.key, this.loadManagementUrl = VipService.managementUrl, this.isApple});

  final Future<String?> Function() loadManagementUrl;

  /// Plataforma para elegir los pasos; null = la del teléfono.
  final bool? isApple;

  @override
  State<ManageSubscriptionScreen> createState() => _ManageSubscriptionScreenState();
}

class _ManageSubscriptionScreenState extends State<ManageSubscriptionScreen> {
  late final Future<String?> _url = widget.loadManagementUrl();

  bool get _isApple => widget.isApple ?? (Platform.isIOS || Platform.isMacOS);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context).textTheme;
    const ink = Color(0xFF1A1A1A);
    return Scaffold(
      backgroundColor: const Color(0xFFFDF7F8),
      appBar: AppBar(
        title: Text(l10n.manageSubscription),
        backgroundColor: Colors.transparent,
        foregroundColor: ink,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(_isApple ? l10n.manageSubscriptionIos : l10n.manageSubscriptionAndroid,
              style: theme.bodyLarge?.copyWith(color: ink, height: 1.4)),
          const SizedBox(height: 16),
          Text(l10n.manageSubscriptionNote, style: theme.bodyMedium?.copyWith(color: ink, fontWeight: FontWeight.w600)),
          const SizedBox(height: 24),
          FutureBuilder<String?>(
            future: _url,
            builder: (context, snapshot) {
              final url = snapshot.data;
              if (url == null || url.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.manageSubscriptionLink, style: theme.titleSmall?.copyWith(color: ink)),
                  const SizedBox(height: 6),
                  SelectableText(url, style: theme.bodyMedium?.copyWith(color: ink)),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.copy),
                    label: Text(l10n.copyLink),
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      await Clipboard.setData(ClipboardData(text: url));
                      messenger.showSnackBar(SnackBar(content: Text(l10n.linkCopied)));
                    },
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

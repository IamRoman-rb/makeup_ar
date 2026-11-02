import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'package:ar_makeup_app/app_services.dart';
import 'package:ar_makeup_app/features/legal/domain/legal_document.dart';
import 'package:ar_makeup_app/features/legal/presentation/legal_document_screen.dart';
import 'package:ar_makeup_app/features/vip/data/vip_service.dart';
import 'package:ar_makeup_app/features/vip/domain/subscription_terms.dart';
import 'package:ar_makeup_app/features/vip/presentation/manage_subscription_screen.dart';
import 'package:ar_makeup_app/features/vip/presentation/subscription_texts.dart';
import 'package:ar_makeup_app/l10n/app_localizations.dart';

/// Por qué no se muestra el catálogo. El texto se arma en build: _load corre
/// desde initState, donde todavía no se puede leer AppLocalizations.
enum _PaywallError { unavailable, loadFailed }

/// Ventana de la pasarela de pago: muestra los planes VIP disponibles y
/// permite comprar uno (o restaurar una compra previa).
///
/// Antes de comprar se ve, por plan, el precio con su período y la prueba
/// gratis o el precio de introducción si la tienda los informa; abajo, el
/// aviso de renovación automática y los enlaces a términos, privacidad y
/// cómo cancelar (Ley 24.240 art. 4; App Store 3.1.2; Google Play).
class VipPaywallScreen extends StatefulWidget {
  const VipPaywallScreen({super.key});

  @override
  State<VipPaywallScreen> createState() => _VipPaywallScreenState();
}

class _VipPaywallScreenState extends State<VipPaywallScreen> {
  Offering? _offering;
  bool _isLoading = true;
  bool _isPurchasing = false;
  _PaywallError? _error;
  String _errorDetail = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!VipService.isAvailable) {
      // Build sin key de RevenueCat (env/revenuecat.json): no hay catálogo.
      setState(() {
        _isLoading = false;
        _error = _PaywallError.unavailable;
      });
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final user = AppServices.auth.currentUser;
      if (user != null) await VipService.loginUser(user.id);
      final offering = await VipService.fetchCurrentOffering();
      if (!mounted) return;
      setState(() => _offering = offering);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _PaywallError.loadFailed;
        _errorDetail = '$e';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _errorText(AppLocalizations l10n) => switch (_error) {
        _PaywallError.unavailable => l10n.vipUnavailable,
        _PaywallError.loadFailed || null => l10n.vipLoadError(_errorDetail),
      };

  Future<void> _buy(Package package) async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isPurchasing = true);
    try {
      final until = await VipService.purchase(package);
      // Sin webhook: el vencimiento que informa RevenueCat se guarda en el usuario.
      if (until != null) await AppServices.auth.setPremiumUntil(until);
      if (!mounted) return;
      if (until != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.vipPurchased), backgroundColor: Colors.green),
        );
        Navigator.pop(context, true);
      }
    } on PlatformException catch (e) {
      final code = PurchasesErrorHelper.getErrorCode(e);
      if (code != PurchasesErrorCode.purchaseCancelledError && mounted) {
        // El código, no el mensaje crudo del SDK (puede traer ids internos).
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.vipPurchaseError(code.name))),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.errorWithDetails('$e'))));
    } finally {
      if (mounted) setState(() => _isPurchasing = false);
    }
  }

  Future<void> _restore() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isPurchasing = true);
    try {
      final until = await VipService.restore();
      if (until != null) await AppServices.auth.setPremiumUntil(until);
      final isVip = until != null;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isVip ? l10n.vipRestored : l10n.vipNothingToRestore)),
      );
      if (isVip) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.errorWithDetails('$e'))));
    } finally {
      if (mounted) setState(() => _isPurchasing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Text(l10n.becomeVip, style: GoogleFonts.playfairDisplay(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37)))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_errorText(l10n), style: const TextStyle(color: Colors.white70), textAlign: TextAlign.center),
                  ),
                )
              : _buildOffering(l10n),
      bottomNavigationBar: _isLoading || _error != null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextButton(
                  onPressed: _isPurchasing ? null : _restore,
                  child: Text(l10n.vipRestore, style: const TextStyle(color: Colors.white54)),
                ),
              ),
            ),
    );
  }

  Widget _buildOffering(AppLocalizations l10n) {
    final packages = _offering?.availablePackages ?? const [];

    if (packages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            l10n.vipNoPlans,
            style: const TextStyle(color: Colors.white70),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Icon(Icons.workspace_premium, color: Color(0xFFD4AF37), size: 60),
        const SizedBox(height: 16),
        Text(
          l10n.vipHeadline,
          textAlign: TextAlign.center,
          style: GoogleFonts.playfairDisplay(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 30),
        for (final package in packages) _buildPackageTile(l10n, package),
        if (packages.any((package) => _terms(package).isAutoRenewing)) ...[
          const SizedBox(height: 8),
          Text(
            l10n.vipAutoRenewNotice(Platform.isIOS || Platform.isMacOS ? 'App Store' : 'Google Play'),
            style: GoogleFonts.inter(color: Colors.white70, fontSize: 12, height: 1.4),
          ),
        ],
        const SizedBox(height: 12),
        Wrap(
          spacing: 4,
          children: [
            _footerLink(l10n.termsOfService, () => _open(const LegalDocumentScreen(kind: LegalDocumentKind.terms))),
            _footerLink(l10n.privacyPolicy, () => _open(const LegalDocumentScreen(kind: LegalDocumentKind.privacy))),
            _footerLink(l10n.manageSubscription, () => _open(const ManageSubscriptionScreen())),
          ],
        ),
      ],
    );
  }

  void _open(Widget screen) => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => screen));

  Widget _footerLink(String label, VoidCallback onTap) => TextButton(
        onPressed: onTap,
        child: Text(label, style: const TextStyle(color: Color(0xFFD4AF37), decoration: TextDecoration.underline)),
      );

  static SubscriptionTerms _terms(Package package) {
    final product = package.storeProduct;
    final intro = product.introductoryPrice;
    return SubscriptionTerms.fromStore(
      priceString: product.priceString,
      subscriptionPeriod: product.subscriptionPeriod,
      introPrice: intro?.price,
      introPriceString: intro?.priceString,
      introPeriod: intro?.period,
      introCycles: intro?.cycles ?? 1,
    );
  }

  Widget _buildPackageTile(AppLocalizations l10n, Package package) {
    final product = package.storeProduct;
    final terms = _terms(package);
    final intro = introText(l10n, terms);
    return Card(
      color: Colors.white12,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        title: Text(product.title, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (product.description.isNotEmpty)
              Text(product.description, style: GoogleFonts.inter(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 4),
            Text(priceText(l10n, terms), style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
            if (intro != null) Text(intro, style: GoogleFonts.inter(color: const Color(0xFFD4AF37), fontSize: 13)),
          ],
        ),
        trailing: _isPurchasing
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFD4AF37)))
            : Text(product.priceString, style: GoogleFonts.inter(color: const Color(0xFFD4AF37), fontWeight: FontWeight.bold, fontSize: 16)),
        onTap: _isPurchasing ? null : () => _buy(package),
      ),
    );
  }
}

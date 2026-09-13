import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'vip_service.dart';

/// Ventana de la pasarela de pago: muestra los planes VIP disponibles y
/// permite comprar uno (o restaurar una compra previa).
class VipPaywallScreen extends StatefulWidget {
  const VipPaywallScreen({super.key});

  @override
  State<VipPaywallScreen> createState() => _VipPaywallScreenState();
}

class _VipPaywallScreenState extends State<VipPaywallScreen> {
  Offering? _offering;
  bool _isLoading = true;
  bool _isPurchasing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await VipService.loginCurrentUser();
      final offering = await VipService.fetchCurrentOffering();
      if (!mounted) return;
      setState(() => _offering = offering);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'No se pudo cargar el catálogo VIP.\n$e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _buy(Package package) async {
    setState(() => _isPurchasing = true);
    try {
      final isVip = await VipService.purchase(package);
      if (!mounted) return;
      if (isVip) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Listo, ya sos VIP! 🎉'), backgroundColor: Colors.green),
        );
        Navigator.pop(context, true);
      }
    } on PlatformException catch (e) {
      final code = PurchasesErrorHelper.getErrorCode(e);
      if (code != PurchasesErrorCode.purchaseCancelledError && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo completar la compra: ${e.message ?? code}')),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isPurchasing = false);
    }
  }

  Future<void> _restore() async {
    setState(() => _isPurchasing = true);
    try {
      final isVip = await VipService.restore();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isVip ? '¡Encontramos tu suscripción VIP! 🎉' : 'No encontramos ninguna compra para restaurar.')),
      );
      if (isVip) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isPurchasing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Text('Hazte VIP', style: GoogleFonts.playfairDisplay(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37)))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_error!, style: const TextStyle(color: Colors.white70), textAlign: TextAlign.center),
                  ),
                )
              : _buildOffering(),
      bottomNavigationBar: _isLoading || _error != null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextButton(
                  onPressed: _isPurchasing ? null : _restore,
                  child: const Text('Restaurar compras', style: TextStyle(color: Colors.white54)),
                ),
              ),
            ),
    );
  }

  Widget _buildOffering() {
    final packages = _offering?.availablePackages ?? const [];

    if (packages.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Todavía no hay ningún plan VIP configurado.',
            style: TextStyle(color: Colors.white70),
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
          'Desbloqueá los videos de todos los tutoriales',
          textAlign: TextAlign.center,
          style: GoogleFonts.playfairDisplay(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 30),
        for (final package in packages) _buildPackageTile(package),
      ],
    );
  }

  Widget _buildPackageTile(Package package) {
    final product = package.storeProduct;
    return Card(
      color: Colors.white12,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        title: Text(product.title, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Text(product.description, style: GoogleFonts.inter(color: Colors.white54, fontSize: 13)),
        trailing: _isPurchasing
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFD4AF37)))
            : Text(product.priceString, style: GoogleFonts.inter(color: const Color(0xFFD4AF37), fontWeight: FontWeight.bold, fontSize: 16)),
        onTap: _isPurchasing ? null : () => _buy(package),
      ),
    );
  }
}

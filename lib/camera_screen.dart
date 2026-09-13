import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'ar/ar_engine_config.dart';
import 'ar/ar_makeup_engine.dart';
import 'ar/deepar_makeup_engine.dart';
import 'ar/legacy_canvas_makeup_engine.dart';
import 'l10n/app_localizations.dart';
import 'services/ai_makeup_recipe_service.dart';
import 'step_by_step_screen.dart';

class CameraScreen extends StatefulWidget {
  final String? filterPath;
  final String? lookId;

  const CameraScreen({super.key, this.filterPath, this.lookId});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  late final ArMakeupEngine _engine = ArEngineConfig.useDeepAr ? DeepArMakeupEngine() : LegacyCanvasMakeupEngine();
  final AiMakeupRecipeService _recipeService = const AiMakeupRecipeService();

  bool _isEffectOn = true;

  @override
  void initState() {
    super.initState();
    _engine.addListener(_onEngineChanged);
    _engine.initialize();
    _loadInitialRecipe();
  }

  void _onEngineChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadInitialRecipe() async {
    final recipe = await _recipeService.fetchRecipeForLook(widget.lookId);
    await _engine.applyRecipe(recipe);
  }

  void _toggleEffect() {
    setState(() => _isEffectOn = !_isEffectOn);
    _engine.setEffectEnabled(_isEffectOn);
  }

  @override
  void dispose() {
    _engine.removeListener(_onEngineChanged);
    _engine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 📸 CÁMARA Y MAQUILLAJE (delegado al motor AR activo)
          Positioned.fill(child: _engine.buildPreview()),

          // BOTONES SUPERIORES
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(15),
                child: Navigator.canPop(context)
                    ? IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context))
                    : const SizedBox(),
              ),
            ),
          ),

          // BOTONES LATERALES
          SafeArea(
            child: Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 20, bottom: 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _buildTutorialButton(l10n),
                    const SizedBox(height: 15),
                    _buildEffectButton(l10n),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTutorialButton(AppLocalizations l10n) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StepByStepScreen())),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), borderRadius: BorderRadius.circular(20)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.menu_book_rounded, color: Color(0xFF1A1A1A), size: 16),
            const SizedBox(width: 8),
            Text(l10n.tutorial, style: GoogleFonts.inter(color: const Color(0xFF1A1A1A), fontWeight: FontWeight.w600, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildEffectButton(AppLocalizations l10n) {
    return GestureDetector(
      onTap: _toggleEffect,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
        decoration: BoxDecoration(
          color: _isEffectOn ? Colors.white.withOpacity(0.8) : Colors.black.withOpacity(0.6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _isEffectOn ? Colors.transparent : Colors.white54),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_isEffectOn ? Icons.auto_awesome : Icons.auto_awesome_outlined, color: _isEffectOn ? const Color(0xFFD4AF37) : Colors.white, size: 16),
            const SizedBox(width: 8),
            Text(_isEffectOn ? l10n.effectOn : l10n.effectOff, style: GoogleFonts.inter(color: _isEffectOn ? Colors.black : Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

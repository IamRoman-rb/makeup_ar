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

  bool _isGeneratingAI = false;
  bool _isEffectOn = true;

  final TextEditingController _promptController = TextEditingController();

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

  // 🧠 IA GENERATIVA: Groq (Llama 3) -> Receta -> Motor AR (DeepAR o legacy)
  Future<void> _generateMakeupFromPrompt(String promptText) async {
    if (promptText.isEmpty) return;
    setState(() => _isGeneratingAI = true);

    final recipe = await _recipeService.generateFromPrompt(promptText);
    if (recipe != null) {
      await _engine.applyRecipe(recipe);
      debugPrint('✅ Groq/Llama3 generó el filtro con éxito');
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al generar con IA. Intenta otro prompt.')),
      );
    }

    if (mounted) {
      setState(() => _isGeneratingAI = false);
      _promptController.clear();
      FocusScope.of(context).unfocus();
    }
  }

  void _toggleEffect() {
    setState(() => _isEffectOn = !_isEffectOn);
    _engine.setEffectEnabled(_isEffectOn);
  }

  @override
  void dispose() {
    _engine.removeListener(_onEngineChanged);
    _engine.dispose();
    _promptController.dispose();
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
                padding: const EdgeInsets.only(right: 20, bottom: 90), // Elevado para dar espacio a la IA
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

          // 🤖 CAJA DE TEXTO PARA LA IA
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.purpleAccent, width: 2),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 20),
                      Expanded(
                        child: TextField(
                          controller: _promptController,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            hintText: 'Ej: "Labios rojos y rubor rosa"',
                            hintStyle: TextStyle(color: Colors.white54),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      _isGeneratingAI
                          ? const Padding(padding: EdgeInsets.all(12.0), child: CircularProgressIndicator(color: Colors.purpleAccent))
                          : IconButton(
                        icon: const Icon(Icons.auto_awesome, color: Colors.purpleAccent),
                        onPressed: () => _generateMakeupFromPrompt(_promptController.text),
                      ),
                    ],
                  ),
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

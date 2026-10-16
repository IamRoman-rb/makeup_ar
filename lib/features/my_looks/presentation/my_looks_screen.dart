import 'dart:async';

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../ar/domain/makeup_recipe.dart';
import '../../studio/domain/recipe_generator.dart';
import '../domain/ai_look.dart';

/// "Mis looks con IA" (versión reducida del Studio para usuarios finales,
/// §10.13 del informe): pedido -> 3 variantes -> probar en AR -> guardar.
/// Los guardados se pueden volver a probar o borrar.
///
/// [onTryOn] abre la prueba en AR con la receta (la pantalla de cámara vive
/// fuera de la feature; se inyecta para los tests).
class MyLooksScreen extends StatefulWidget {
  const MyLooksScreen({
    super.key,
    required this.repository,
    required this.generator,
    required this.onTryOn,
    this.locale,
  });

  final IAiLookRepository repository;
  final IRecipeGenerator generator;
  final void Function(MakeupRecipe recipe) onTryOn;

  /// es, en, pt o fr; por defecto, el idioma de la app.
  final String? locale;

  @override
  State<MyLooksScreen> createState() => _MyLooksScreenState();
}

class _MyLooksScreenState extends State<MyLooksScreen> {
  static const _locales = {'es', 'en', 'pt', 'fr'};

  final _prompt = TextEditingController();
  // Una sola suscripción (la lista se reconstruye al aparecer las variantes y
  // un StreamBuilder se volvía a suscribir).
  StreamSubscription<List<AiLook>>? _subscription;
  List<AiLook>? _saved;
  bool _generating = false;
  List<MakeupRecipe> _variants = const [];

  /// Variante que vino del preset local porque la IA no respondió.
  bool _isFallback = false;
  String? _message;
  final Set<MakeupRecipe> _savedNow = {};

  @override
  void initState() {
    super.initState();
    _subscription = widget.repository.watch().listen(
      (looks) => setState(() => _saved = looks),
      onError: (Object e) {
        debugPrint('ai_looks: $e');
        setState(() => _saved = const []);
      },
    );
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    _prompt.dispose();
    super.dispose();
  }

  String _locale(BuildContext context) {
    final given = widget.locale;
    if (given != null) return given;
    final code = Localizations.localeOf(context).languageCode;
    return _locales.contains(code) ? code : 'es';
  }

  Future<void> _generate() async {
    final l10n = AppLocalizations.of(context)!;
    final text = _prompt.text.trim();
    if (text.isEmpty || text.length > AiLookLimits.maxPromptLength) {
      setState(() => _message = l10n.myAiLooksInvalidPrompt(AiLookLimits.maxPromptLength));
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _generating = true;
      _message = null;
    });
    final GenerationResult result;
    try {
      result = await widget.generator.generate(prompt: text, locale: _locale(context));
    } catch (e) {
      // El contrato devuelve fallas tipadas; esto es por si un generador tira.
      debugPrint('generate: $e');
      if (mounted) {
        setState(() {
          _generating = false;
          _message = l10n.myAiLooksErrorGeneric;
        });
      }
      return;
    }
    if (!mounted) return;
    final fallback = result.fallback;
    setState(() {
      _generating = false;
      _savedNow.clear();
      if (result.hasVariants) {
        _variants = result.variants;
        _isFallback = false;
      } else {
        _variants = fallback == null ? const [] : [fallback];
        _isFallback = fallback != null;
        _message = _generationMessage(l10n, result.failure);
      }
    });
  }

  String _generationMessage(AppLocalizations l10n, GenerationFailure? failure) => switch (failure) {
        GenerationFailure.quotaExhausted => l10n.myAiLooksErrorQuota(AiLookLimits.dailyGenerations),
        GenerationFailure.unauthenticated => l10n.myAiLooksErrorLogin,
        GenerationFailure.invalidInput => l10n.myAiLooksInvalidPrompt(AiLookLimits.maxPromptLength),
        GenerationFailure.noValidVariants || GenerationFailure.unavailable => l10n.myAiLooksFallback,
        _ => l10n.myAiLooksErrorGeneric,
      };

  Future<void> _save(MakeupRecipe recipe) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final failure = await widget.repository.save(recipe);
    if (!mounted) return;
    if (failure == null) setState(() => _savedNow.add(recipe));
    messenger.showSnackBar(SnackBar(content: Text(_saveMessage(l10n, failure))));
  }

  String _saveMessage(AppLocalizations l10n, AiLookFailure? failure) => switch (failure) {
        null => l10n.myAiLooksSaved,
        AiLookFailure.full => l10n.myAiLooksErrorFull(AiLookLimits.maxSaved),
        AiLookFailure.unauthenticated => l10n.myAiLooksErrorLogin,
        _ => l10n.myAiLooksErrorGeneric,
      };

  Future<void> _delete(AiLook look) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        content: Text(l10n.myAiLooksDeleteConfirm(look.recipe.name)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: Text(l10n.studioCancel)),
          FilledButton(onPressed: () => Navigator.pop(dialog, true), child: Text(l10n.myAiLooksDelete)),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final failure = await widget.repository.delete(look.id);
    if (failure != null && failure != AiLookFailure.notFound && mounted) {
      messenger.showSnackBar(SnackBar(content: Text(_saveMessage(l10n, failure))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final message = _message;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.myAiLooksTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            key: const ValueKey('ai-prompt'),
            controller: _prompt,
            maxLength: AiLookLimits.maxPromptLength,
            minLines: 1,
            maxLines: 3,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _generating ? null : unawaited(_generate()),
            decoration: InputDecoration(
              hintText: l10n.myAiLooksPromptHint,
              helperText: l10n.myAiLooksDailyLimit(AiLookLimits.dailyGenerations),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            key: const ValueKey('ai-generate'),
            onPressed: _generating ? null : _generate,
            icon: _generating
                ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.auto_awesome),
            label: Text(l10n.myAiLooksGenerate),
          ),
          if (message != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(message, key: const ValueKey('ai-message')),
            ),
          if (_variants.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(_isFallback ? l10n.myAiLooksSuggestion : l10n.myAiLooksVariants,
                style: Theme.of(context).textTheme.titleMedium),
            for (final recipe in _variants)
              _LookTile(
                recipe: recipe,
                onTap: () => widget.onTryOn(recipe),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(onPressed: () => widget.onTryOn(recipe), child: Text(l10n.myAiLooksTry)),
                    _savedNow.contains(recipe)
                        ? const Padding(padding: EdgeInsets.all(12), child: Icon(Icons.check))
                        : IconButton(
                            tooltip: l10n.myAiLooksSave,
                            icon: const Icon(Icons.bookmark_add_outlined),
                            onPressed: () => _save(recipe),
                          ),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 24),
          Text(l10n.myAiLooksSavedTitle, style: Theme.of(context).textTheme.titleMedium),
          ...switch (_saved) {
            null => [const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()))],
            [] => [Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(l10n.myAiLooksEmpty))],
            final looks => [
                for (final look in looks)
                  _LookTile(
                    key: ValueKey('saved-${look.id}'),
                    recipe: look.recipe,
                    onTap: () => widget.onTryOn(look.recipe),
                    trailing: IconButton(
                      tooltip: l10n.myAiLooksDelete,
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _delete(look),
                    ),
                  ),
              ],
          },
        ],
      ),
    );
  }
}

class _LookTile extends StatelessWidget {
  const _LookTile({super.key, required this.recipe, required this.onTap, required this.trailing});

  final MakeupRecipe recipe;
  final VoidCallback onTap;
  final Widget trailing;

  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: EdgeInsets.zero,
        onTap: onTap,
        leading: SizedBox(
          width: 56,
          child: Wrap(
            spacing: 2,
            runSpacing: 2,
            children: [
              for (final color in swatchesOf(recipe).take(4))
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Color(0xFF000000 | color.rgb),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.black12),
                  ),
                ),
            ],
          ),
        ),
        title: Text(recipe.name),
        trailing: trailing,
      );
}

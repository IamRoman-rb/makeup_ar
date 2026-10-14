import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../l10n/app_localizations.dart';
import '../../ar/domain/i_makeup_renderer.dart';
import '../../ar/domain/makeup_recipe.dart';
import '../../ar/presentation/test_filter_view.dart';
import '../domain/image_look.dart';
import '../domain/image_recipe.dart';
import '../domain/recipe_edits.dart';
import '../domain/recipe_generator.dart';
import '../domain/recipe_qa.dart';
import '../domain/studio_look.dart';
import 'qa_panel.dart';
import 'recipe_editor_panel.dart';

/// Elige una foto y devuelve sus bytes (null si se cancela).
typedef ImageBytesPicker = Future<Uint8List?> Function();

/// Galería con image_picker. La foto queda en memoria: no se guarda.
Future<Uint8List?> pickGalleryImage() async {
  final file = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 2048, maxHeight: 2048, imageQuality: 95);
  return file?.readAsBytes();
}

/// Studio (F3, solo admins): prompt -> 3 variantes generadas por IA, vista
/// previa en vivo con el motor, edición, remix, borradores y publicación en
/// el catálogo (docs/ar_engine/motor_ar_propio.md §10.13).
///
/// F5: QA automático (§10.10) de la receta elegida, recalculado en cada
/// edición; con algo en rojo no se publica (los borradores sí se guardan).
///
/// F4: "Desde foto" arma la receta midiendo una foto de referencia y
/// "Paleta de producto" saca colores de una foto de un producto. Las dos
/// corren en el teléfono ([IImageLookAnalyzer]); la foto no se sube ni se
/// guarda (docs/ar_engine/F4_PLAN.md).
///
/// La IA solo elige parámetros: cada variante llega validada por la función
/// y otra vez por la app (CloudRecipeGenerator), y cada edición pasa por
/// RecipeEdits, que nunca produce una receta inválida.
class StudioScreen extends StatefulWidget {
  const StudioScreen({
    super.key,
    required this.generator,
    required this.repository,
    this.renderer,
    this.imageAnalyzer,
    this.pickImage = pickGalleryImage,
  });

  final IRecipeGenerator generator;
  final ILookRepository repository;

  /// Sin analizador no aparecen "Desde foto" ni "Paleta de producto".
  final IImageLookAnalyzer? imageAnalyzer;

  /// Inyectable para tests; por defecto, la galería.
  final ImageBytesPicker pickImage;

  /// Inyectable para tests; por defecto, el de `AR_RENDERER`.
  final IMakeupRenderer? renderer;

  @override
  State<StudioScreen> createState() => _StudioScreenState();
}

class _StudioScreenState extends State<StudioScreen> {
  final TextEditingController _prompt = TextEditingController();
  final TextEditingController _remix = TextEditingController();

  List<MakeupRecipe> _variants = const [];
  int _selected = 0;

  /// Cambia con cada juego nuevo de variantes (no con las ediciones): los ids
  /// de las opciones cambian y la vista previa vuelve a la primera.
  int _generation = 0;
  List<TestFilterOption>? _options;
  LookSourceType _sourceType = LookSourceType.manual;
  String? _sourcePrompt;
  String? _model;
  String? _draftId;
  bool _busy = false;
  // Aviso o galería abiertos (sin spinner: no hay trabajo en curso).
  bool _picking = false;
  String? _message;

  /// Confianza y ajuste por región de la última receta desde foto.
  List<ImageRegionReport> _report = const [];
  bool _photoNoticeAccepted = false;

  @override
  void dispose() {
    _prompt.dispose();
    _remix.dispose();
    super.dispose();
  }

  MakeupRecipe? get _current => _selected < _variants.length ? _variants[_selected] : null;

  String get _locale {
    final code = Localizations.localeOf(context).languageCode;
    return const {'es', 'en', 'pt', 'fr'}.contains(code) ? code : 'es';
  }

  /// Opciones para la vista previa. Lista nueva en cada cambio: la vista la
  /// compara por identidad y vuelve a mandar la receta elegida. [fresh]: un
  /// juego nuevo (generación, remix, borrador), no una edición.
  void _setVariants(List<MakeupRecipe> variants, {int selected = 0, bool fresh = true}) {
    if (fresh) _generation++;
    _variants = List.unmodifiable(variants);
    _selected = variants.isEmpty ? 0 : selected.clamp(0, variants.length - 1);
    _options = [
      for (var i = 0; i < variants.length; i++)
        TestFilterOption(id: _optionId(i), label: variants[i].name, recipe: variants[i]),
    ];
  }

  String _optionId(int index) => 'g$_generation-v$index';

  String _failureText(AppLocalizations l10n, GenerationFailure failure) => switch (failure) {
        GenerationFailure.unauthenticated => l10n.studioErrorAuth,
        GenerationFailure.notAdmin => l10n.studioErrorAdmin,
        GenerationFailure.invalidInput => l10n.studioErrorInput,
        GenerationFailure.quotaExhausted => l10n.studioErrorQuota,
        GenerationFailure.unavailable => l10n.studioErrorUnavailable,
        GenerationFailure.appCheck => l10n.studioErrorAppCheck,
        GenerationFailure.noValidVariants => l10n.studioFallback,
        GenerationFailure.unknown => l10n.studioErrorUnknown,
      };

  Future<void> _run(Future<GenerationResult> Function() call, LookSourceType type, String prompt) async {
    if (_busy) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _busy = true;
      _message = null;
    });
    final GenerationResult result;
    try {
      result = await call();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (!mounted) return;
    setState(() {
      final failure = result.failure;
      _report = const [];
      if (result.hasVariants) {
        _setVariants(result.variants);
        _sourceType = type;
        _sourcePrompt = prompt;
        _model = result.model;
        _draftId = null;
      } else if (result.fallback case final fallback?) {
        _setVariants([fallback]);
        _sourceType = LookSourceType.manual;
        _sourcePrompt = prompt;
        _model = null;
        _draftId = null;
      }
      _message = failure == null
          ? null
          : failure == GenerationFailure.noValidVariants || result.fallback == null
              ? _failureText(l10n, failure)
              : '${_failureText(l10n, failure)} ${l10n.studioFallback}';
    });
  }

  void _generate() {
    final text = _prompt.text.trim();
    if (text.isEmpty) return;
    FocusScope.of(context).unfocus();
    unawaited(_run(() => widget.generator.generate(prompt: text, locale: _locale), LookSourceType.prompt, text));
  }

  void _remixCurrent() {
    final base = _current;
    final instruction = _remix.text.trim();
    if (base == null || instruction.isEmpty) return;
    FocusScope.of(context).unfocus();
    final prompt = _sourcePrompt ?? instruction;
    unawaited(_run(
      () => widget.generator.remix(base: base, instruction: instruction, locale: _locale),
      LookSourceType.remix,
      prompt,
    ));
  }

  void _edit(MakeupRecipe recipe) {
    final variants = [..._variants];
    variants[_selected] = recipe;
    setState(() => _setVariants(variants, selected: _selected, fresh: false));
  }

  StudioLook _look(MakeupRecipe recipe, {LookCategory? category, String? image}) => StudioLook(
        id: _draftId,
        recipe: recipe,
        category: category ?? LookCategory.of(recipe),
        sourceType: _sourceType,
        sourcePrompt: _sourcePrompt,
        model: _model,
        image: image,
      );

  Future<void> _saveDraft() async {
    final recipe = _current;
    if (recipe == null) return;
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final id = await widget.repository.saveDraft(_look(recipe));
      if (!mounted) return;
      setState(() => _draftId = id);
      messenger.showSnackBar(SnackBar(content: Text(l10n.studioSaved)));
    } catch (e) {
      debugPrint('Studio: no se pudo guardar el borrador: $e');
      messenger.showSnackBar(SnackBar(content: Text(l10n.studioSaveError)));
    }
  }

  Future<void> _publish() async {
    final recipe = _current;
    if (recipe == null) return;
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final look = await showDialog<StudioLook>(
      context: context,
      builder: (_) => _PublishDialog(look: _look(recipe)),
    );
    if (look == null) return;
    try {
      await widget.repository.publish(look);
      if (!mounted) return;
      setState(() => _draftId = null);
      messenger.showSnackBar(SnackBar(content: Text(l10n.studioPublished)));
    } catch (e) {
      debugPrint('Studio: no se pudo publicar: $e');
      messenger.showSnackBar(SnackBar(content: Text(l10n.studioSaveError)));
    }
  }

  Future<void> _openDrafts() async {
    final picked = await showModalBottomSheet<StudioLook>(
      context: context,
      builder: (_) => _DraftsSheet(repository: widget.repository),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _report = const [];
      _setVariants([picked.recipe]);
      _sourceType = picked.sourceType;
      _sourcePrompt = picked.sourcePrompt;
      _model = picked.model;
      _draftId = picked.id;
      _message = null;
    });
  }

  /// Aviso de privacidad y derechos, una vez por pantalla.
  Future<bool> _acceptPhotoNotice() async {
    if (_photoNoticeAccepted) return true;
    final l10n = AppLocalizations.of(context)!;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.studioPhotoNoticeTitle),
        content: Text(l10n.studioPhotoNotice),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.studioCancel)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l10n.studioContinue)),
        ],
      ),
    );
    _photoNoticeAccepted = accepted ?? false;
    return _photoNoticeAccepted;
  }

  String _photoStatusText(AppLocalizations l10n, PhotoLookStatus status) => switch (status) {
        PhotoLookStatus.noFace || PhotoLookStatus.lowPresence => l10n.studioPhotoNoFace,
        PhotoLookStatus.faceTooSmall => l10n.studioPhotoSmall,
        PhotoLookStatus.profile => l10n.studioPhotoProfile,
        PhotoLookStatus.ok || PhotoLookStatus.badImage => l10n.studioPhotoBad,
      };

  /// Aviso (si hace falta) y galería, con los botones deshabilitados mientras
  /// tanto: un doble toque no abre dos galerías ni dos análisis.
  Future<Uint8List?> _pick({required bool notice}) async {
    if (_busy || _picking) return null;
    setState(() => _picking = true);
    try {
      if (notice && !await _acceptPhotoNotice()) return null;
      return await widget.pickImage();
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  /// Foto de referencia -> 3 variantes (fiel, intensa, sutil) con su reporte.
  Future<void> _fromPhoto() async {
    final analyzer = widget.imageAnalyzer;
    if (analyzer == null) return;
    final bytes = await _pick(notice: true);
    if (bytes == null || !mounted) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _busy = true;
      _message = null;
    });
    ImageRecipeResult result;
    try {
      final measurements = await analyzer.analyzeFace(bytes);
      result = ImageRecipeBuilder.build(measurements, name: l10n.studioPhotoFaithful);
    } catch (e) {
      debugPrint('Studio: no se pudo analizar la foto: $e');
      result = const ImageRecipeResult(status: PhotoLookStatus.badImage);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (!mounted) return;
    setState(() {
      final recipe = result.recipe;
      if (recipe == null) {
        _message = _photoStatusText(l10n, result.status);
        return;
      }
      _setVariants(ImageRecipeBuilder.variants(
        recipe,
        names: [l10n.studioPhotoFaithful, l10n.studioPhotoBolder, l10n.studioPhotoSubtler],
      ));
      _report = result.regions;
      _sourceType = LookSourceType.image;
      _sourcePrompt = null;
      _model = null;
      _draftId = null;
    });
  }

  /// Foto de un producto -> swatches -> un color en una capa de la receta.
  Future<void> _fromPalette() async {
    final analyzer = widget.imageAnalyzer;
    if (analyzer == null || _current == null) return;
    final bytes = await _pick(notice: false);
    if (bytes == null || !mounted) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _busy = true;
      _message = null;
    });
    List<ProductSwatch> swatches;
    try {
      swatches = await analyzer.palette(bytes);
    } catch (e) {
      debugPrint('Studio: no se pudo sacar la paleta: $e');
      swatches = const [];
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    final recipe = _current;
    if (!mounted || recipe == null) return;
    if (swatches.isEmpty) {
      setState(() => _message = l10n.studioPaletteEmpty);
      return;
    }
    final picked = await showModalBottomSheet<({RecipeLayer layer, RecipeColor color})>(
      context: context,
      builder: (_) => _PaletteSheet(swatches: swatches, recipe: recipe),
    );
    final current = _current;
    if (picked == null || current == null || !mounted) return;
    _edit(RecipeEdits.withColorOrAdd(current, picked.layer, picked.color));
  }

  Widget _reportView(AppLocalizations l10n) {
    final worst = _report.fold(0.0, (w, r) => r.fitError > w ? r.fitError : w);
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final region in _report)
                Chip(
                  visualDensity: VisualDensity.compact,
                  label: Text(l10n.studioRegionConfidence(
                    RecipeEditorPanel.layerLabel(l10n, region.layer),
                    (region.confidence * 100).round(),
                  )),
                ),
            ],
          ),
          if (worst > ImageRecipePolicy.maxFitError)
            Text(l10n.studioPhotoRough, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ],
      ),
    );
  }

  TestFilterLabels _labels(AppLocalizations l10n) => TestFilterLabels(
        noFilter: l10n.testFilterNone,
        intensity: l10n.testFilterIntensity,
        note: l10n.studioNote,
        showPoints: l10n.testFilterShowPoints,
        compare: l10n.testFilterCompare,
        matte: l10n.testFilterFinishMatte,
        satin: l10n.testFilterFinishSatin,
        gloss: l10n.testFilterFinishGloss,
        shimmer: l10n.testFilterFinishShimmer,
        zoneAll: l10n.testFilterZoneAll,
        zoneLips: l10n.testFilterZoneLips,
        zoneEyes: l10n.testFilterZoneEyes,
        zoneCheeks: l10n.testFilterZoneCheeks,
        zoneSkin: l10n.testFilterZoneSkin,
        unavailable: l10n.testFilterUnavailable,
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final current = _current;
    // Unas decenas de cuentas OKLab: se recalcula en cada edición.
    final qa = current == null ? null : RecipeQa.check(current);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.studioTitle),
        actions: [
          IconButton(tooltip: l10n.studioDrafts, icon: const Icon(Icons.folder_open), onPressed: _openDrafts),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 5,
            child: ColoredBox(
              color: Colors.black,
              child: TestFilterView(
                labels: _labels(l10n),
                renderer: widget.renderer,
                options: _options ?? [TestFilterOption(id: 'none', label: l10n.testFilterNone, recipe: null)],
                initialOptionId: _optionId(_selected),
                onOptionSelected: (option) {
                  final index = _options?.indexWhere((o) => o.id == option.id) ?? -1;
                  if (index >= 0) setState(() => _selected = index);
                },
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _prompt,
                        maxLength: 300,
                        minLines: 1,
                        maxLines: 3,
                        decoration: InputDecoration(hintText: l10n.studioPromptHint, counterText: ''),
                        onSubmitted: (_) => _generate(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _busy ? null : _generate,
                      child: _busy
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : Text(l10n.studioGenerate),
                    ),
                  ],
                ),
                if (widget.imageAnalyzer != null)
                  Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _busy || _picking ? null : _fromPhoto,
                        icon: const Icon(Icons.photo_outlined, size: 18),
                        label: Text(l10n.studioFromPhoto),
                      ),
                      OutlinedButton.icon(
                        onPressed: _busy || _picking || current == null ? null : _fromPalette,
                        icon: const Icon(Icons.palette_outlined, size: 18),
                        label: Text(l10n.studioPalette),
                      ),
                    ],
                  ),
                if (_message case final message?)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(message, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ),
                if (current == null)
                  Padding(padding: const EdgeInsets.only(top: 16), child: Text(l10n.studioEmpty, textAlign: TextAlign.center))
                else ...[
                  const SizedBox(height: 8),
                  Text(current.name, style: Theme.of(context).textTheme.titleMedium),
                  if (_report.isNotEmpty) _reportView(l10n),
                  RecipeEditorPanel(recipe: current, onChanged: _edit),
                  if (qa != null) QaPanel(report: qa),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _remix,
                          maxLength: 300,
                          decoration: InputDecoration(hintText: l10n.studioRemixHint, counterText: ''),
                          onSubmitted: (_) => _remixCurrent(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(onPressed: _busy ? null : _remixCurrent, child: Text(l10n.studioRemix)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: OutlinedButton(onPressed: _saveDraft, child: Text(l10n.studioSaveDraft))),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton(
                          onPressed: qa?.blocksPublish ?? true ? null : _publish,
                          child: Text(l10n.studioPublish),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Nombre, categoría e imagen antes de publicar.
class _PublishDialog extends StatefulWidget {
  const _PublishDialog({required this.look});

  final StudioLook look;

  @override
  State<_PublishDialog> createState() => _PublishDialogState();
}

class _PublishDialogState extends State<_PublishDialog> {
  late final TextEditingController _name = TextEditingController(text: widget.look.name);
  final TextEditingController _image = TextEditingController();
  late LookCategory _category = widget.look.category;

  @override
  void dispose() {
    _name.dispose();
    _image.dispose();
    super.dispose();
  }

  String _categoryLabel(AppLocalizations l10n, LookCategory category) => switch (category) {
        LookCategory.lips => l10n.categoryLips,
        LookCategory.eyes => l10n.categoryEyes,
        LookCategory.complexion => l10n.categoryComplexion,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.studioPublish),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: _name, maxLength: 60, decoration: InputDecoration(labelText: l10n.studioName)),
          DropdownButtonFormField<LookCategory>(
            initialValue: _category,
            decoration: InputDecoration(labelText: l10n.studioCategory),
            items: [
              for (final category in LookCategory.values)
                DropdownMenuItem(value: category, child: Text(_categoryLabel(l10n, category))),
            ],
            onChanged: (value) => setState(() => _category = value ?? _category),
          ),
          TextField(controller: _image, decoration: InputDecoration(labelText: l10n.studioImageUrl)),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.studioCancel)),
        FilledButton(
          onPressed: () {
            final image = _image.text.trim();
            final renamed = RecipeEdits.withName(widget.look.recipe, _name.text);
            Navigator.pop(
              context,
              widget.look.copyWith(recipe: renamed, category: _category, image: image.startsWith('https://') ? image : null),
            );
          },
          child: Text(l10n.studioPublish),
        ),
      ],
    );
  }
}

/// Paleta de un producto: primero un color, después la capa donde va. Las
/// capas que faltan se pueden agregar (RecipeEdits.withColorOrAdd).
class _PaletteSheet extends StatefulWidget {
  const _PaletteSheet({required this.swatches, required this.recipe});

  final List<ProductSwatch> swatches;
  final MakeupRecipe recipe;

  @override
  State<_PaletteSheet> createState() => _PaletteSheetState();
}

class _PaletteSheetState extends State<_PaletteSheet> {
  RecipeColor? _color;

  /// Capas con color presentes, más las que se pueden agregar.
  List<RecipeLayer> _targets() {
    final present = RecipeEdits.layersOf(widget.recipe).where((l) => l.hasColor).toList();
    final next = RecipeEdits.nextShadow(widget.recipe);
    return [
      ...present,
      for (final layer in [RecipeLayer.lips, RecipeLayer.lipLiner, RecipeLayer.cheeks, RecipeLayer.eyeLiner])
        if (!present.contains(layer) && (layer != RecipeLayer.lipLiner || widget.recipe.lips != null)) layer,
      ?next,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final color = _color;
    final next = RecipeEdits.nextShadow(widget.recipe);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.studioPalette, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                for (final swatch in widget.swatches)
                  InkWell(
                    key: ValueKey('swatch-${swatch.color.toHex()}'),
                    onTap: () => setState(() => _color = swatch.color),
                    customBorder: const CircleBorder(),
                    child: Column(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Color(0xFF000000 | swatch.color.rgb),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: swatch.color == color ? Theme.of(context).colorScheme.primary : Colors.black26,
                              width: swatch.color == color ? 3 : 1,
                            ),
                          ),
                        ),
                        Text('${(swatch.fraction * 100).round()} %', style: Theme.of(context).textTheme.labelSmall),
                      ],
                    ),
                  ),
              ],
            ),
            if (color != null) ...[
              const SizedBox(height: 12),
              Text(l10n.studioPalettePickLayer),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final layer in _targets())
                      ListTile(
                        dense: true,
                        title: Text(layer == next ? l10n.studioNewShadow : RecipeEditorPanel.layerLabel(l10n, layer)),
                        onTap: () => Navigator.pop(context, (layer: layer, color: color)),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Borradores guardados: tocar uno lo abre, la cruz lo borra.
class _DraftsSheet extends StatefulWidget {
  const _DraftsSheet({required this.repository});

  final ILookRepository repository;

  @override
  State<_DraftsSheet> createState() => _DraftsSheetState();
}

class _DraftsSheetState extends State<_DraftsSheet> {
  late Future<List<StudioLook>> _drafts = widget.repository.drafts();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return FutureBuilder<List<StudioLook>>(
      future: _drafts,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()));
        }
        final drafts = snapshot.data ?? const <StudioLook>[];
        if (drafts.isEmpty) {
          return Padding(padding: const EdgeInsets.all(32), child: Center(child: Text(l10n.studioNoDrafts)));
        }
        return ListView(
          shrinkWrap: true,
          children: [
            for (final draft in drafts)
              ListTile(
                title: Text(draft.name),
                subtitle: draft.sourcePrompt == null ? null : Text(draft.sourcePrompt ?? '', maxLines: 1),
                onTap: () => Navigator.pop(context, draft),
                trailing: IconButton(
                  tooltip: l10n.studioDeleteDraft,
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    final id = draft.id;
                    if (id == null) return;
                    await widget.repository.deleteDraft(id);
                    if (mounted) setState(() => _drafts = widget.repository.drafts());
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}

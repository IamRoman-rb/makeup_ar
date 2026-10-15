import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../ar/domain/makeup_recipe.dart';
import '../domain/recipe_edits.dart';

/// Editor de la receta elegida en el Studio: color HEX con muestra y
/// cantidad por capa, acabado del labial y quitar capas. Cada cambio produce
/// una receta nueva ya validada ([RecipeEdits]) y la manda a [onChanged]; la
/// vista previa la dibuja en vivo.
class RecipeEditorPanel extends StatelessWidget {
  const RecipeEditorPanel({super.key, required this.recipe, required this.onChanged});

  final MakeupRecipe recipe;
  final ValueChanged<MakeupRecipe> onChanged;

  static String layerLabel(AppLocalizations l10n, RecipeLayer layer) => switch (layer) {
        RecipeLayer.lips => l10n.studioLayerLips,
        RecipeLayer.lipLiner => l10n.studioLayerLipLiner,
        RecipeLayer.cheeks => l10n.studioLayerCheeks,
        RecipeLayer.foundation => l10n.studioLayerFoundation,
        RecipeLayer.contour => l10n.studioLayerContour,
        RecipeLayer.highlight => l10n.studioLayerHighlight,
        RecipeLayer.eyeLiner => l10n.studioLayerEyeLiner,
        RecipeLayer.lashes => l10n.studioLayerLashes,
        RecipeLayer.shadow0 => l10n.studioLayerShadow(1),
        RecipeLayer.shadow1 => l10n.studioLayerShadow(2),
        RecipeLayer.shadow2 => l10n.studioLayerShadow(3),
        RecipeLayer.shadow3 => l10n.studioLayerShadow(4),
        RecipeLayer.iris => l10n.studioLayerIris,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final lips = recipe.lips;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final layer in RecipeEdits.layersOf(recipe)) _LayerRow(recipe: recipe, layer: layer, onChanged: onChanged),
        if (lips != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Wrap(
              spacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(l10n.studioFinish),
                for (final finish in LipFinish.values)
                  ChoiceChip(
                    label: Text(_finishLabel(l10n, finish)),
                    selected: (lips.finish ?? LipFinish.satin) == finish,
                    onSelected: (_) => onChanged(RecipeEdits.withLipFinish(recipe, finish)),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  static String _finishLabel(AppLocalizations l10n, LipFinish finish) => switch (finish) {
        LipFinish.matte => l10n.testFilterFinishMatte,
        LipFinish.satin => l10n.testFilterFinishSatin,
        LipFinish.gloss => l10n.testFilterFinishGloss,
        LipFinish.shimmer => l10n.testFilterFinishShimmer,
      };
}

class _LayerRow extends StatelessWidget {
  const _LayerRow({required this.recipe, required this.layer, required this.onChanged});

  final MakeupRecipe recipe;
  final RecipeLayer layer;
  final ValueChanged<MakeupRecipe> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final value = RecipeEdits.valueOf(recipe, layer);
    if (value == null) return const SizedBox.shrink();
    final color = value.color;
    return Row(
      children: [
        SizedBox(width: 108, child: Text(RecipeEditorPanel.layerLabel(l10n, layer), overflow: TextOverflow.ellipsis)),
        if (color != null)
          InkWell(
            key: ValueKey('color-${layer.name}'),
            onTap: () async {
              final picked = await _pickColor(context, color);
              if (picked != null) onChanged(RecipeEdits.withColor(recipe, layer, picked));
            },
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: Color(0xFF000000 | color.rgb),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black26),
              ),
            ),
          ),
        Expanded(
          child: Slider(
            key: ValueKey('amount-${layer.name}'),
            value: value.amount.clamp(0.0, 1.0),
            onChanged: (amount) => onChanged(RecipeEdits.withAmount(recipe, layer, amount)),
          ),
        ),
        IconButton(
          tooltip: l10n.studioRemove,
          icon: const Icon(Icons.close, size: 18),
          onPressed: () => onChanged(RecipeEdits.without(recipe, layer)),
        ),
      ],
    );
  }

  Future<RecipeColor?> _pickColor(BuildContext context, RecipeColor current) =>
      showDialog<RecipeColor>(context: context, builder: (_) => _HexDialog(initial: current));
}

/// Diálogo de color HEX. Dueño de su controller: se libera cuando el diálogo
/// termina de cerrarse, no al hacer pop (la animación de salida lo usa).
class _HexDialog extends StatefulWidget {
  const _HexDialog({required this.initial});

  final RecipeColor initial;

  @override
  State<_HexDialog> createState() => _HexDialogState();
}

class _HexDialogState extends State<_HexDialog> {
  late final TextEditingController _controller = TextEditingController(text: widget.initial.toHex());

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.studioColorHex),
      content: TextField(controller: _controller, autofocus: true, decoration: const InputDecoration(hintText: '#B3122D')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.studioCancel)),
        TextButton(
          onPressed: () => Navigator.pop(context, RecipeColor.tryParse(_controller.text.trim().toUpperCase())),
          child: Text(l10n.studioAccept),
        ),
      ],
    );
  }
}

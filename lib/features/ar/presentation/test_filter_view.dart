import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:makeup_engine/makeup_engine.dart';

import '../domain/makeup_recipe.dart';
import '../domain/recipe_presets.dart';

/// Opción del selector: un preset local (su color de labios como tinte) o
/// "sin filtro" (paso directo).
final class TestFilterOption {
  const TestFilterOption({required this.id, required this.label, required this.color});

  /// Opciones a partir de los presets locales (`RecipePresets`), con "sin filtro"
  /// primero.
  static List<TestFilterOption> fromPresets(String noFilterLabel) => [
        TestFilterOption(id: 'none', label: noFilterLabel, color: null),
        for (final preset in RecipePresets.all)
          TestFilterOption(id: preset.id, label: preset.recipe.name, color: _presetColor(preset.recipe)),
      ];

  static RecipeColor? _presetColor(MakeupRecipe recipe) =>
      recipe.lips?.color ?? recipe.cheeks?.color ?? recipe.eyes?.shadow?.firstOrNull?.color;

  final String id;
  final String label;

  /// null = sin filtro.
  final RecipeColor? color;
}

/// Filtro de prueba del motor nativo para el Espejo: cámara frontal → GLES →
/// `Texture`, con el tinte OKLab del motor usando el color de cada preset.
///
/// "Solo labios" (por defecto) usa el tracker facial para teñir solo los
/// labios (provisional: el labial fotorrealista con máscara UV es P4); apagado,
/// tiñe toda la imagen. "Ver puntos" dibuja los landmarks para depurar. En los
/// dos casos solo cambia la croma y se conserva la luz y la textura de la piel.
///
/// Dueña del motor mientras está montada: lo inicia en initState y lo detiene
/// en dispose. Bloquea la pantalla en vertical, la única orientación validada
/// del motor (ver CameraMath.extraRotation). Quien la monte tiene que haber
/// liberado antes cualquier otro uso de la cámara.
class TestFilterView extends StatefulWidget {
  const TestFilterView({
    super.key,
    required this.noFilterLabel,
    required this.intensityLabel,
    required this.note,
    required this.lipsOnlyLabel,
    required this.showPointsLabel,
    this.engine,
  });

  final String noFilterLabel;
  final String intensityLabel;
  final String note;
  final String lipsOnlyLabel;
  final String showPointsLabel;

  /// Inyectable para tests.
  final MakeupEngine? engine;

  @override
  State<TestFilterView> createState() => _TestFilterViewState();
}

class _TestFilterViewState extends State<TestFilterView> {
  static const Duration _statsPeriod = Duration(seconds: 1);
  static const double _defaultAmount = 0.45;

  late final MakeupEngine _engine = widget.engine ?? MakeupEngine();
  late final List<TestFilterOption> _options = TestFilterOption.fromPresets(widget.noFilterLabel);
  final ValueNotifier<EngineStats> _stats = ValueNotifier(EngineStats.empty);

  EngineStartInfo? _info;
  String? _error;
  Timer? _statsTimer;
  bool _statsInFlight = false;
  bool _tintInFlight = false;
  bool _tintDirty = false;
  late TestFilterOption _selected = _options.length > 1 ? _options[1] : _options.first;
  double _amount = _defaultAmount;
  bool _lipsOnly = true;
  bool _showPoints = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    unawaited(_start());
  }

  @override
  void dispose() {
    _statsTimer?.cancel();
    _stats.dispose();
    unawaited(_engine.stop());
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  Future<void> _start() async {
    try {
      final info = await _engine.start();
      if (!mounted) {
        await _engine.stop();
        return;
      }
      setState(() => _info = info);
      await _applyRenderOptions();
      await _applyTint();
      _statsTimer = Timer.periodic(_statsPeriod, (_) => _pollStats());
    } on MakeupEngineException catch (e) {
      if (mounted) setState(() => _error = '${e.code}: ${e.message ?? ''}');
    }
  }

  /// Nunca hay más de un pedido de métricas en vuelo: los demás se descartan.
  Future<void> _pollStats() async {
    if (_statsInFlight) return;
    _statsInFlight = true;
    try {
      final stats = await _engine.getStats();
      if (mounted) _stats.value = stats;
    } finally {
      _statsInFlight = false;
    }
  }

  /// El slider genera muchos eventos por segundo: solo se envía el último valor.
  Future<void> _applyTint() async {
    _tintDirty = true;
    if (_tintInFlight) return;
    _tintInFlight = true;
    try {
      while (_tintDirty && mounted) {
        _tintDirty = false;
        final color = _selected.color;
        if (color == null) {
          await _engine.setTint(r: 0, g: 0, b: 0, amount: 0);
        } else {
          await _engine.setTint(
            r: color.red / 255,
            g: color.green / 255,
            b: color.blue / 255,
            amount: _amount,
          );
        }
      }
    } finally {
      _tintInFlight = false;
    }
  }

  void _select(TestFilterOption option) {
    setState(() => _selected = option);
    unawaited(_applyTint());
  }

  Future<void> _applyRenderOptions() => _engine.setRenderOptions(
        showLandmarks: _showPoints,
        region: _lipsOnly ? TintRegion.lips : TintRegion.full,
      );

  void _setLipsOnly(bool value) {
    setState(() => _lipsOnly = value);
    unawaited(_applyRenderOptions());
  }

  void _setShowPoints(bool value) {
    setState(() => _showPoints = value);
    unawaited(_applyRenderOptions());
  }

  @override
  Widget build(BuildContext context) {
    final info = _info;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (info == null)
          Center(
            child: _error == null
                ? const CircularProgressIndicator(color: Colors.pink)
                : Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_error ?? '', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white)),
                  ),
          )
        else
          // Igual que el espejo: llena la pantalla recortando los bordes.
          ClipRect(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: info.width.toDouble(),
                height: info.height.toDouble(),
                child: Texture(textureId: info.textureId),
              ),
            ),
          ),
        Positioned(
          top: 8,
          left: 8,
          child: _FpsBadge(stats: _stats, trackingRequested: _lipsOnly || _showPoints),
        ),
        Positioned(left: 0, right: 0, bottom: 0, child: _buildControls()),
      ],
    );
  }

  Widget _buildControls() {
    final hasColor = _selected.color != null;
    return Container(
      color: Colors.black54,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.note, style: const TextStyle(color: Colors.white70, fontSize: 11)),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            children: [
              FilterChip(
                label: Text(widget.lipsOnlyLabel),
                selected: _lipsOnly,
                onSelected: _setLipsOnly,
              ),
              FilterChip(
                label: Text(widget.showPointsLabel),
                selected: _showPoints,
                onSelected: _setShowPoints,
              ),
            ],
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _options.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) => _OptionChip(
                option: _options[index],
                selected: _options[index].id == _selected.id,
                onTap: () => _select(_options[index]),
              ),
            ),
          ),
          if (hasColor)
            Row(
              children: [
                Text(widget.intensityLabel, style: const TextStyle(color: Colors.white, fontSize: 12)),
                Expanded(
                  child: Slider(
                    value: _amount,
                    activeColor: Colors.pink,
                    onChanged: (value) {
                      setState(() => _amount = value);
                      unawaited(_applyTint());
                    },
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _OptionChip extends StatelessWidget {
  const _OptionChip({required this.option, required this.selected, required this.onTap});

  final TestFilterOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = option.color;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? Colors.white24 : Colors.black38,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? Colors.white : Colors.white30),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color == null ? Colors.transparent : Color(0xFF000000 | color.rgb),
                border: Border.all(color: Colors.white70),
              ),
            ),
            const SizedBox(width: 6),
            Text(option.label, style: const TextStyle(color: Colors.white, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

/// FPS reales del motor y estado del tracker (calculados en nativo), y error
/// asíncrono si lo hay. Texto de depuración: no se traduce.
class _FpsBadge extends StatelessWidget {
  const _FpsBadge({required this.stats, required this.trackingRequested});

  final ValueListenable<EngineStats> stats;
  final bool trackingRequested;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<EngineStats>(
      valueListenable: stats,
      builder: (context, s, _) {
        final fps = s.renderFps;
        final error = s.error ?? s.tracker.error;
        final text = error != null
            ? 'Motor: $error'
            : 'Motor nativo · ${fps == null ? '—' : fps.toStringAsFixed(0)} fps\n${trackerLabel(s.tracker, requested: trackingRequested)}';
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(6)),
          child: Text(text, style: TextStyle(color: error != null ? Colors.orangeAccent : Colors.greenAccent, fontSize: 11)),
        );
      },
    );
  }
}

/// Una línea con el estado del tracker para el badge. [requested]: alguna
/// opción de la vista lo necesita.
@visibleForTesting
String trackerLabel(TrackerStats tracker, {required bool requested}) {
  switch (tracker.state) {
    case TrackerState.off:
      if (!requested) return 'Tracker: apagado';
      return tracker.backend == null ? 'Tracker: cargando modelos…' : 'Tracker: iniciando…';
    case TrackerState.searching:
      return 'Tracker: buscando cara…';
    case TrackerState.tracking:
      final hz = tracker.hz;
      final ms = tracker.landmarkP50Ms;
      return 'Tracker: ${hz == null ? '—' : hz.toStringAsFixed(0)} Hz · '
          '${ms == null ? '—' : ms.toStringAsFixed(0)} ms';
  }
}

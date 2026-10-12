import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:makeup_engine/makeup_engine.dart';

import '../domain/makeup_recipe.dart';
import '../domain/recipe_presets.dart';

/// Opción del selector: un preset local o "sin filtro" (paso directo).
final class TestFilterOption {
  const TestFilterOption({required this.id, required this.label, required this.recipe});

  /// Opciones a partir de los presets locales (`RecipePresets`), con "sin filtro"
  /// primero.
  static List<TestFilterOption> fromPresets(String noFilterLabel) => [
        TestFilterOption(id: 'none', label: noFilterLabel, recipe: null),
        for (final preset in RecipePresets.all)
          TestFilterOption(id: preset.id, label: preset.recipe.name, recipe: preset.recipe),
      ];

  final String id;
  final String label;

  /// null = sin filtro.
  final MakeupRecipe? recipe;

  /// Color del tinte de pantalla completa: el de los labios o, si no hay, el
  /// de otra región.
  RecipeColor? get color {
    final current = recipe;
    if (current == null) return null;
    return current.lips?.color ?? current.cheeks?.color ?? current.eyes?.shadow?.firstOrNull?.color;
  }

  LipsSpec? get lips => recipe?.lips;
}

/// Textos de la vista (traducidos por quien la monta).
final class TestFilterLabels {
  const TestFilterLabels({
    required this.noFilter,
    required this.intensity,
    required this.note,
    required this.lipsOnly,
    required this.showPoints,
    required this.compare,
    required this.matte,
    required this.satin,
    required this.gloss,
    required this.shimmer,
  });

  final String noFilter;
  final String intensity;
  final String note;
  final String lipsOnly;
  final String showPoints;

  /// Botón que, mientras se mantiene apretado, muestra la cámara sin maquillaje.
  final String compare;
  final String matte;
  final String satin;
  final String gloss;
  final String shimmer;

  String finish(LipFinish finish) => switch (finish) {
        LipFinish.matte => matte,
        LipFinish.satin => satin,
        LipFinish.gloss => gloss,
        LipFinish.shimmer => shimmer,
      };
}

/// Filtro de prueba del motor nativo para el Espejo: cámara frontal → GLES →
/// `Texture`.
///
/// "Solo labios" (por defecto) pinta el labial de la receta del preset sobre
/// la cara (máscara UV, brillo y acabado; ver docs/ar_engine/LIPS.md): el
/// slider es la opacidad del labial y los chips de acabado lo cambian para
/// comparar. Apagado, tiñe toda la imagen con el color del preset (OKLab, solo
/// croma). "Ver puntos" dibuja los landmarks para depurar. El botón de
/// comparar muestra la cámara sin maquillaje mientras se mantiene apretado.
///
/// Dueña del motor mientras está montada: lo inicia en initState y lo detiene
/// en dispose. Bloquea la pantalla en vertical, la única orientación validada
/// del motor (ver CameraMath.extraRotation). Quien la monte tiene que haber
/// liberado antes cualquier otro uso de la cámara.
class TestFilterView extends StatefulWidget {
  const TestFilterView({super.key, required this.labels, this.engine});

  final TestFilterLabels labels;

  /// Inyectable para tests.
  final MakeupEngine? engine;

  @override
  State<TestFilterView> createState() => _TestFilterViewState();
}

class _TestFilterViewState extends State<TestFilterView> {
  static const Duration _statsPeriod = Duration(seconds: 1);
  static const double _defaultTintAmount = 0.45;

  late final MakeupEngine _engine = widget.engine ?? MakeupEngine();
  late final List<TestFilterOption> _options = TestFilterOption.fromPresets(widget.labels.noFilter);
  final ValueNotifier<EngineStats> _stats = ValueNotifier(EngineStats.empty);

  EngineStartInfo? _info;
  String? _error;
  Timer? _statsTimer;
  bool _statsInFlight = false;
  bool _lookInFlight = false;
  bool _lookDirty = false;
  late TestFilterOption _selected = _options.length > 1 ? _options[1] : _options.first;
  double _tintAmount = _defaultTintAmount;
  late double _lipsOpacity = _selected.lips?.opacity ?? 0.0;

  /// Acabado elegido en los chips; null = el del preset.
  LipFinish? _finish;
  bool _lipsOnly = true;
  bool _showPoints = false;
  bool _comparing = false;

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
      await _applyLook();
      // Si se desmontó durante los awaits, dispose() ya pasó: no crear el timer.
      if (!mounted) return;
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
    } on PlatformException catch (e) {
      _ignoreEngineError('getStats', e);
    } finally {
      _statsInFlight = false;
    }
  }

  /// Manda el look actual: la receta (solo labios) o el tinte (pantalla
  /// completa). El slider genera muchos eventos por segundo: solo se envía el
  /// último estado.
  Future<void> _applyLook() async {
    _lookDirty = true;
    if (_lookInFlight) return;
    _lookInFlight = true;
    try {
      while (_lookDirty && mounted) {
        _lookDirty = false;
        try {
          if (_lipsOnly) {
            await _engine.setRecipe(lipsRecipe(_selected, opacity: _comparing ? 0.0 : _lipsOpacity, finish: _finish));
          } else {
            final color = _selected.color;
            if (color == null || _comparing) {
              await _engine.setTint(r: 0, g: 0, b: 0, amount: 0);
            } else {
              await _engine.setTint(r: color.red / 255, g: color.green / 255, b: color.blue / 255, amount: _tintAmount);
            }
          }
        } on PlatformException catch (e) {
          _ignoreEngineError('look', e);
        }
      }
    } finally {
      _lookInFlight = false;
    }
  }

  void _select(TestFilterOption option) {
    setState(() {
      _selected = option;
      _lipsOpacity = option.lips?.opacity ?? 0.0;
      _finish = null;
    });
    unawaited(_applyLook());
  }

  Future<void> _applyRenderOptions() async {
    try {
      await _engine.setRenderOptions(
        showLandmarks: _showPoints,
        region: _lipsOnly ? TintRegion.lips : TintRegion.full,
      );
    } on PlatformException catch (e) {
      _ignoreEngineError('renderOptions', e);
    }
  }

  /// Los pedidos al motor se lanzan sin esperar (unawaited): si el motor ya
  /// se detuvo (la vista se desmontó con un pedido en vuelo) o lo rechaza, el
  /// pedido se descarta; el próximo cambio manda el estado completo.
  void _ignoreEngineError(String what, PlatformException e) {
    debugPrint('TestFilterView: $what descartado (${e.code}: ${e.message})');
  }

  void _setLipsOnly(bool value) {
    setState(() => _lipsOnly = value);
    unawaited(_applyRenderOptions());
    unawaited(_applyLook());
  }

  void _setShowPoints(bool value) {
    setState(() => _showPoints = value);
    unawaited(_applyRenderOptions());
  }

  void _setFinish(LipFinish finish) {
    setState(() => _finish = finish);
    unawaited(_applyLook());
  }

  void _setComparing(bool value) {
    if (_comparing == value) return;
    setState(() => _comparing = value);
    unawaited(_applyLook());
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
        Positioned(top: 8, right: 8, child: _buildCompareButton()),
        Positioned(left: 0, right: 0, bottom: 0, child: _buildControls()),
      ],
    );
  }

  /// Mientras se mantiene apretado: cámara sin maquillaje (antes/después).
  Widget _buildCompareButton() {
    return Listener(
      onPointerDown: (_) => _setComparing(true),
      onPointerUp: (_) => _setComparing(false),
      onPointerCancel: (_) => _setComparing(false),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: _comparing ? Colors.white24 : Colors.black54,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white54),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.compare, color: Colors.white, size: 18),
            const SizedBox(width: 6),
            Text(widget.labels.compare, style: const TextStyle(color: Colors.white, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildControls() {
    final labels = widget.labels;
    final lips = _selected.lips;
    final showLipControls = _lipsOnly && lips != null;
    final showTintSlider = !_lipsOnly && _selected.color != null;
    final effectiveFinish = _finish ?? lips?.finish ?? LipFinish.satin;
    return Container(
      color: Colors.black54,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(labels.note, style: const TextStyle(color: Colors.white70, fontSize: 11)),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            children: [
              FilterChip(label: Text(labels.lipsOnly), selected: _lipsOnly, onSelected: _setLipsOnly),
              FilterChip(label: Text(labels.showPoints), selected: _showPoints, onSelected: _setShowPoints),
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
          if (showLipControls) ...[
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              children: [
                for (final finish in LipFinish.values)
                  ChoiceChip(
                    label: Text(labels.finish(finish)),
                    selected: finish == effectiveFinish,
                    onSelected: (_) => _setFinish(finish),
                  ),
              ],
            ),
          ],
          if (showLipControls || showTintSlider)
            Row(
              children: [
                Text(labels.intensity, style: const TextStyle(color: Colors.white, fontSize: 12)),
                Expanded(
                  child: Slider(
                    value: showLipControls ? _lipsOpacity : _tintAmount,
                    activeColor: Colors.pink,
                    onChanged: (value) {
                      setState(() {
                        if (showLipControls) {
                          _lipsOpacity = value;
                        } else {
                          _tintAmount = value;
                        }
                      });
                      unawaited(_applyLook());
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

/// Receta que se manda al motor en modo "solo labios": la del preset con la
/// opacidad del slider y, si se eligió, otro acabado. Sin labios (o "sin
/// filtro") devuelve una receta sin `lips`, que apaga el labial.
@visibleForTesting
Map<String, Object?> lipsRecipe(TestFilterOption option, {required double opacity, LipFinish? finish}) {
  final recipe = option.recipe;
  final lips = recipe?.lips;
  if (recipe == null || lips == null) return const {'schema': 'makeup-recipe/2', 'name': 'none'};
  final json = recipe.toJson();
  json['lips'] = LipsSpec(
    color: lips.color,
    opacity: opacity.clamp(0.0, 1.0),
    finish: finish ?? lips.finish,
    gloss: lips.gloss,
    lumaFollow: lips.lumaFollow,
    liner: lips.liner,
  ).toJson();
  return json;
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

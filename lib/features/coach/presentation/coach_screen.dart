import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:ar_makeup_app/features/ar/data/makeup_renderer_factory.dart';
import 'package:ar_makeup_app/features/ar/domain/i_makeup_renderer.dart';
import 'package:ar_makeup_app/features/ar/domain/makeup_recipe.dart';
import 'package:ar_makeup_app/features/ar/presentation/test_filter_view.dart';
import 'package:ar_makeup_app/l10n/app_localizations.dart';

import '../../studio/domain/image_look.dart';
import '../data/engine_coach.dart';
import '../domain/coach.dart';
import '../domain/coach_policy.dart';
import 'coach_texts.dart';

/// Guía de maquillaje (docs/ar_engine/COACH.md): la cámara muestra la cara
/// real (sin maquillaje virtual) y cada ~1,5 s se mide y se compara con
/// [look], zona por zona; la indicación se muestra y se dice en voz alta.
/// Manteniendo apretado el botón se ve el look virtual encima.
///
/// Las medidas salen de la cámara antes de componer el maquillaje virtual y
/// se hacen en el teléfono: no se guarda ni se sube ninguna imagen.
class CoachScreen extends StatefulWidget {
  const CoachScreen({super.key, required this.look, this.renderer, this.sampler, this.voice});

  /// El look a seguir (con receta).
  final TestFilterOption look;

  /// Inyectables para tests; por defecto, el motor nativo.
  final IMakeupRenderer? renderer;
  final ICoachSampler? sampler;
  final ICoachVoice? voice;

  @override
  State<CoachScreen> createState() => _CoachScreenState();
}

enum _Phase { intro, reference, running }

class _CoachScreenState extends State<CoachScreen> with WidgetsBindingObserver {
  late final IMakeupRenderer _renderer = widget.renderer ?? createMakeupRenderer();
  late final ICoachSampler _sampler = widget.sampler ?? EngineCoachSampler();
  late final ICoachVoice _voice = widget.voice ?? EngineCoachVoice();
  /// null si el look no tiene zonas que la guía pueda revisar.
  late final CoachSession? _session = _sessionFor(widget.look.recipe);

  // Listas creadas una vez: la vista las compara por identidad y, al cambiar,
  // manda la receta (look virtual mientras se aprieta "ver el look").
  late final List<TestFilterOption> _bare = [
    TestFilterOption(id: 'coach-bare', label: widget.look.label, recipe: null),
  ];
  late final List<TestFilterOption> _target = [widget.look];

  final Stopwatch _clock = Stopwatch()..start();
  Timer? _timer;
  bool _inFlight = false;
  bool _inForeground = true;
  _Phase _phase = _Phase.intro;
  bool _muted = false;
  bool _voiceWarned = false;
  bool _showTarget = false;
  CoachPrompt? _prompt;

  static CoachSession? _sessionFor(MakeupRecipe? recipe) {
    if (recipe == null) return null;
    final target = CoachTarget.from(recipe);
    return target.isEmpty ? null : CoachSession(target);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    unawaited(_voice.stop());
    unawaited(_voice.release());
    super.dispose();
  }

  /// En segundo plano se desmonta la cámara (como el Espejo) y se para todo.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive && _inForeground) {
      _timer?.cancel();
      _timer = null;
      unawaited(_voice.stop());
      setState(() => _inForeground = false);
    } else if (state == AppLifecycleState.resumed && !_inForeground) {
      setState(() => _inForeground = true);
      if (_phase == _Phase.running) _startLoop();
    }
  }

  String _locale(BuildContext context) {
    final code = Localizations.localeOf(context).languageCode;
    return const {'es', 'en', 'pt', 'fr'}.contains(code) ? code : 'es';
  }

  Future<void> _takeReference() async {
    final session = _session;
    if (session == null) return;
    setState(() => _phase = _Phase.reference);
    final samples = <LookMeasurements>[];
    for (var i = 0; i < CoachPolicy.referenceSamples && mounted && _inForeground; i++) {
      samples.add(await _sampler.sample());
    }
    if (!mounted) return;
    if (!session.setBaseline(samples)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.coachReferenceFailed)),
      );
    }
    _run();
  }

  void _run() {
    setState(() => _phase = _Phase.running);
    _startLoop();
  }

  void _startLoop() {
    _timer?.cancel();
    _timer = Timer.periodic(CoachPolicy.samplePeriod, (_) => unawaited(_tick()));
    unawaited(_tick());
  }

  /// Una muestra a la vez: si la anterior no terminó, esta se descarta.
  Future<void> _tick() async {
    final session = _session;
    if (_inFlight || session == null || !_inForeground) return;
    _inFlight = true;
    try {
      final watch = Stopwatch()..start();
      final measurement = await _sampler.sample();
      final ms = watch.elapsedMilliseconds;
      if (!mounted) return;
      final toSay = session.add(measurement, _clock.elapsed);
      setState(() => _prompt = session.current);
      if (toSay != null && !_muted) await _say(toSay);
      // Para medir en el E20 (profile/debug); en release no se pide nada más.
      if (!kReleaseMode) await _log(measurement, ms, session);
    } finally {
      _inFlight = false;
    }
  }

  Future<void> _say(CoachPrompt prompt) async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final spoken = await _voice.speak(coachPromptText(l10n, prompt), locale: _locale(context));
    if (!spoken && !_voiceWarned && mounted) {
      _voiceWarned = true;
      messenger.showSnackBar(SnackBar(content: Text(l10n.coachVoiceUnavailable)));
    }
  }

  /// Línea COACH en logcat para medir en el E20 (COACH.md).
  Future<void> _log(LookMeasurements m, int ms, CoachSession session) async {
    final stats = await _renderer.stats();
    final verdicts = session.verdicts.entries.map((e) => '${e.key.name}:${e.value.name}').join(',');
    debugPrint('COACH ms=$ms status=${m.status.name} eyes=${m.eyeDistancePx.toStringAsFixed(0)} '
        'hz=${stats.trackerHz?.toStringAsFixed(1) ?? '-'} fps=${stats.renderFps?.toStringAsFixed(0) ?? '-'} '
        'focus=${session.focus?.name ?? '-'} verdicts=[$verdicts]');
  }

  void _toggleMute() {
    setState(() => _muted = !_muted);
    if (_muted) unawaited(_voice.stop());
  }

  void _setShowTarget(bool value) {
    if (_showTarget != value) setState(() => _showTarget = value);
  }

  TestFilterLabels _labels(AppLocalizations l10n) => TestFilterLabels(
        noFilter: l10n.testFilterNone,
        intensity: l10n.testFilterIntensity,
        note: l10n.testFilterNote,
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
    final session = _session;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(l10n.coachTitle),
        actions: [
          IconButton(
            key: const ValueKey('coach-mute'),
            tooltip: _muted ? l10n.coachUnmute : l10n.coachMute,
            icon: Icon(_muted ? Icons.volume_off : Icons.volume_up),
            onPressed: _toggleMute,
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: _inForeground
                ? TestFilterView(
                    renderer: _renderer,
                    options: _showTarget ? _target : _bare,
                    initialOptionId: _showTarget ? widget.look.id : _bare.first.id,
                    controls: TestFilterControls.none,
                    showHud: false,
                    labels: _labels(l10n),
                  )
                : const SizedBox.expand(),
          ),
          if (session == null)
            _bottomCard(child: Text(l10n.coachNoZones, style: const TextStyle(fontSize: 16)))
          else ...[
            Positioned(top: 8, left: 8, right: 8, child: _ZoneChips(session: session)),
            _bottomCard(child: _cardContent(l10n)),
          ],
        ],
      ),
    );
  }

  Widget _bottomCard({required Widget child}) => Positioned(
        left: 12,
        right: 12,
        bottom: 16,
        child: Card(
          child: Padding(padding: const EdgeInsets.all(16), child: child),
        ),
      );

  Widget _cardContent(AppLocalizations l10n) {
    switch (_phase) {
      case _Phase.intro:
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.coachIntroTitle, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(l10n.coachIntroBody),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: const ValueKey('coach-skip'),
                    onPressed: _run,
                    child: Text(l10n.coachSkip),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    key: const ValueKey('coach-reference'),
                    onPressed: _takeReference,
                    child: Text(l10n.coachTakeReference),
                  ),
                ),
              ],
            ),
          ],
        );
      case _Phase.reference:
        return Row(
          children: [
            const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: 12),
            Expanded(child: Text(l10n.coachTakingReference)),
          ],
        );
      case _Phase.running:
        final prompt = _prompt;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              prompt == null ? l10n.coachStarting : coachPromptText(l10n, prompt),
              key: const ValueKey('coach-prompt'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            // Mientras se mantiene apretado: el look virtual encima.
            Listener(
              onPointerDown: (_) => _setShowTarget(true),
              onPointerUp: (_) => _setShowTarget(false),
              onPointerCancel: (_) => _setShowTarget(false),
              child: OutlinedButton.icon(
                key: const ValueKey('coach-show-target'),
                onPressed: () {},
                icon: const Icon(Icons.visibility_outlined),
                label: Text(l10n.coachHoldTarget),
              ),
            ),
          ],
        );
    }
  }
}

/// Una ficha por zona del look con su estado: ✓ bien, ↑ falta, ↓ sobra,
/// ~ tono, ? no se ve. La de la zona en foco va resaltada.
class _ZoneChips extends StatelessWidget {
  const _ZoneChips({required this.session});

  final CoachSession session;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final focus = session.focus;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final zone in session.target.zones)
          Chip(
            key: ValueKey('coach-zone-${zone.name}'),
            visualDensity: VisualDensity.compact,
            backgroundColor: zone == focus ? Colors.pink.shade100 : Colors.white,
            avatar: Icon(_icon(session.verdicts[zone]), size: 18, color: _color(session.verdicts[zone])),
            label: Text(coachZoneName(l10n, zone)),
          ),
      ],
    );
  }

  static IconData _icon(CoachVerdict? verdict) => switch (verdict) {
        null => Icons.more_horiz,
        CoachVerdict.ok => Icons.check_circle,
        CoachVerdict.tooLittle || CoachVerdict.tooThin || CoachVerdict.wingShort => Icons.arrow_upward,
        CoachVerdict.tooMuch || CoachVerdict.tooThick || CoachVerdict.wingLong => Icons.arrow_downward,
        CoachVerdict.tooDark || CoachVerdict.tooLight || CoachVerdict.otherTone => Icons.palette_outlined,
        CoachVerdict.notVisible || CoachVerdict.tooFar => Icons.help_outline,
      };

  static Color _color(CoachVerdict? verdict) => switch (verdict) {
        CoachVerdict.ok => Colors.green,
        null || CoachVerdict.notVisible || CoachVerdict.tooFar => Colors.grey,
        _ => Colors.orange,
      };
}

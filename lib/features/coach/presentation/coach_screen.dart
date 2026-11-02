import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

  /// Se está saliendo de la guía (pop en curso): dispose llega recién al
  /// terminar la transición y hasta entonces no se mide ni se habla.
  bool _leaving = false;

  /// Sube con cada pausa: una muestra pedida antes no vale después, aunque la
  /// app ya haya vuelto (es de la cámara anterior).
  int _epoch = 0;

  /// El motor no puede dibujar en este equipo (o AR_RENDERER=painter): sin
  /// cara en vivo no hay qué medir y la guía muestra los pasos del look.
  bool _unavailable = false;

  /// Pasos del look para seguir sin cámara, y el actual (= cantidad: terminó).
  late final List<CoachStep> _steps = switch (_session) {
    final session? => CoachStep.fromTarget(session.target),
    null => const <CoachStep>[],
  };
  int _step = 0;

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
      _epoch++;
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
    final epoch = _epoch;
    final samples = <LookMeasurements>[];
    for (var i = 0; i < CoachPolicy.referenceSamples; i++) {
      final sample = await _sampler.sample();
      if (!_active || epoch != _epoch) break;
      samples.add(sample);
    }
    if (!mounted || _leaving) return;
    // Se pausó en medio: una referencia a medias confunde más que ninguna.
    // Vuelve a "Antes de empezar" para tomarla de nuevo o saltearla.
    if (!_active || epoch != _epoch) {
      setState(() => _phase = _Phase.intro);
      return;
    }
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

  /// Mide solo con la guía a la vista: en segundo plano, saliendo o sin motor
  /// no hay cámara que medir ni nadie a quien hablarle.
  bool get _active => mounted && _inForeground && !_leaving && !_unavailable;

  void _startLoop() {
    if (!_active) return;
    _timer?.cancel();
    _timer = Timer.periodic(CoachPolicy.samplePeriod, (_) => unawaited(_tick()));
    unawaited(_tick());
  }

  /// Una muestra a la vez: si la anterior no terminó, esta se descarta.
  Future<void> _tick() async {
    final session = _session;
    if (_inFlight || session == null || !_active) return;
    _inFlight = true;
    final epoch = _epoch;
    try {
      final watch = Stopwatch()..start();
      final measurement = await _sampler.sample();
      final ms = watch.elapsedMilliseconds;
      // Se pausó o se salió mientras se medía (aunque ya haya vuelto): la
      // muestra es de la cámara anterior y se descarta.
      if (!_active || epoch != _epoch) return;
      final before = session.verdicts;
      final wasDone = session.done;
      final toSay = session.add(measurement, _clock.elapsed);
      setState(() => _prompt = session.current);
      _hapticFor(before, session, wasDone);
      // Sin esperar a la voz: si el TextToSpeech tarda en arrancar (o no
      // responde), las muestras siguen.
      if (toSay != null) unawaited(_say(toSay));
      // Para medir en el E20 (profile/debug); en release no se pide nada más.
      if (!kReleaseMode && _active) await _log(measurement, ms, session);
    } finally {
      _inFlight = false;
    }
  }

  /// Vibración corta cuando una zona queda bien y otra más marcada al
  /// terminar: la usuaria tiene el pincel en la mano y no siempre mira la
  /// pantalla. HapticFeedback es de Flutter (sin dependencias).
  void _hapticFor(Map<CoachZone, CoachVerdict> before, CoachSession session, bool wasDone) {
    if (session.done && !wasDone) {
      unawaited(HapticFeedback.mediumImpact());
      return;
    }
    final newlyOk = session.verdicts.entries
        .any((e) => e.value == CoachVerdict.ok && before[e.key] != null && before[e.key] != CoachVerdict.ok);
    if (newlyOk) unawaited(HapticFeedback.lightImpact());
  }

  /// Dice [prompt] con el mismo texto que la pantalla y en el idioma de la
  /// app; corta lo que se estaba diciendo.
  Future<void> _say(CoachPrompt prompt) async {
    if (!_active) return;
    await _speak(coachPromptText(AppLocalizations.of(context)!, prompt));
  }

  /// Hay alguien mirando y la voz no está silenciada (también sin motor: los
  /// pasos sin cámara se dicen igual).
  bool get _canSpeak => mounted && _inForeground && !_leaving && !_muted;

  Future<void> _speak(String text) async {
    if (!_canSpeak) return;
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final spoken = await _voice.speak(text, locale: _locale(context));
    if (!spoken && !_voiceWarned && mounted && !_leaving) {
      _voiceWarned = true;
      messenger.showSnackBar(SnackBar(content: Text(l10n.coachVoiceUnavailable)));
    }
  }

  /// El motor no pudo abrir la cámara: en lugar de un callejón sin salida,
  /// la guía pasa a los pasos del look (de la receta, sin medir ni IA).
  void _onEngineUnavailable() {
    if (!mounted || _unavailable) return;
    _timer?.cancel();
    _timer = null;
    unawaited(_voice.stop());
    setState(() {
      _unavailable = true;
      _step = 0;
    });
    _speakStep();
  }

  /// Dice el paso actual, o que terminó.
  void _speakStep() {
    if (_steps.isEmpty) return;
    final l10n = AppLocalizations.of(context)!;
    unawaited(_speak(_step < _steps.length ? coachStepText(l10n, _steps[_step]) : l10n.coachStepsFinished));
  }

  /// Pasa al paso [index] (0..cantidad; cantidad = terminó) y lo dice.
  void _goToStep(int index) {
    final next = index.clamp(0, _steps.length);
    if (next == _step) return;
    final forward = next > _step;
    setState(() => _step = next);
    if (forward) {
      unawaited(next == _steps.length ? HapticFeedback.mediumImpact() : HapticFeedback.lightImpact());
    }
    _speakStep();
  }

  /// Línea COACH en logcat para medir en el E20 (COACH.md).
  Future<void> _log(LookMeasurements m, int ms, CoachSession session) async {
    final stats = await _renderer.stats();
    final verdicts = session.verdicts.entries.map((e) => '${e.key.name}:${e.value.name}').join(',');
    debugPrint('COACH ms=$ms status=${m.status.name} eyes=${m.eyeDistancePx.toStringAsFixed(0)} '
        'hz=${stats.trackerHz?.toStringAsFixed(1) ?? '-'} fps=${stats.renderFps?.toStringAsFixed(0) ?? '-'} '
        'focus=${session.focus?.name ?? '-'} verdicts=[$verdicts]');
  }

  /// Silenciar corta la voz en el acto; al reactivarla se dice la indicación
  /// que está en pantalla (si viene de una muestra válida).
  void _toggleMute() {
    final muted = !_muted;
    setState(() => _muted = muted);
    if (muted) {
      unawaited(_voice.stop());
      return;
    }
    if (_unavailable) {
      _speakStep();
      return;
    }
    final prompt = _phase == _Phase.running && _active ? _session?.resume(_clock.elapsed) : null;
    if (prompt != null) unawaited(_say(prompt));
  }

  /// Al salir (atrás o gesto del sistema) la voz se calla enseguida, sin
  /// esperar a que termine la transición; dispose libera el motor de voz.
  void _onPop(bool didPop, Object? _) {
    if (!didPop || _leaving) return;
    _leaving = true;
    _timer?.cancel();
    _timer = null;
    unawaited(_voice.stop());
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
    return PopScope<Object?>(
      onPopInvokedWithResult: _onPop,
      child: Scaffold(
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
        body: _body(l10n, session),
      ),
    );
  }

  Widget _body(AppLocalizations l10n, CoachSession? session) {
    return Stack(
      children: [
        Positioned.fill(
          // Sin motor no se vuelve a montar la cámara (por ejemplo al volver de
          // segundo plano): la guía sigue con los pasos.
          child: _inForeground && !_unavailable
              ? TestFilterView(
                  renderer: _renderer,
                  options: _showTarget ? _target : _bare,
                  initialOptionId: _showTarget ? widget.look.id : _bare.first.id,
                  controls: TestFilterControls.none,
                  showHud: false,
                  labels: _labels(l10n),
                  onUnavailable: _onEngineUnavailable,
                )
              : const SizedBox.expand(),
        ),
        if (session == null)
          _bottomCard(child: Text(l10n.coachNoZones, style: const TextStyle(fontSize: 16)))
        else if (_unavailable)
          Positioned.fill(child: _stepsView(l10n))
        else ...[
          Positioned(top: 8, left: 8, right: 8, child: _ZoneChips(session: session)),
          _bottomCard(child: _cardContent(l10n)),
        ],
      ],
    );
  }

  /// Sin cámara: los pasos del look en orden, con su color. "Hecho" avanza y
  /// dice el siguiente; tocar un paso vuelve a él.
  Widget _stepsView(AppLocalizations l10n) {
    final theme = Theme.of(context);
    final finished = _step >= _steps.length;
    return ColoredBox(
      color: theme.colorScheme.surface,
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(l10n.coachStepsTitle, style: theme.textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(l10n.coachStepsIntro),
                  const SizedBox(height: 12),
                  for (var i = 0; i < _steps.length; i++)
                    _StepTile(
                      key: ValueKey('coach-step-$i'),
                      number: i + 1,
                      text: coachStepText(l10n, _steps[i]),
                      color: _steps[i].color,
                      done: i < _step,
                      current: i == _step,
                      onTap: () => _goToStep(i),
                    ),
                  if (finished)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        l10n.coachStepsFinished,
                        key: const ValueKey('coach-steps-finished'),
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!finished)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        l10n.coachStepProgress(_step + 1, _steps.length),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          key: const ValueKey('coach-step-back'),
                          onPressed: _step == 0 ? null : () => _goToStep(_step - 1),
                          child: Text(l10n.coachStepBack),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: finished
                            ? FilledButton(
                                key: const ValueKey('coach-steps-restart'),
                                onPressed: () => _goToStep(0),
                                child: Text(l10n.coachStepsRestart),
                              )
                            : FilledButton(
                                key: const ValueKey('coach-step-next'),
                                onPressed: () => _goToStep(_step + 1),
                                child: Text(l10n.coachStepNext),
                              ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
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

/// Un paso sin cámara: número (o ✓ si ya está), la indicación y el color de
/// la receta. El actual va resaltado.
class _StepTile extends StatelessWidget {
  const _StepTile({
    super.key,
    required this.number,
    required this.text,
    required this.color,
    required this.done,
    required this.current,
    required this.onTap,
  });

  final int number;
  final String text;
  final RecipeColor? color;
  final bool done;
  final bool current;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final swatch = color;
    return Card(
      color: current ? Colors.pink.shade50 : null,
      child: ListTile(
        selected: current,
        selectedColor: Colors.black87,
        leading: done
            ? const Icon(Icons.check_circle, color: Colors.green)
            : CircleAvatar(radius: 14, child: Text('$number', style: const TextStyle(fontSize: 13))),
        title: Text(text),
        trailing: swatch == null
            ? null
            : ExcludeSemantics(
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF000000 | swatch.rgb),
                    border: Border.all(color: Colors.black26),
                  ),
                ),
              ),
        onTap: onTap,
      ),
    );
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

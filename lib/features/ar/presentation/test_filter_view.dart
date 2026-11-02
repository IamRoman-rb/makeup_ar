import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/makeup_renderer_factory.dart';
import '../domain/i_makeup_renderer.dart';
import '../domain/makeup_recipe.dart';
import '../domain/recipe_adjustments.dart';
import '../domain/recipe_presets.dart';
import 'camera_permission_gate.dart';

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

  /// Color de muestra del chip: el de los labios o, si no hay, el de otra región.
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
    required this.showPoints,
    required this.compare,
    required this.matte,
    required this.satin,
    required this.gloss,
    required this.shimmer,
    required this.zoneAll,
    required this.zoneLips,
    required this.zoneEyes,
    required this.zoneCheeks,
    required this.zoneSkin,
    required this.unavailable,
    this.lightAdaptation,
  });

  final String noFilter;
  final String intensity;
  final String note;
  final String showPoints;

  /// Botón que, mientras se mantiene apretado, muestra la cámara sin maquillaje.
  final String compare;
  final String matte;
  final String satin;
  final String gloss;
  final String shimmer;
  final String zoneAll;
  final String zoneLips;
  final String zoneEyes;
  final String zoneCheeks;
  final String zoneSkin;

  /// El maquillaje en vivo no está disponible en este equipo.
  final String unavailable;

  /// Chip para prender y apagar la adaptación a la luz (comparación A/B en
  /// el arnés); null = sin chip.
  final String? lightAdaptation;

  String finish(LipFinish finish) => switch (finish) {
        LipFinish.matte => matte,
        LipFinish.satin => satin,
        LipFinish.gloss => gloss,
        LipFinish.shimmer => shimmer,
      };

  String zone(MakeupZone zone) => switch (zone) {
        MakeupZone.all => zoneAll,
        MakeupZone.lips => zoneLips,
        MakeupZone.eyes => zoneEyes,
        MakeupZone.cheeks => zoneCheeks,
        MakeupZone.skin => zoneSkin,
      };
}

/// Controles de abajo de [TestFilterView]. El badge de FPS (arriba) y el botón
/// de comparar (abajo, encima de estos controles) se ven siempre, salvo en el
/// Espejo.
enum TestFilterControls {
  /// Opciones, zonas, puntos, acabado e intensidad (arnés del tracker).
  full,

  /// Solo el slider de intensidad: un look del catálogo, sin otros filtros.
  intensity,

  /// Nada: quien la monta pone sus propios controles (Studio).
  none,
}

/// Filtro de prueba del motor de maquillaje para el Espejo.
///
/// Cada preset se aplica completo (labios, rubor, piel y ojos; ver
/// docs/ar_engine/FACE.md). Los chips de zona muestran una región sola para
/// comparar o capturar; el slider escala todas las opacidades; los chips de
/// acabado cambian el del labial. "Ver puntos" dibuja los landmarks y el botón
/// de comparar muestra la cámara sin maquillaje mientras se mantiene apretado.
///
/// Dueña del renderer mientras está montada: lo inicia en initState y lo
/// detiene en dispose. Si el renderer no puede dibujar en este equipo (o es el
/// respaldo, `AR_RENDERER=painter`), muestra el aviso y llama a
/// [onUnavailable] para que quien la monta vuelva al espejo normal. Bloquea la
/// pantalla en vertical, la única orientación validada del motor. Quien la
/// monte tiene que haber liberado antes cualquier otro uso de la cámara.
class TestFilterView extends StatefulWidget {
  const TestFilterView({
    super.key,
    required this.labels,
    this.renderer,
    this.onUnavailable,
    this.extraOptions = const [],
    this.options,
    this.initialOptionId,
    this.onOptionSelected,
    this.mirrorOnly = false,
    this.controls = TestFilterControls.full,
    this.showHud = true,
    this.showStats = true,
    this.cameraPermission,
    this.bottomAction,
    this.coveredBottom,
  });

  final TestFilterLabels labels;

  /// Inyectable para tests; por defecto, el de `AR_RENDERER`.
  final IMakeupRenderer? renderer;

  /// Permiso de cámara pedido en contexto antes de abrir la cámara. null =
  /// el del sistema en Android cuando la vista crea su propio renderer (el
  /// motor nativo no lo pide); en iOS lo pide el motor y en los tests con un
  /// renderer inyectado no se pide.
  final ICameraPermission? cameraPermission;

  /// El renderer no puede mostrar maquillaje (ver [IMakeupRenderer.start]).
  final VoidCallback? onUnavailable;

  /// Opciones después de los presets (el arnés suma recetas de prueba).
  final List<TestFilterOption> extraOptions;

  /// Reemplaza "sin filtro" + presets + [extraOptions] (Studio: las variantes
  /// generadas). Si cambia, la vista conserva la opción elegida por id y
  /// vuelve a mandar su receta si cambió (edición en vivo).
  final List<TestFilterOption>? options;

  /// Opción elegida al iniciar (y si la elegida desaparece); por defecto, la
  /// primera receta.
  final String? initialOptionId;

  /// El usuario eligió otra opción.
  final ValueChanged<TestFilterOption>? onOptionSelected;

  /// Espejo: la cámara sola, sin maquillaje, tracker ni controles. Cambiarlo
  /// no reinicia el renderer (la cámara sigue abierta) y conserva el look
  /// elegido para cuando se vuelve al filtro.
  final bool mirrorOnly;

  /// Qué controles se ven abajo.
  final TestFilterControls controls;

  /// Badge de FPS (arriba) y botón de comparar (abajo a la derecha, al
  /// alcance del pulgar). La guía de maquillaje los oculta: ahí la usuaria
  /// tiene que ver su cara tal cual.
  final bool showHud;

  /// Badge de FPS y estado del tracker (texto de depuración). La app lo oculta
  /// en release; el arnés y los builds de profile lo muestran para medir.
  final bool showStats;

  /// Botón de quien monta la vista, en la misma fila que comparar y a su
  /// izquierda ("Guíame" en el Espejo con un look): comparten la fila sin
  /// taparse. No se ve en el Espejo sin look.
  final Widget? bottomAction;

  /// Fracción del alto de la vista (0..1) que tapa desde abajo un panel de
  /// quien la monta (el panel arrastrable del Studio): la fila de comparar se
  /// ubica justo encima y lo sigue al arrastrarlo.
  final ValueListenable<double>? coveredBottom;

  @override
  State<TestFilterView> createState() => _TestFilterViewState();
}

class _TestFilterViewState extends State<TestFilterView> {
  static const Duration _statsPeriod = Duration(seconds: 1);

  late final IMakeupRenderer _rendererInstance = widget.renderer ?? createMakeupRenderer();

  /// Si la persona niega la cámara (o el diálogo del sistema desmonta la
  /// vista), el renderer nativo nunca se crea: dispose no lo construye solo
  /// para detenerlo.
  bool _rendererUsed = false;

  IMakeupRenderer get _renderer {
    _rendererUsed = true;
    return _rendererInstance;
  }
  late List<TestFilterOption> _options = _buildOptions();
  final ValueNotifier<MakeupRendererStats> _stats = ValueNotifier(MakeupRendererStats.empty);

  MakeupSurface? _surface;
  bool _unavailable = false;

  /// Sin permiso de cámara (no se llama a onUnavailable: el espejo de
  /// respaldo volvería a pedir el permiso que la persona acaba de negar).
  CameraAccess? _cameraDenied;
  bool _starting = false;
  Timer? _statsTimer;
  bool _statsInFlight = false;
  bool _lookInFlight = false;
  bool _lookDirty = false;
  late TestFilterOption _selected = _initialOption();
  MakeupZone _zone = MakeupZone.all;
  double _intensity = 1.0;

  /// Acabado de labial elegido en los chips; null = el del preset.
  LipFinish? _finish;
  bool _showPoints = false;
  bool _lightAdaptation = true;
  bool _comparing = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    unawaited(_start());
  }

  List<TestFilterOption> _buildOptions() =>
      widget.options ?? [...TestFilterOption.fromPresets(widget.labels.noFilter), ...widget.extraOptions];

  TestFilterOption _initialOption() {
    final wanted = widget.initialOptionId;
    for (final option in _options) {
      if (option.id == wanted) return option;
    }
    return _options.firstWhere((option) => option.recipe != null, orElse: () => _options.first);
  }

  @override
  void didUpdateWidget(TestFilterView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // El botón desapareció con el dedo encima (no llega el pointer up): vuelve
    // el look para cuando reaparezca.
    if (_comparing && (widget.mirrorOnly || !widget.showHud)) {
      _comparing = false;
      unawaited(_applyLook());
    }
    if (widget.mirrorOnly != oldWidget.mirrorOnly) unawaited(_syncMirror());
    if (identical(widget.options, oldWidget.options) && identical(widget.extraOptions, oldWidget.extraOptions)) {
      return;
    }
    final previous = _selected;
    _options = _buildOptions();
    final current = _options.where((option) => option.id == previous.id).firstOrNull ?? _initialOption();
    _selected = current;
    if (!identical(current.recipe, previous.recipe)) unawaited(_applyLook());
  }

  @override
  void dispose() {
    _statsTimer?.cancel();
    _stats.dispose();
    if (_rendererUsed) unawaited(_rendererInstance.stop());
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  /// Prende o apaga el tracker según [TestFilterView.mirrorOnly] y manda el
  /// look (null en el Espejo). Antes de start solo queda guardado.
  Future<void> _syncMirror() async {
    await _renderer.setTrackingEnabled(!widget.mirrorOnly);
    if (mounted) await _applyLook();
  }

  ICameraPermission? get _cameraPermission =>
      widget.cameraPermission ?? (widget.renderer == null && Platform.isAndroid ? const SystemCameraPermission() : null);

  /// Reintento desde la vista de permiso denegado (un toque de la persona).
  void _retryCamera() {
    if (_starting) return;
    setState(() => _cameraDenied = null);
    unawaited(_start(userInitiated: true));
  }

  Future<void> _start({bool userInitiated = false}) async {
    if (_starting) return;
    _starting = true;
    try {
      final permission = _cameraPermission;
      if (permission != null) {
        CameraAccess access;
        try {
          access = await ensureCameraAccess(context, permission, userInitiated: userInitiated);
        } catch (e) {
          // Canal de permission_handler roto: mejor la vista de permiso que un
          // spinner eterno.
          debugPrint('TestFilterView: no se pudo consultar el permiso (${e.runtimeType})');
          access = CameraAccess.denied;
        }
        if (!mounted) return;
        if (access != CameraAccess.granted) {
          setState(() => _cameraDenied = access);
          return;
        }
      }
      await _startRenderer();
    } finally {
      _starting = false;
    }
  }

  Future<void> _startRenderer() async {
    // Antes de abrir la cámara: un Espejo no llega a cargar los modelos.
    if (widget.mirrorOnly) await _renderer.setTrackingEnabled(false);
    final surface = await _renderer.start();
    if (!mounted) {
      await _renderer.stop();
      return;
    }
    if (surface == null) {
      debugPrint('TestFilterView: sin maquillaje en vivo (${_renderer.unavailableReason})');
      setState(() => _unavailable = true);
      widget.onUnavailable?.call();
      return;
    }
    setState(() => _surface = surface);
    await _applyLook();
    // Si se desmontó durante los awaits, dispose() ya pasó: no crear el timer.
    if (!mounted) return;
    _statsTimer = Timer.periodic(_statsPeriod, (_) => _pollStats());
  }

  /// Nunca hay más de un pedido de métricas en vuelo: los demás se descartan.
  Future<void> _pollStats() async {
    // Sin indicador a la vista no hay nada que actualizar.
    if (_statsInFlight || widget.mirrorOnly || !widget.showHud || !widget.showStats) return;
    _statsInFlight = true;
    try {
      final stats = await _renderer.stats();
      if (mounted) _stats.value = stats;
    } finally {
      _statsInFlight = false;
    }
  }

  /// Manda el look actual. El slider genera muchos eventos por segundo: solo
  /// se envía el último estado.
  Future<void> _applyLook() async {
    _lookDirty = true;
    if (_lookInFlight) return;
    _lookInFlight = true;
    try {
      while (_lookDirty && mounted) {
        _lookDirty = false;
        final recipe = _selected.recipe;
        await _renderer.applyRecipe(
          recipe == null || _comparing || widget.mirrorOnly
              ? null
              : adjustRecipe(recipe, zone: _zone, intensity: _intensity, lipFinish: _finish),
        );
      }
    } finally {
      _lookInFlight = false;
    }
  }

  void _select(TestFilterOption option) {
    setState(() {
      _selected = option;
      _finish = null;
    });
    widget.onOptionSelected?.call(option);
    unawaited(_applyLook());
  }

  void _setZone(MakeupZone zone) {
    setState(() => _zone = zone);
    unawaited(_applyLook());
  }

  void _setShowPoints(bool value) {
    setState(() => _showPoints = value);
    unawaited(_renderer.setShowLandmarks(value));
  }

  void _setLightAdaptation(bool value) {
    setState(() => _lightAdaptation = value);
    unawaited(_renderer.setLightAdaptation(value));
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
    final surface = _surface;
    final denied = _cameraDenied;
    if (denied != null) {
      return CameraDeniedView(
        access: denied,
        onRetry: _retryCamera,
        onOpenSettings: () => unawaited(_cameraPermission?.openSettings()),
        fallbackText: widget.labels.unavailable,
      );
    }
    if (_unavailable) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(widget.labels.unavailable, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white)),
        ),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        if (surface == null)
          const Center(child: CircularProgressIndicator(color: Colors.pink))
        else
          // Igual que el espejo: llena la pantalla recortando los bordes.
          ClipRect(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: surface.width.toDouble(),
                height: surface.height.toDouble(),
                child: Texture(textureId: surface.textureId),
              ),
            ),
          ),
        if (!widget.mirrorOnly) ...[
          if (widget.showHud && widget.showStats) Positioned(top: 8, left: 8, child: _FpsBadge(stats: _stats)),
          if (_buildBottom() case final bottom?) _positionBottom(bottom),
        ],
      ],
    );
  }

  /// Abajo de todo los controles; encima, la fila de comparar (y la acción de
  /// quien monta la vista). Sin controles ni panel debajo, la fila respeta el
  /// área de gestos del sistema.
  Widget? _buildBottom() {
    final controls = _buildControls();
    final actions = _buildActionRow();
    if (actions == null) return controls;
    final row = Padding(padding: const EdgeInsets.fromLTRB(12, 0, 12, 12), child: actions);
    final bare = controls == null && widget.coveredBottom == null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (bare) SafeArea(top: false, child: row) else row,
        ?controls,
      ],
    );
  }

  /// Pegado abajo, o encima del panel de quien monta la vista
  /// ([TestFilterView.coveredBottom]); nunca más arriba que [_minTopGap].
  Widget _positionBottom(Widget bottom) {
    final covered = widget.coveredBottom;
    if (covered == null) return Positioned(left: 0, right: 0, bottom: 0, child: bottom);
    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, constraints) => ValueListenableBuilder<double>(
          valueListenable: covered,
          child: bottom,
          builder: (context, fraction, child) {
            final height = constraints.maxHeight;
            final inset = math.min(height * fraction.clamp(0.0, 1.0), math.max(0.0, height - _minTopGap));
            return Padding(
              padding: EdgeInsets.only(bottom: inset),
              child: Align(alignment: Alignment.bottomCenter, child: child),
            );
          },
        ),
      ),
    );
  }

  /// Espacio que la fila de comparar deja arriba cuando el panel de abajo
  /// sube casi hasta el tope (que siga a la vista).
  static const double _minTopGap = 72;

  /// La acción de quien monta la vista a la izquierda, comparar a la derecha
  /// (donde llega el pulgar). La acción conserva su ancho; si no entran,
  /// el texto de comparar pasa a dos líneas en lugar de taparla.
  Widget? _buildActionRow() {
    final action = widget.bottomAction;
    final compare = widget.showHud ? _buildCompareButton() : null;
    if (action == null && compare == null) return null;
    return Row(
      mainAxisAlignment: action == null ? MainAxisAlignment.end : MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        ?action,
        if (action != null && compare != null) const SizedBox(width: 12),
        if (compare != null) Flexible(child: compare),
      ],
    );
  }

  /// Mientras se mantiene apretado: cámara sin maquillaje (antes/después).
  /// Al soltar o si el sistema cancela el toque (otro gesto, una llamada),
  /// vuelve el look. Área táctil de 48 dp como mínimo; apretado se invierte
  /// (fondo blanco) para que se note sin mirar el texto.
  Widget _buildCompareButton() {
    final foreground = _comparing ? Colors.black : Colors.white;
    return Semantics(
      button: true,
      label: widget.labels.compare,
      excludeSemantics: true,
      child: Listener(
        key: const ValueKey('filter-compare'),
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) => _setComparing(true),
        onPointerUp: (_) => _setComparing(false),
        onPointerCancel: (_) => _setComparing(false),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          child: DecoratedBox(
            decoration: BoxDecoration(
              // Negro al 65 %: el texto blanco mantiene más de 4,5:1 aunque la
              // cámara detrás sea blanca.
              color: _comparing ? Colors.white : Colors.black.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white70, width: 1.5),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.compare, color: foreground, size: 20),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      widget.labels.compare,
                      style: TextStyle(color: foreground, fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Slider que escala todas las opacidades del look elegido.
  Widget _buildIntensity() => Row(
        children: [
          Text(widget.labels.intensity, style: const TextStyle(color: Colors.white, fontSize: 12)),
          Expanded(
            child: Slider(
              value: _intensity,
              max: kMaxRecipeIntensity,
              activeColor: Colors.pink,
              onChanged: (value) {
                setState(() => _intensity = value);
                unawaited(_applyLook());
              },
            ),
          ),
        ],
      );

  /// null = sin controles abajo ([TestFilterControls.none], o solo intensidad
  /// sin receta).
  Widget? _buildControls() {
    final recipe = _selected.recipe;
    switch (widget.controls) {
      case TestFilterControls.none:
        return null;
      case TestFilterControls.intensity:
        if (recipe == null) return null;
        return Container(
          color: Colors.black54,
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          child: _buildIntensity(),
        );
      case TestFilterControls.full:
        return _buildFullControls();
    }
  }

  Widget _buildFullControls() {
    final labels = widget.labels;
    final recipe = _selected.recipe;
    final lips = _selected.lips;
    final showFinish = lips != null && (_zone == MakeupZone.all || _zone == MakeupZone.lips);
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
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final zone in MakeupZone.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(labels.zone(zone)),
                      selected: zone == _zone,
                      onSelected: (_) => _setZone(zone),
                    ),
                  ),
                FilterChip(label: Text(labels.showPoints), selected: _showPoints, onSelected: _setShowPoints),
                if (labels.lightAdaptation case final light?)
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: FilterChip(
                      label: Text(light),
                      selected: _lightAdaptation,
                      onSelected: _setLightAdaptation,
                    ),
                  ),
              ],
            ),
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
          if (showFinish) ...[
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
          if (recipe != null) _buildIntensity(),
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

/// FPS del render y estado del tracker, y error asíncrono si lo hay. Texto de
/// depuración: no se traduce.
class _FpsBadge extends StatelessWidget {
  const _FpsBadge({required this.stats});

  final ValueListenable<MakeupRendererStats> stats;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<MakeupRendererStats>(
      valueListenable: stats,
      builder: (context, s, _) {
        final fps = s.renderFps;
        final error = s.error;
        final text = error != null
            ? 'Motor: $error'
            : 'Motor nativo · ${fps == null ? '—' : fps.toStringAsFixed(0)} fps\n${trackerLabel(s)}';
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(6)),
          child: Text(text, style: TextStyle(color: error != null ? Colors.orangeAccent : Colors.greenAccent, fontSize: 11)),
        );
      },
    );
  }
}

/// Una línea con el estado del tracker para el badge. El maquillaje siempre
/// necesita el tracker: "apagado" solo se ve un instante al iniciar.
@visibleForTesting
String trackerLabel(MakeupRendererStats stats) {
  switch (stats.tracking) {
    case FaceTrackingState.off:
      return 'Tracker: iniciando…';
    case FaceTrackingState.loading:
      return 'Tracker: cargando modelos…';
    case FaceTrackingState.searching:
      return 'Tracker: buscando cara…';
    case FaceTrackingState.tracking:
      final hz = stats.trackerHz;
      final ms = stats.landmarkMs;
      return 'Tracker: ${hz == null ? '—' : hz.toStringAsFixed(0)} Hz · '
          '${ms == null ? '—' : ms.toStringAsFixed(0)} ms';
  }
}

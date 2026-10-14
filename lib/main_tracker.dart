import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:makeup_engine/makeup_engine.dart';
import 'package:permission_handler/permission_handler.dart';

import 'features/ar/domain/makeup_recipe.dart';
import 'features/ar/domain/recipe_presets.dart';
import 'features/ar/presentation/test_filter_view.dart';
import 'features/studio/data/engine_image_analyzer.dart';
import 'features/studio/domain/image_recipe.dart';

/// Arnés de medición de P3 (tracker + compositor), separado de la app (sin
/// Firebase ni RevenueCat): el filtro de prueba del Espejo a pantalla completa
/// y, cada 5 s, una línea `TRACK ...` con las métricas en logcat (etiqueta
/// flutter). Medir siempre en profile:
///   `flutter run --profile -t lib/main_tracker.dart -d <id>`
/// Pide el permiso de cámara antes de montar la vista.
///
/// F4: "Foto" mide el maquillaje de una foto de la galería y suma sus 3
/// variantes como chips (línea `PHOTO ...` en logcat con el tiempo, el estado,
/// la confianza y el error de ajuste por región); "Paleta" deja los colores de
/// una foto de producto en una línea `PALETTE ...`. La foto no se guarda.
void main() {
  runApp(const MaterialApp(debugShowCheckedModeBanner: false, home: _TrackerHarness()));
}

class _TrackerHarness extends StatefulWidget {
  const _TrackerHarness();

  @override
  State<_TrackerHarness> createState() => _TrackerHarnessState();
}

class _TrackerHarnessState extends State<_TrackerHarness> {
  static const Duration _logPeriod = Duration(seconds: 5);

  // Fachada sin estado sobre el mismo canal: la vista es la dueña de la sesión.
  final MakeupEngine _engine = MakeupEngine();
  final Stopwatch _clock = Stopwatch()..start();
  Timer? _timer;
  bool _inFlight = false;
  bool? _granted;
  final EngineImageAnalyzer _analyzer = EngineImageAnalyzer();
  late List<TestFilterOption> _extraOptions = [_lipLinerOption()];
  bool _analyzing = false;

  @override
  void initState() {
    super.initState();
    unawaited(_requestCamera());
  }

  Future<void> _requestCamera() async {
    final status = await Permission.camera.request();
    if (!mounted) return;
    setState(() => _granted = status.isGranted);
    if (status.isGranted) _timer = Timer.periodic(_logPeriod, (_) => _log());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _log() async {
    if (_inFlight) return;
    _inFlight = true;
    try {
      final s = await _engine.getStats();
      final t = s.tracker;
      debugPrint('TRACK t=${_clock.elapsed.inSeconds}s '
          'fps=${_f(s.renderFps)} cpuP95=${_f(s.cpuP95Ms)} frameP95=${_f(s.intervalP95Ms)} '
          'state=${t.state.name} hz=${_f(t.hz)} lmP50=${_f(t.landmarkP50Ms)} lmP95=${_f(t.landmarkP95Ms)} '
          'detP50=${_f(t.detectorP50Ms)} readback=${_f(t.readbackMs)} cropFails=${t.cropFailures} jitter=${_f(t.jitterP50Px, 2)} '
          'presence=${_f(t.presence, 2)} occl=${_f(t.occlusionGate, 2)} yaw=${_f(t.yawDeg)} pitch=${_f(t.pitchDeg)} roll=${_f(t.rollDeg)} '
          'runs=${t.landmarkRuns}/${t.detectorRuns} losses=${t.losses} init=${_f(t.initMs, 0)} '
          'backend="${t.backend ?? '-'}" error="${s.error ?? t.error ?? '-'}"');
    } on Exception catch (e) {
      debugPrint('TRACK error $e');
    } finally {
      _inFlight = false;
    }
  }

  Future<Uint8List?> _pickPhoto() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 2048, maxHeight: 2048, imageQuality: 95);
    return file?.readAsBytes();
  }

  /// Foto de referencia -> receta (F4) con su reporte en logcat.
  Future<void> _analyzePhoto() async {
    if (_analyzing) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _analyzing = true);
    try {
      final bytes = await _pickPhoto();
      if (bytes == null || !mounted) return;
      final watch = Stopwatch()..start();
      final measurements = await _analyzer.analyzeFace(bytes);
      final ms = watch.elapsedMilliseconds;
      final result = ImageRecipeBuilder.build(measurements, name: 'Foto · fiel');
      final regions = result.regions
          .map((r) => '${r.layer.name}:${_f(r.confidence, 2)}/${_f(r.fitError, 4)}')
          .join(' ');
      debugPrint('PHOTO ms=$ms status=${result.status.name} yaw=${_f(measurements.yawRatio, 2)} '
          'liner=${_f(measurements.linerExtent, 2)} wing=${_f(measurements.wingExtent, 2)} '
          'worstFit=${_f(result.worstFitError, 4)} regions=[$regions]');
      final recipe = result.recipe;
      if (recipe == null) {
        messenger.showSnackBar(SnackBar(content: Text('Foto: ${result.status.name}')));
        return;
      }
      final variants = ImageRecipeBuilder.variants(recipe, names: const ['Foto · fiel', 'Foto · intensa', 'Foto · sutil']);
      setState(() {
        _extraOptions = [
          _lipLinerOption(),
          for (var i = 0; i < variants.length; i++)
            TestFilterOption(id: 'photo-${_clock.elapsedMilliseconds}-$i', label: variants[i].name, recipe: variants[i]),
        ];
      });
      messenger.showSnackBar(SnackBar(
        content: Text('Foto en $ms ms · ajuste ${_f(result.worstFitError, 3)} · ${result.regions.length} regiones'),
      ));
    } on Exception catch (e) {
      debugPrint('PHOTO error $e');
      messenger.showSnackBar(SnackBar(content: Text('Foto: $e')));
    } finally {
      if (mounted) setState(() => _analyzing = false);
    }
  }

  /// Foto de producto -> paleta (F4) en logcat.
  Future<void> _analyzePalette() async {
    if (_analyzing) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _analyzing = true);
    try {
      final bytes = await _pickPhoto();
      if (bytes == null || !mounted) return;
      final watch = Stopwatch()..start();
      final swatches = await _analyzer.palette(bytes);
      final text = swatches.map((s) => '${s.color.toHex()} ${(s.fraction * 100).round()}%').join(' ');
      debugPrint('PALETTE ms=${watch.elapsedMilliseconds} $text');
      messenger.showSnackBar(SnackBar(content: Text(text.isEmpty ? 'Paleta vacía' : text)));
    } on Exception catch (e) {
      debugPrint('PALETTE error $e');
    } finally {
      if (mounted) setState(() => _analyzing = false);
    }
  }

  /// Receta de prueba: ningún preset usa el delineado de labios (P6b). Rojo
  /// clásico con un delineado bordó.
  static TestFilterOption _lipLinerOption() {
    final red = RecipePresets.all.firstWhere((p) => p.id == 'classic_red').recipe;
    final lips = red.lips;
    final recipe = MakeupRecipe(
      name: 'Rojo + delineado',
      lips: lips == null
          ? null
          : LipsSpec(
              color: lips.color,
              opacity: lips.opacity,
              finish: lips.finish,
              gloss: lips.gloss,
              lumaFollow: lips.lumaFollow,
              liner: const ColorLayer(color: RecipeColor(0x6E0A1A), opacity: 0.8),
            ),
      cheeks: red.cheeks,
      eyes: red.eyes,
      skin: red.skin,
    );
    return TestFilterOption(id: 'lip_liner_test', label: recipe.name, recipe: recipe);
  }

  static String _f(double? value, [int digits = 1]) => value == null ? '-' : value.toStringAsFixed(digits);

  @override
  Widget build(BuildContext context) {
    final granted = _granted;
    return Scaffold(
      backgroundColor: Colors.black,
      body: granted == true
          ? Stack(
              children: [
                Positioned.fill(child: _filterView()),
                SafeArea(
                  child: Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      // Debajo de la píldora "Mantené para comparar".
                      padding: const EdgeInsets.fromLTRB(8, 64, 8, 8),
                      child: Wrap(
                        spacing: 8,
                        children: [
                          FilledButton.tonal(
                            onPressed: _analyzing ? null : _analyzePhoto,
                            child: Text(_analyzing ? '…' : 'Foto'),
                          ),
                          FilledButton.tonal(onPressed: _analyzing ? null : _analyzePalette, child: const Text('Paleta')),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            )
          : Center(
              child: Text(
                granted == null ? 'Pidiendo permiso de cámara…' : 'Sin permiso de cámara',
                style: const TextStyle(color: Colors.white),
              ),
            ),
    );
  }

  Widget _filterView() => TestFilterView(
              extraOptions: _extraOptions,
              labels: const TestFilterLabels(
                noFilter: 'Sin filtro',
                intensity: 'Intensidad',
                note: 'Arnés P3-P5: tracker + maquillaje completo. Métricas en logcat (TRACK).',
                showPoints: 'Ver puntos',
                compare: 'Mantené para comparar',
                matte: 'Mate',
                satin: 'Satinado',
                gloss: 'Brillo',
                shimmer: 'Shimmer',
                zoneAll: 'Todo',
                zoneLips: 'Labios',
                zoneEyes: 'Ojos',
                zoneCheeks: 'Mejillas',
                zoneSkin: 'Piel',
                unavailable: 'Maquillaje en vivo no disponible (AR_RENDERER=painter o el motor no pudo iniciar).',
                lightAdaptation: 'Luz adaptada',
              ),
            );
}

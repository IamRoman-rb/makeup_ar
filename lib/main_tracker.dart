import 'dart:async';

import 'package:flutter/material.dart';
import 'package:makeup_engine/makeup_engine.dart';
import 'package:permission_handler/permission_handler.dart';

import 'features/ar/domain/makeup_recipe.dart';
import 'features/ar/domain/recipe_presets.dart';
import 'features/ar/presentation/test_filter_view.dart';

/// Arnés de medición de P3 (tracker + compositor), separado de la app (sin
/// Firebase ni RevenueCat): el filtro de prueba del Espejo a pantalla completa
/// y, cada 5 s, una línea `TRACK ...` con las métricas en logcat (etiqueta
/// flutter). Medir siempre en profile:
///   `flutter run --profile -t lib/main_tracker.dart -d <id>`
/// Pide el permiso de cámara antes de montar la vista.
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
          'presence=${_f(t.presence, 2)} yaw=${_f(t.yawDeg)} pitch=${_f(t.pitchDeg)} roll=${_f(t.rollDeg)} '
          'runs=${t.landmarkRuns}/${t.detectorRuns} losses=${t.losses} init=${_f(t.initMs, 0)} '
          'backend="${t.backend ?? '-'}" error="${s.error ?? t.error ?? '-'}"');
    } on Exception catch (e) {
      debugPrint('TRACK error $e');
    } finally {
      _inFlight = false;
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
          ? TestFilterView(
              extraOptions: [_lipLinerOption()],
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
              ),
            )
          : Center(
              child: Text(
                granted == null ? 'Pidiendo permiso de cámara…' : 'Sin permiso de cámara',
                style: const TextStyle(color: Colors.white),
              ),
            ),
    );
  }
}

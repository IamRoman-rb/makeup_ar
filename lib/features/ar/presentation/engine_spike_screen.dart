import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:makeup_engine/makeup_engine.dart';
import 'package:permission_handler/permission_handler.dart';

/// Pantalla del spike P1: cámara nativa en un `Texture`, tinte OKLab opcional y
/// overlay con las métricas que calcula el motor (p50/p95). Sirve para correr
/// el protocolo de docs/ar_engine/motor_ar_propio.md §11.5 en el Moto E20.
class EngineSpikeScreen extends StatefulWidget {
  const EngineSpikeScreen({super.key, this.engine});

  /// Inyectable para tests.
  final MakeupEngine? engine;

  @override
  State<EngineSpikeScreen> createState() => _EngineSpikeScreenState();
}

class _EngineSpikeScreenState extends State<EngineSpikeScreen> {
  static const Duration _statsPeriod = Duration(milliseconds: 500);
  static const List<Color> _tints = [Color(0xFFB3122D), Color(0xFFD9607E), Color(0xFF3B0A1E), Color(0xFFC9A15A)];

  late final MakeupEngine _engine = widget.engine ?? MakeupEngine();
  final ValueNotifier<EngineStats> _stats = ValueNotifier(EngineStats.empty);
  Timer? _statsTimer;
  bool _statsInFlight = false;
  bool _tintInFlight = false;
  bool _tintDirty = false;
  EngineStartInfo? _info;
  String? _error;
  int? _rotationOverride;
  Color _tint = _tints.first;
  double _amount = 0;

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
    final permission = await Permission.camera.request();
    if (!mounted) return;
    if (!permission.isGranted) {
      setState(() => _error = 'Sin permiso de cámara');
      return;
    }
    try {
      final info = await _engine.start(rotationDegrees: _rotationOverride);
      if (!mounted) {
        await _engine.stop();
        return;
      }
      setState(() {
        _info = info;
        _error = null;
      });
      await _applyTint();
      _statsTimer?.cancel();
      _statsTimer = Timer.periodic(_statsPeriod, (_) => _pollStats());
    } on MakeupEngineException catch (e) {
      if (mounted) setState(() => _error = '${e.code}: ${e.message}');
    }
  }

  Future<void> _restart() async {
    _statsTimer?.cancel();
    await _engine.stop();
    if (!mounted) return;
    setState(() => _info = null);
    await _start();
  }

  /// Los pedidos de métricas se descartan si el anterior no volvió: nunca se encolan.
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

  /// El slider genera ~60 eventos/s: se manda solo el último valor y nunca hay
  /// más de un setTint en vuelo.
  Future<void> _applyTint() async {
    _tintDirty = true;
    if (_tintInFlight) return;
    _tintInFlight = true;
    try {
      while (_tintDirty && mounted) {
        _tintDirty = false;
        await _engine.setTint(r: _tint.r, g: _tint.g, b: _tint.b, amount: _amount);
      }
    } finally {
      _tintInFlight = false;
    }
  }

  Future<void> _cycleRotation() async {
    final current = _rotationOverride ?? _info?.rotationDegrees ?? 0;
    _rotationOverride = (current + 90) % 360;
    await _restart();
  }

  @override
  Widget build(BuildContext context) {
    final info = _info;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: info == null
                  ? Text(_error ?? 'Iniciando motor…', style: const TextStyle(color: Colors.white))
                  : AspectRatio(aspectRatio: info.aspectRatio, child: Texture(textureId: info.textureId)),
            ),
            if (info != null) Positioned(left: 8, top: 8, right: 8, child: _StatsOverlay(info: info, stats: _stats)),
            Positioned(left: 8, right: 8, bottom: 8, child: _buildControls()),
          ],
        ),
      ),
    );
  }

  Widget _buildControls() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              for (final color in _tints)
                GestureDetector(
                  onTap: () {
                    setState(() => _tint = color);
                    unawaited(_applyTint());
                  },
                  child: Container(
                    width: 32,
                    height: 32,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(color: color == _tint ? Colors.white : Colors.transparent, width: 2),
                    ),
                  ),
                ),
              const Spacer(),
              TextButton(onPressed: _cycleRotation, child: const Text('Rotar 90°')),
              TextButton(onPressed: _engine.resetStats, child: const Text('Reset')),
            ],
          ),
          Row(
            children: [
              Text('Tinte OKLab ${(_amount * 100).round()}%', style: const TextStyle(color: Colors.white, fontSize: 12)),
              Expanded(
                child: Slider(
                  value: _amount,
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

class _StatsOverlay extends StatelessWidget {
  const _StatsOverlay({required this.info, required this.stats});

  final EngineStartInfo info;
  final ValueListenable<EngineStats> stats;

  static String _ms(double? value) => value == null ? '—' : value.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<EngineStats>(
      valueListenable: stats,
      builder: (context, s, _) {
        final lines = [
          'Render ${s.renderFps?.toStringAsFixed(1) ?? '—'} fps · cámara ${s.cameraFps?.toStringAsFixed(1) ?? '—'} fps · ${s.frames} frames',
          'Intervalo p50/p95: ${_ms(s.intervalP50Ms)} / ${_ms(s.intervalP95Ms)} ms',
          'CPU render p50/p95: ${_ms(s.cpuP50Ms)} / ${_ms(s.cpuP95Ms)} ms',
          'Cámara p50/p95: ${_ms(s.cameraIntervalP50Ms)} / ${_ms(s.cameraIntervalP95Ms)} ms',
          'Preview ${info.previewWidth}x${info.previewHeight} → ${info.width}x${info.height} · sensor ${info.sensorOrientation}° · rot ${info.rotationDegrees}° · AE ${info.fpsMin}-${info.fpsMax}',
          info.glInfo,
          if (s.error != null) 'ERROR: ${s.error}',
        ];
        return Container(
          padding: const EdgeInsets.all(6),
          color: Colors.black54,
          child: Text(
            lines.join('\n'),
            style: const TextStyle(color: Colors.greenAccent, fontSize: 11, fontFamily: 'monospace', height: 1.3),
          ),
        );
      },
    );
  }
}

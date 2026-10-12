import 'package:flutter/material.dart';
import 'package:makeup_engine/makeup_engine.dart';

/// Benchmark de los modelos del tracker (BlazeFace + FaceMesh-V2) con LiteRT,
/// GPU vs CPU. Imagen sintética: no usa la cámara. Corre solo al abrir y tarda
/// unos minutos. Medir siempre en profile:
///   `flutter run --profile -t lib/main_benchmark.dart -d <id>`
/// Los resultados también salen en logcat (etiquetas makeup_bench y flutter).
void main() {
  runApp(const MaterialApp(debugShowCheckedModeBanner: false, home: _BenchmarkScreen()));
}

class _BenchmarkScreen extends StatefulWidget {
  const _BenchmarkScreen();

  @override
  State<_BenchmarkScreen> createState() => _BenchmarkScreenState();
}

class _BenchmarkScreenState extends State<_BenchmarkScreen> {
  List<ModelBenchmarkResult>? _results;
  String? _error;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    try {
      final results = await MakeupEngine().runBenchmark();
      for (final r in results) {
        debugPrint('BENCH ${r.model} ${r.backend} run p50=${_ms(r.runP50Ms)} p95=${_ms(r.runP95Ms)} '
            'total p50=${_ms(r.totalP50Ms)} p95=${_ms(r.totalP95Ms)} init=${_ms(r.initMs)} error=${r.error ?? '-'}');
      }
      debugPrint('BENCH FIN');
      if (mounted) setState(() => _results = results);
    } on Exception catch (e) {
      debugPrint('BENCH ERROR $e');
      if (mounted) setState(() => _error = '$e');
    }
  }

  static String _ms(double? value) => value == null ? '—' : value.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final results = _results;
    return Scaffold(
      appBar: AppBar(title: const Text('Benchmark del tracker')),
      body: results == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _error ?? 'Midiendo… (unos minutos, no bloquees el teléfono)',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                for (final r in results)
                  ListTile(
                    dense: true,
                    title: Text('${r.model.replaceAll('.tflite', '')} · ${r.backend}'),
                    subtitle: Text(r.error ??
                        'inferencia p50/p95: ${_ms(r.runP50Ms)} / ${_ms(r.runP95Ms)} ms\n'
                            'con E/S p50/p95: ${_ms(r.totalP50Ms)} / ${_ms(r.totalP95Ms)} ms · init ${_ms(r.initMs)} ms'),
                  ),
              ],
            ),
    );
  }
}

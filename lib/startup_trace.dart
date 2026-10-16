import 'package:flutter/foundation.dart';

/// Marcas del arranque en logcat: `STARTUP <etapa> <ms>`, en ms desde el
/// comienzo de `main()`. Sirven para medir en el E20 antes de optimizar
/// (protocolo en docs/ar_engine/STARTUP.md). Cuestan un `debugPrint` por etapa.
final class StartupTrace {
  StartupTrace._();

  static final Stopwatch _clock = Stopwatch();

  /// Destino de las líneas; los tests lo reemplazan.
  @visibleForTesting
  static void Function(String line) sink = debugPrint;

  static void start() {
    _clock
      ..reset()
      ..start();
    sink(line('main', 0));
  }

  static void mark(String stage) => sink(line(stage, _clock.elapsedMilliseconds));

  @visibleForTesting
  static String line(String stage, int ms) => 'STARTUP $stage $ms';
}

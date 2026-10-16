import 'package:ar_makeup_app/startup_trace.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('las marcas salen en orden, con el formato STARTUP <etapa> <ms>', () {
    final lines = <String>[];
    final previous = StartupTrace.sink;
    StartupTrace.sink = lines.add;
    addTearDown(() => StartupTrace.sink = previous);

    StartupTrace.start();
    StartupTrace.mark('firebase');
    StartupTrace.mark('first_frame');

    expect(lines.first, 'STARTUP main 0');
    final pattern = RegExp(r'^STARTUP (\w+) (\d+)$');
    final ms = [for (final line in lines) int.parse(pattern.firstMatch(line)!.group(2)!)];
    expect([for (final line in lines) pattern.firstMatch(line)!.group(1)], ['main', 'firebase', 'first_frame']);
    expect(ms, orderedEquals([...ms]..sort()));
  });
}

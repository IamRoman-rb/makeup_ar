import 'dart:async';

import 'package:ar_makeup_app/features/auth/presentation/splash_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('servicios rápidos: espera el mínimo', (tester) async {
    var done = false;
    unawaited(splashGate(Future<void>.value()).then((_) => done = true));
    await tester.pump(kMinSplashDuration - const Duration(milliseconds: 50));
    expect(done, isFalse);
    await tester.pump(const Duration(milliseconds: 60));
    expect(done, isTrue);
  });

  testWidgets('servicios lentos: espera a que terminen, sin sumar el mínimo', (tester) async {
    final ready = Completer<void>();
    var done = false;
    unawaited(splashGate(ready.future).then((_) => done = true));
    await tester.pump(kMinSplashDuration * 2);
    expect(done, isFalse);
    ready.complete();
    await tester.pump();
    expect(done, isTrue);
  });

  testWidgets('si los servicios fallan, el error llega al splash', (tester) async {
    Object? error;
    unawaited(splashGate(Future<void>.error(StateError('sin red'))).catchError((Object e) => error = e));
    await tester.pump(kMinSplashDuration);
    expect(error, isA<StateError>());
  });

  test('el mínimo es corto: el splash ya no domina el arranque', () {
    expect(kMinSplashDuration, lessThanOrEqualTo(const Duration(seconds: 1)));
  });
}

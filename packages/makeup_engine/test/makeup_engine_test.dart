import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:makeup_engine/makeup_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('makeup_engine');
  final calls = <MethodCall>[];
  Object? Function(MethodCall call) handler = (_) => null;

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return handler(call);
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  test('start parsea la respuesta nativa', () async {
    handler = (_) => {
          'textureId': 7,
          'width': 720,
          'height': 1280,
          'previewWidth': 1280,
          'previewHeight': 720,
          'sensorOrientation': 270,
          'rotationDegrees': 270,
          'fpsMin': 30,
          'fpsMax': 30,
          'glInfo': 'ARM | Mali-G57 | OpenGL ES 3.2',
        };
    final info = await MakeupEngine().start();
    expect(info.textureId, 7);
    expect(info.aspectRatio, closeTo(720 / 1280, 1e-9));
    expect(info.fpsMax, 30);
    expect(info.glInfo, contains('Mali'));
    expect(calls.single.arguments, isEmpty);
  });

  test('start envía la rotación forzada', () async {
    handler = (_) => {'textureId': 1, 'width': 1, 'height': 1};
    await MakeupEngine().start(rotationDegrees: 90);
    expect(calls.single.arguments, {'rotationDegrees': 90});
  });

  test('start convierte PlatformException en MakeupEngineException', () async {
    handler = (_) => throw PlatformException(code: 'gl_init_failed', message: 'sin essl3');
    await expectLater(
      MakeupEngine().start(),
      throwsA(isA<MakeupEngineException>().having((e) => e.code, 'code', 'gl_init_failed')),
    );
  });

  test('getStats: NaN de ventana vacía se vuelve null y calcula fps', () async {
    handler = (_) => {
          'frames': 120.0,
          'intervalP50Ms': 33.3,
          'intervalP95Ms': double.nan,
          'cpuP50Ms': 4.0,
          'cpuP95Ms': 6.5,
          'cameraIntervalP50Ms': 33.3,
          'cameraIntervalP95Ms': 35.0,
          'error': null,
        };
    final stats = await MakeupEngine().getStats();
    expect(stats.frames, 120);
    expect(stats.intervalP95Ms, isNull);
    expect(stats.renderFps, closeTo(30.03, 0.01));
    expect(stats.cameraFps, closeTo(30.03, 0.01));
    expect(stats.error, isNull);
  });

  test('getStats sin sesión devuelve vacío', () async {
    handler = (_) => null;
    final stats = await MakeupEngine().getStats();
    expect(stats.frames, 0);
    expect(stats.renderFps, isNull);
  });

  test('setTint recorta a [0, 1]', () async {
    await MakeupEngine().setTint(r: 1.5, g: -1, b: 0.5, amount: 2);
    expect(calls.single.method, 'setTint');
    expect(calls.single.arguments, {'r': 1.0, 'g': 0.0, 'b': 0.5, 'amount': 1.0});
  });
}

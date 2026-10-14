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

  test('setRecipe manda la receta como mapa', () async {
    final recipe = <String, Object?>{
      'schema': 'makeup-recipe/2',
      'name': 'Rojo clásico',
      'lips': {'color': '#B3122D', 'opacity': 0.85, 'finish': 'gloss', 'gloss': 0.6, 'lumaFollow': 0.35},
    };
    await MakeupEngine().setRecipe(recipe);
    expect(calls.single.method, 'setRecipe');
    expect(calls.single.arguments, {'recipe': recipe});
  });

  test('setRenderOptions manda puntos y región', () async {
    await MakeupEngine().setRenderOptions(showLandmarks: true, region: TintRegion.makeup, lightAdaptation: false);
    expect(calls.single.method, 'setRenderOptions');
    expect(calls.single.arguments, {'showLandmarks': true, 'region': 1, 'lightAdaptation': false});
  });

  test('setRenderOptions por defecto: sin puntos y pantalla completa', () async {
    await MakeupEngine().setRenderOptions();
    expect(calls.single.arguments, {'showLandmarks': false, 'region': 0, 'lightAdaptation': true});
  });

  test('getStats parsea las métricas del tracker', () async {
    handler = (_) => {
          'frames': 10.0,
          'tracker': {
            'state': 2,
            'landmarkRuns': 40.0,
            'detectorRuns': 3.0,
            'losses': 1.0,
            'intervalP50Ms': 50.0,
            'intervalP95Ms': double.nan,
            'landmarkP50Ms': 17.0,
            'jitterP50Px': 0.4,
            'presence': 0.99,
            'yawDeg': -12.5,
            'initMs': 812.0,
            'backend': 'detector=gpu landmarks=gpu',
            'error': null,
          },
        };
    final stats = await MakeupEngine().getStats();
    final tracker = stats.tracker;
    expect(tracker.state, TrackerState.tracking);
    expect(tracker.landmarkRuns, 40);
    expect(tracker.losses, 1);
    expect(tracker.hz, closeTo(20, 1e-9));
    expect(tracker.intervalP95Ms, isNull);
    expect(tracker.jitterP50Px, 0.4);
    expect(tracker.yawDeg, -12.5);
    expect(tracker.backend, contains('gpu'));
  });

  test('getStats sin tracker devuelve tracker apagado', () async {
    handler = (_) => {'frames': 1.0, 'tracker': {'state': 99}};
    final stats = await MakeupEngine().getStats();
    expect(stats.tracker.state, TrackerState.tracking); // fuera de rango: se acota
    handler = (_) => {'frames': 1.0};
    expect((await MakeupEngine().getStats()).tracker.state, TrackerState.off);
  });

  test('runBenchmark parsea resultados y errores por backend', () async {
    handler = (_) => [
          {
            'model': 'face_landmarks_detector.tflite',
            'backend': 'gpu',
            'iterations': 300,
            'initMs': 812.5,
            'runP50Ms': 21.0,
            'runP95Ms': 25.5,
            'totalP50Ms': 23.0,
            'totalP95Ms': 28.0,
            'error': null,
          },
          {
            'model': 'face_landmarks_detector.tflite',
            'backend': 'gpu_opengl',
            'iterations': 0,
            'runP50Ms': double.nan,
            'error': 'LiteRtException: sin OpenGL ES 3.1',
          },
        ];
    final results = await MakeupEngine().runBenchmark();
    expect(results, hasLength(2));
    expect(results.first.runP50Ms, 21.0);
    expect(results.first.error, isNull);
    expect(results.last.runP50Ms, isNull);
    expect(results.last.error, contains('OpenGL'));
  });

  test('analyzeFaceImage manda los bytes y parsea las medidas', () async {
    // Medidas sintéticas: estado ok, labio válido y delineado con wing.
    final values = List<double>.filled(FaceImageAnalysis.valueCount, 0);
    values[1] = 180; // distancia entre ojos
    values[3] = 1; // piel válida
    values[4] = 0.8;
    values[10] = 1; // labios válidos
    values[11] = 0.5;
    values[12] = 0.16;
    values[14] = 0.7; // gloss_score
    values[15] = 900;
    values[16] = 0.95;
    values[38] = 2; // placement low
    values[FaceImageAnalysis.valueCount - 2] = 0.35;
    values[FaceImageAnalysis.valueCount - 1] = 0.6;
    handler = (_) => values;
    final analysis = await MakeupEngine().analyzeFaceImage(Uint8List.fromList([1, 2, 3]));
    expect(calls.single.method, 'analyzeFaceImage');
    expect((calls.single.arguments as Map)['bytes'], [1, 2, 3]);
    expect(analysis.status, FaceImageStatus.ok);
    expect(analysis.eyeDistancePx, 180);
    expect(analysis.skin.valid, isTrue);
    expect(analysis.lips.valid, isTrue);
    expect(analysis.lips.a, closeTo(0.16, 1e-9));
    expect(analysis.lips.gloss, closeTo(0.7, 1e-9));
    expect(analysis.lips.samples, 900);
    expect(analysis.cheekPlacement, 2);
    expect(analysis.eyeRegions, hasLength(5));
    expect(analysis.linerExtent, closeTo(0.35, 1e-9));
    expect(analysis.wingExtent, closeTo(0.6, 1e-9));
  });

  test('analyzeFaceImage: estado de rechazo, largo inválido y errores', () async {
    final values = List<double>.filled(FaceImageAnalysis.valueCount, 0)..[0] = 4;
    handler = (_) => values;
    expect((await MakeupEngine().analyzeFaceImage(Uint8List(1))).status, FaceImageStatus.profile);

    handler = (_) => [0.0, 1.0];
    await expectLater(
      MakeupEngine().analyzeFaceImage(Uint8List(1)),
      throwsA(isA<MakeupEngineException>().having((e) => e.code, 'code', 'bad_response')),
    );

    handler = (_) => throw PlatformException(code: 'bad_image', message: 'No se pudo leer la foto');
    await expectLater(
      MakeupEngine().analyzeFaceImage(Uint8List(1)),
      throwsA(isA<MakeupEngineException>().having((e) => e.code, 'code', 'bad_image')),
    );
  });

  test('extractPalette parsea swatches de a 4 valores', () async {
    handler = (_) => [0.7, 0.1, 0.2, 0.6, 0.4, 0.3, 0.2, 0.3, 0.9];
    final swatches = await MakeupEngine().extractPalette(Uint8List(1));
    expect(calls.single.method, 'extractPalette');
    expect(swatches, hasLength(2));
    expect(swatches.first.r, closeTo(0.7, 1e-9));
    expect(swatches.first.fraction, closeTo(0.6, 1e-9));
    expect(swatches.last.b, closeTo(0.2, 1e-9));
  });
}

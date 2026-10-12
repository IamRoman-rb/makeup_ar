import 'package:ar_makeup_app/features/ar/data/makeup_renderer_factory.dart';
import 'package:ar_makeup_app/features/ar/data/mirror_fallback_renderer.dart';
import 'package:ar_makeup_app/features/ar/data/native_gpu_makeup_renderer.dart';
import 'package:ar_makeup_app/features/ar/domain/i_makeup_renderer.dart';
import 'package:ar_makeup_app/features/ar/domain/recipe_presets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:makeup_engine/makeup_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('makeup_engine');
  final calls = <MethodCall>[];
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  void mockEngine({bool startFails = false, bool rejectRecipe = false}) {
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      switch (call.method) {
        case 'start':
          if (startFails) throw PlatformException(code: 'gl_init_failed', message: 'sin GLES 3');
          return {'textureId': 7, 'width': 720, 'height': 1280, 'glInfo': 'test'};
        case 'setRecipe':
          if (rejectRecipe) throw PlatformException(code: 'not_running');
          return null;
        case 'getStats':
          return {
            'frames': 30.0,
            'intervalP50Ms': 35.7,
            'tracker': {'state': 2, 'intervalP50Ms': 66.7, 'landmarkP50Ms': 21.0, 'backend': 'gpu'},
          };
        default:
          return null;
      }
    });
  }

  setUp(calls.clear);
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('nativo: inicia en modo maquillaje y manda la receta entera', () async {
    mockEngine();
    final renderer = NativeGpuMakeupRenderer();
    final surface = await renderer.start();
    expect(surface?.textureId, 7);
    expect(surface?.width, 720);
    final options = calls.firstWhere((c) => c.method == 'setRenderOptions').arguments as Map<Object?, Object?>;
    expect(options, {'showLandmarks': false, 'region': TintRegion.makeup.index});

    final glam = RecipePresets.all.firstWhere((p) => p.id == 'golden_glam').recipe;
    await renderer.applyRecipe(glam);
    final sent = (calls.last.arguments as Map<Object?, Object?>)['recipe'];
    expect(sent, glam.toJson());

    await renderer.applyRecipe(null);
    final none = (calls.last.arguments as Map<Object?, Object?>)['recipe'] as Map<Object?, Object?>;
    expect(none.containsKey('lips'), isFalse);
    expect(none.containsKey('eyes'), isFalse);

    await renderer.setShowLandmarks(true);
    expect(calls.last.arguments, {'showLandmarks': true, 'region': TintRegion.makeup.index});
  });

  test('nativo: si el motor no inicia, start devuelve null con el motivo', () async {
    mockEngine(startFails: true);
    final renderer = NativeGpuMakeupRenderer();
    expect(await renderer.start(), isNull);
    expect(renderer.unavailableReason, contains('gl_init_failed'));
  });

  test('nativo: un pedido rechazado se descarta', () async {
    mockEngine(rejectRecipe: true);
    final renderer = NativeGpuMakeupRenderer();
    await renderer.start();
    await expectLater(renderer.applyRecipe(RecipePresets.all.first.recipe), completes);
  });

  test('nativo: métricas del motor al dominio', () async {
    mockEngine();
    final stats = await NativeGpuMakeupRenderer().stats();
    expect(stats.renderFps, closeTo(28, 0.1));
    expect(stats.tracking, FaceTrackingState.tracking);
    expect(stats.trackerHz, closeTo(15, 0.1));
    expect(stats.landmarkMs, 21.0);
    expect(toRendererStats(EngineStats.empty).tracking, FaceTrackingState.loading);
  });

  test('respaldo: no dibuja nada', () async {
    const renderer = MirrorFallbackRenderer();
    expect(await renderer.start(), isNull);
    expect(renderer.unavailableReason, isNotNull);
    await renderer.applyRecipe(RecipePresets.all.first.recipe);
    await renderer.stop();
  });

  test('AR_RENDERER elige la implementación', () {
    expect(createMakeupRenderer(flag: 'painter'), isA<MirrorFallbackRenderer>());
    expect(createMakeupRenderer(flag: 'native'), isA<NativeGpuMakeupRenderer>());
    expect(createMakeupRenderer(flag: 'otro'), isA<NativeGpuMakeupRenderer>());
    expect(kArRendererFlag, 'native');
  });
}

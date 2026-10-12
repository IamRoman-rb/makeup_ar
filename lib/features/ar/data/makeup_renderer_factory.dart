import '../domain/i_makeup_renderer.dart';
import 'mirror_fallback_renderer.dart';
import 'native_gpu_makeup_renderer.dart';

/// Renderer elegido al compilar: `--dart-define=AR_RENDERER=native|painter`
/// (por defecto native). Cualquier otro valor usa el nativo.
const String kArRendererFlag = String.fromEnvironment('AR_RENDERER', defaultValue: 'native');

IMakeupRenderer createMakeupRenderer({String flag = kArRendererFlag}) =>
    flag == 'painter' ? const MirrorFallbackRenderer() : NativeGpuMakeupRenderer();

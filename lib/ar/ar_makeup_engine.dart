import 'package:flutter/widgets.dart';

/// Contrato común para cualquier motor de renderizado de maquillaje AR, para
/// que [CameraScreen] pueda alternar entre DeepAR y el motor legacy
/// (ML Kit + CustomPainter) sin cambiar su UI.
///
/// Notifica a sus listeners cada vez que hay un frame/estado nuevo que
/// justifique reconstruir el preview (por ejemplo, una malla facial nueva
/// en el motor legacy).
abstract class ArMakeupEngine extends ChangeNotifier {
  bool get isReady;

  Future<void> initialize();

  Widget buildPreview();

  Future<void> applyRecipe(Map<String, dynamic> recipe);

  Future<void> setEffectEnabled(bool enabled);
}

import 'package:makeup_engine/makeup_engine.dart';

import '../../studio/data/engine_image_analyzer.dart';
import '../../studio/domain/image_look.dart';
import '../domain/coach.dart';

/// [ICoachSampler] con el motor nativo: mide la cara de la sesión de cámara
/// en vivo (la que abrió la vista de la guía) con los landmarks del tracker.
/// El recorte se mide en el teléfono y se descarta: solo vuelven números.
final class EngineCoachSampler implements ICoachSampler {
  EngineCoachSampler({MakeupEngine? engine}) : _engine = engine ?? MakeupEngine();

  final MakeupEngine _engine;

  @override
  Future<LookMeasurements> sample() async {
    try {
      final analysis = await _engine.sampleLiveLook();
      return analysis == null
          ? const LookMeasurements(status: PhotoLookStatus.noFace)
          : EngineImageAnalyzer.toMeasurements(analysis);
    } on MakeupEngineException {
      return const LookMeasurements(status: PhotoLookStatus.badImage);
    }
  }
}

/// [ICoachVoice] con el TextToSpeech de Android (CoachVoice.kt del plugin).
final class EngineCoachVoice implements ICoachVoice {
  EngineCoachVoice({MakeupEngine? engine}) : _engine = engine ?? MakeupEngine();

  final MakeupEngine _engine;

  @override
  Future<bool> speak(String text, {required String locale}) => _engine.coachSpeak(text, locale: locale);

  @override
  Future<void> stop() => _engine.coachStop();

  @override
  Future<void> release() => _engine.coachRelease();
}

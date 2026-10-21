import AVFoundation
import Foundation

/// Voz de la guía de maquillaje (docs/ar_engine/COACH.md) con el sintetizador
/// del sistema: port de CoachVoice.kt, sin dependencias. Main. Cada speak corta
/// lo anterior: la guía siempre dice lo más reciente.
final class CoachVoice {
  private let synthesizer = AVSpeechSynthesizer()

  /// false si el sistema no tiene voz para [locale] (es, en, pt, fr): queda
  /// solo el texto.
  func speak(_ text: String, locale: String) -> Bool {
    guard let voice = AVSpeechSynthesisVoice(language: locale) else { return false }
    if synthesizer.isSpeaking { synthesizer.stopSpeaking(at: .immediate) }
    let utterance = AVSpeechUtterance(string: text)
    utterance.voice = voice
    synthesizer.speak(utterance)
    return true
  }

  func stop() {
    if synthesizer.isSpeaking { synthesizer.stopSpeaking(at: .immediate) }
  }
}

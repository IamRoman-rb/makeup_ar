/// Umbrales de la guía de maquillaje (docs/ar_engine/COACH.md). Valores
/// iniciales a calibrar en el E20 con maquillaje real: cada uno dice qué
/// diferencia con el look cuenta como "falta", "sobra" u "otro tono".
abstract final class CoachPolicy {
  /// Fracción de la máscara de la región que se tiene que ver para opinar.
  static const double minCoverage = 0.4;

  /// ΔE OK entre lo observado y lo que el motor pintaría con la receta a
  /// partir del cual el color no es el del look (otro tono, más oscuro o más
  /// claro). La cámara en vivo tiene ruido de ~0,02.
  static const double toneTolerance = 0.05;

  /// Cantidad aplicada / la de la receta: debajo de 1 − esto falta, arriba de
  /// 1 + [amountHigh] sobra.
  static const double amountLow = 0.3;
  static const double amountHigh = 0.35;

  /// Ruido de una región medida en vivo (ΔE OK): la cámara del E20, la
  /// mediana robusta de cada región y el movimiento entre muestras. A
  /// calibrar en el E20 (línea COACH).
  static const double measurementNoise = 0.015;

  /// Hasta dónde se busca la cantidad (× la del color de la receta).
  static const double maxAmount = 1.5;

  /// Debajo de este ΔE entre el color del look y el natural no se puede decir
  /// cuánto hay: solo si el color coincide.
  static const double minContrast = 0.03;

  /// Labio natural estimado desde la piel cuando no hay referencia: más
  /// oscuro y más rojo (aproximado; con la referencia es exacto).
  static const double naturalLipDeltaL = -0.06;
  static const double naturalLipDeltaA = 0.04;

  /// Delineado (unidades de la receta, 0..1): tolerancia de grosor y de wing.
  static const double linerThicknessTolerance = 0.2;
  static const double wingTolerance = 0.2;

  /// El delineado mide ~1 mm: con la cara lejos no se distingue (en la cámara
  /// frontal a 720p, con los ojos a menos de esto en px no se juzga).
  static const double minEyeDistanceForLinerPx = 170;

  /// Una opacidad de receta menor que esto no se revisa (casi no se ve).
  static const double minTargetOpacity = 0.05;

  /// Lecturas iguales seguidas para cambiar el veredicto de una zona.
  static const int confirmations = 2;

  /// La misma indicación no se repite antes de esto.
  static const Duration repeatAfter = Duration(seconds: 6);

  /// Cada cuánto se toma una muestra.
  static const Duration samplePeriod = Duration(milliseconds: 1500);

  /// Muestras de la referencia con la cara lavada.
  static const int referenceSamples = 2;
}

/// Resultados del análisis de fotos del Studio (F4; docs/ar_engine/F4_PLAN.md):
/// medidas de un look sobre una foto de referencia y paleta de una foto de
/// producto. Solo números: la foto se procesa en el teléfono y no se guarda.
library;

/// Motivo del resultado ([StillFaceStatus] en studio/still_face_locator.h).
enum FaceImageStatus {
  ok,

  /// El detector no encontró una cara.
  noFace,

  /// La cara es muy chica en la foto.
  faceTooSmall,

  /// El modelo de landmarks no confirmó la cara.
  lowPresence,

  /// La cara está muy girada: hace falta una foto de frente.
  profile,

  /// La foto está vacía o no se pudo medir la piel.
  badImage,
}

/// Una región medida: color robusto OKLab, `gloss_score` [0, 1], cantidad de
/// muestras y cobertura (fracción de la máscara que se vio en la foto).
final class FaceImageRegion {
  const FaceImageRegion({
    required this.valid,
    required this.l,
    required this.a,
    required this.b,
    this.gloss = 0,
    this.samples = 0,
    this.coverage = 0,
  });

  static const FaceImageRegion missing = FaceImageRegion(valid: false, l: 0, a: 0, b: 0);

  final bool valid;
  final double l;
  final double a;
  final double b;
  final double gloss;
  final int samples;
  final double coverage;

  /// Bloque de [FaceImageAnalysis.regionFloats] valores desde [offset].
  static FaceImageRegion _at(List<double> values, int offset) => FaceImageRegion(
    valid: values[offset] >= 0.5,
    l: values[offset + 1],
    a: values[offset + 2],
    b: values[offset + 3],
    gloss: values[offset + 4],
    samples: values[offset + 5].round(),
    coverage: values[offset + 6],
  );
}

/// Medidas de un look sobre una foto (studio/look_analysis.h, mismo orden).
final class FaceImageAnalysis {
  const FaceImageAnalysis({
    required this.status,
    this.eyeDistancePx = 0,
    this.yawRatio = 0,
    this.skin = FaceImageRegion.missing,
    this.lips = FaceImageRegion.missing,
    this.lipLiner = FaceImageRegion.missing,
    this.lipInterior = FaceImageRegion.missing,
    this.cheeks = FaceImageRegion.missing,
    this.cheekPlacement = 0,
    this.eyeRegions = const [],
    this.liner = FaceImageRegion.missing,
    this.linerExtent = 0,
    this.wingExtent = 0,
  });

  // Índices de kLook* (look_analysis.h).
  static const int regionFloats = 7;
  static const int eyeRegionCount = 5;
  static const int _skin = 3;
  static const int _lips = _skin + regionFloats;
  static const int _lipLiner = _lips + regionFloats;
  static const int _lipInterior = _lipLiner + regionFloats;
  static const int _cheeks = _lipInterior + regionFloats;
  static const int _cheekPlacement = _cheeks + regionFloats;
  static const int _eyeRegions = _cheekPlacement + 1;
  static const int _liner = _eyeRegions + eyeRegionCount * regionFloats;
  static const int _linerExtent = _liner + regionFloats;
  static const int _wingExtent = _linerExtent + 1;

  /// Cantidad de valores que manda el nativo (kLookValueCount).
  static const int valueCount = _wingExtent + 1;

  /// null si la lista no tiene el largo esperado o trae valores no finitos.
  static FaceImageAnalysis? fromValues(List<double> values) {
    if (values.length != valueCount || values.any((v) => !v.isFinite)) return null;
    final statusIndex = values[0].round();
    final status = statusIndex >= 0 && statusIndex < FaceImageStatus.values.length
        ? FaceImageStatus.values[statusIndex]
        : FaceImageStatus.badImage;
    return FaceImageAnalysis(
      status: status,
      eyeDistancePx: values[1],
      yawRatio: values[2],
      skin: FaceImageRegion._at(values, _skin),
      lips: FaceImageRegion._at(values, _lips),
      lipLiner: FaceImageRegion._at(values, _lipLiner),
      lipInterior: FaceImageRegion._at(values, _lipInterior),
      cheeks: FaceImageRegion._at(values, _cheeks),
      cheekPlacement: values[_cheekPlacement].round().clamp(0, 2),
      eyeRegions: [
        for (var i = 0; i < eyeRegionCount; i++) FaceImageRegion._at(values, _eyeRegions + i * regionFloats),
      ],
      liner: FaceImageRegion._at(values, _liner),
      linerExtent: values[_linerExtent],
      wingExtent: values[_wingExtent],
    );
  }

  final FaceImageStatus status;
  final double eyeDistancePx;
  final double yawRatio;

  /// Piel base (frente, puente de la nariz, mentón): la referencia sin maquillaje.
  final FaceImageRegion skin;
  final FaceImageRegion lips;

  /// Mitad interna del anillo del delineado de labios.
  final FaceImageRegion lipLiner;

  /// Centro del labio (para comparar con el anillo).
  final FaceImageRegion lipInterior;

  /// Rubor en el placement que más se aparta de la piel.
  final FaceImageRegion cheeks;

  /// 0 apple, 1 high, 2 low (orden de `placement` del esquema).
  final int cheekPlacement;

  /// Párpado, pliegue, V externa, lagrimal y hueso de la ceja (orden de `region`).
  final List<FaceImageRegion> eyeRegions;

  /// Color de los texels oscuros del delineado y del wing.
  final FaceImageRegion liner;

  /// Grosor medido del delineado: distancia normalizada a la línea de pestañas [0, 1].
  final double linerExtent;

  /// Largo medido del wing [0, 1] (avance a lo largo de su eje).
  final double wingExtent;
}

/// Un color de la paleta de un producto: sRGB [0, 1] y fracción del área.
final class PaletteSwatch {
  const PaletteSwatch({required this.r, required this.g, required this.b, required this.fraction});

  final double r;
  final double g;
  final double b;
  final double fraction;

  /// Grupos de 4 valores (r, g, b, fracción); ignora un resto incompleto.
  static List<PaletteSwatch> fromValues(List<double> values) => [
    for (var i = 0; i + 3 < values.length; i += 4)
      if (values.sublist(i, i + 4).every((v) => v.isFinite))
        PaletteSwatch(
          r: values[i].clamp(0.0, 1.0),
          g: values[i + 1].clamp(0.0, 1.0),
          b: values[i + 2].clamp(0.0, 1.0),
          fraction: values[i + 3].clamp(0.0, 1.0),
        ),
  ];
}

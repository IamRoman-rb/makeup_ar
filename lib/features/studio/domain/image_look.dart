/// Medidas de un look sobre una foto y paleta de un producto (F4): lo que
/// devuelve el analizador del motor, en tipos del dominio (sin Flutter ni el
/// plugin). La foto se procesa en el teléfono y no se guarda: acá solo hay
/// números (docs/ar_engine/F4_PLAN.md).
library;

import 'dart:typed_data';

import '../../ar/domain/makeup_recipe.dart';
import 'oklab.dart';

/// Resultado del análisis de la foto.
enum PhotoLookStatus { ok, noFace, faceTooSmall, lowPresence, profile, badImage }

/// Una región medida: color robusto, `gloss_score` [0, 1] y cobertura
/// (fracción de la máscara que se vio en la foto).
final class LookRegion {
  const LookRegion({required this.valid, required this.color, this.gloss = 0, this.coverage = 0});

  static const LookRegion missing = LookRegion(valid: false, color: Oklab(0, 0, 0));

  final bool valid;
  final Oklab color;
  final double gloss;
  final double coverage;
}

final class LookMeasurements {
  const LookMeasurements({
    required this.status,
    this.yawRatio = 0,
    this.skin = LookRegion.missing,
    this.lips = LookRegion.missing,
    this.lipLiner = LookRegion.missing,
    this.lipInterior = LookRegion.missing,
    this.cheeks = LookRegion.missing,
    this.cheekPlacement = CheekPlacement.apple,
    this.eyeRegions = const [],
    this.liner = LookRegion.missing,
    this.linerExtent = 0,
    this.wingExtent = 0,
    this.lipsSplit = false,
    this.sideMask = 0,
  });

  final PhotoLookStatus status;

  /// Giro de la cara: nariz respecto del medio de los ojos (0 de frente).
  final double yawRatio;
  final LookRegion skin;
  final LookRegion lips;
  final LookRegion lipLiner;
  final LookRegion lipInterior;
  final LookRegion cheeks;
  final CheekPlacement cheekPlacement;

  /// Por [ShadowRegion], en su orden (puede venir vacía).
  final List<LookRegion> eyeRegions;
  final LookRegion liner;

  /// Grosor medido del delineado (distancia normalizada a la línea de pestañas).
  final double linerExtent;

  /// Largo medido del wing [0, 1].
  final double wingExtent;

  /// Diagnóstico: labio de dos colores (se usó uno) y lados usados (bit 0
  /// rubor, bit 1 párpado, bit 2 delineado).
  final bool lipsSplit;
  final int sideMask;

  LookRegion eye(ShadowRegion region) =>
      region.index < eyeRegions.length ? eyeRegions[region.index] : LookRegion.missing;
}

/// Color de una foto de producto con su fracción del área.
final class ProductSwatch {
  const ProductSwatch({required this.color, required this.fraction});

  final RecipeColor color;
  final double fraction;
}

/// Analizador de fotos del Studio (implementación: el motor nativo).
abstract interface class IImageLookAnalyzer {
  /// Mide el maquillaje de una foto de referencia (JPEG/PNG). Tira
  /// [ImageAnalysisException] si la foto no se pudo leer.
  Future<LookMeasurements> analyzeFace(Uint8List bytes);

  /// Colores de una foto de producto, de mayor a menor área.
  Future<List<ProductSwatch>> palette(Uint8List bytes);
}

final class ImageAnalysisException implements Exception {
  const ImageAnalysisException(this.code, [this.message]);

  final String code;
  final String? message;

  @override
  String toString() => 'ImageAnalysisException($code): $message';
}

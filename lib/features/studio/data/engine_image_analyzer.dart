import 'dart:typed_data';

import 'package:makeup_engine/makeup_engine.dart';

import '../../ar/domain/makeup_recipe.dart';
import '../domain/image_look.dart';
import '../domain/oklab.dart';

/// [IImageLookAnalyzer] con el motor nativo (F4): la foto se analiza en el
/// teléfono (StillImageAnalyzer.kt + cpp/studio/) y solo vuelven números.
final class EngineImageAnalyzer implements IImageLookAnalyzer {
  EngineImageAnalyzer({MakeupEngine? engine}) : _engine = engine ?? MakeupEngine();

  final MakeupEngine _engine;

  @override
  Future<LookMeasurements> analyzeFace(Uint8List bytes) async {
    try {
      return toMeasurements(await _engine.analyzeFaceImage(bytes));
    } on MakeupEngineException catch (e) {
      throw ImageAnalysisException(e.code, e.message);
    }
  }

  @override
  Future<List<ProductSwatch>> palette(Uint8List bytes) async {
    try {
      return [
        for (final swatch in await _engine.extractPalette(bytes))
          ProductSwatch(color: _color(swatch.r, swatch.g, swatch.b), fraction: swatch.fraction),
      ];
    } on MakeupEngineException catch (e) {
      throw ImageAnalysisException(e.code, e.message);
    }
  }

  /// Tipos del plugin -> dominio.
  static LookMeasurements toMeasurements(FaceImageAnalysis analysis) => LookMeasurements(
    status: switch (analysis.status) {
      FaceImageStatus.ok => PhotoLookStatus.ok,
      FaceImageStatus.noFace => PhotoLookStatus.noFace,
      FaceImageStatus.faceTooSmall => PhotoLookStatus.faceTooSmall,
      FaceImageStatus.lowPresence => PhotoLookStatus.lowPresence,
      FaceImageStatus.profile => PhotoLookStatus.profile,
      FaceImageStatus.badImage => PhotoLookStatus.badImage,
    },
    yawRatio: analysis.yawRatio,
    eyeDistancePx: analysis.eyeDistancePx,
    skin: _region(analysis.skin),
    lips: _region(analysis.lips),
    lipLiner: _region(analysis.lipLiner),
    lipInterior: _region(analysis.lipInterior),
    cheeks: _region(analysis.cheeks),
    cheekPlacement: CheekPlacement.values[analysis.cheekPlacement.clamp(0, CheekPlacement.values.length - 1)],
    eyeRegions: [for (final region in analysis.eyeRegions) _region(region)],
    liner: _region(analysis.liner),
    linerExtent: analysis.linerExtent,
    wingExtent: analysis.wingExtent,
    lipsSplit: analysis.lipsSplit,
    sideMask: analysis.sideMask,
    cheekSkin: _region(analysis.cheekSkin),
    eyeSkin: _region(analysis.eyeSkin),
  );

  static LookRegion _region(FaceImageRegion region) => LookRegion(
    valid: region.valid,
    color: Oklab(region.l, region.a, region.b),
    gloss: region.gloss,
    coverage: region.coverage,
  );

  static RecipeColor _color(double r, double g, double b) {
    int channel(double c) => (c.clamp(0.0, 1.0) * 255).round();
    return RecipeColor((channel(r) << 16) | (channel(g) << 8) | channel(b));
  }
}

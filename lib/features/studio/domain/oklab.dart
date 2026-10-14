/// OKLab en Dart para armar recetas desde medidas (F4). Mismas fórmulas y
/// misma gamma 2.2 que el motor (cpp/color_math.h, shaders/color.glsl) y que
/// tools/studio/sample_region_reference.py. Dominio puro.
library;

import 'dart:math' as math;

import '../../ar/domain/makeup_recipe.dart';

final class Oklab {
  const Oklab(this.l, this.a, this.b);

  final double l;
  final double a;
  final double b;

  /// sRGB [0, 1] -> OKLab.
  factory Oklab.fromSrgb(double r, double g, double b) {
    double lin(double c) => math.pow(c.clamp(0.0, 1.0), 2.2).toDouble();
    return Oklab.fromLinear(lin(r), lin(g), lin(b));
  }

  factory Oklab.fromColor(RecipeColor color) => Oklab.fromSrgb(color.red / 255, color.green / 255, color.blue / 255);

  factory Oklab.fromLinear(double r, double g, double b) {
    double cbrt(double x) => x < 0 ? -math.pow(-x, 1 / 3).toDouble() : math.pow(x, 1 / 3).toDouble();
    final l = cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b);
    final m = cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b);
    final s = cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b);
    return Oklab(
      0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
      1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
      0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s,
    );
  }

  /// RGB lineal sin recortar (puede salir de [0, 1]).
  List<double> toLinear() {
    final l1 = l + 0.3963377774 * a + 0.2158037573 * b;
    final m1 = l - 0.1055613458 * a - 0.0638541728 * b;
    final s1 = l - 0.0894841775 * a - 1.2914855480 * b;
    final l3 = l1 * l1 * l1;
    final m3 = m1 * m1 * m1;
    final s3 = s1 * s1 * s1;
    return [
      4.0767416621 * l3 - 3.3077115913 * m3 + 0.2309699292 * s3,
      -1.2684380046 * l3 + 2.6097574011 * m3 - 0.3413193965 * s3,
      -0.0041960863 * l3 - 0.7034186147 * m3 + 1.7076147010 * s3,
    ];
  }

  /// Dentro del gamut sRGB (con la tolerancia del script de referencia).
  bool get inGamut => toLinear().every((c) => c >= -1e-4 && c <= 1 + 1e-4);

  /// Color HEX de la receta (recortado al gamut).
  RecipeColor toRecipeColor() {
    final linear = toLinear();
    int channel(double c) => (math.pow(c.clamp(0.0, 1.0), 1 / 2.2) * 255).round().clamp(0, 255);
    return RecipeColor((channel(linear[0]) << 16) | (channel(linear[1]) << 8) | channel(linear[2]));
  }

  /// ΔE OK (distancia euclídea).
  double distanceTo(Oklab other) {
    final dl = l - other.l;
    final da = a - other.a;
    final db = b - other.b;
    return math.sqrt(dl * dl + da * da + db * db);
  }

  /// Distancia solo en croma (a, b).
  double chromaDistanceTo(Oklab other) {
    final da = a - other.a;
    final db = b - other.b;
    return math.sqrt(da * da + db * db);
  }

  @override
  String toString() => 'Oklab(${l.toStringAsFixed(3)}, ${a.toStringAsFixed(3)}, ${b.toStringAsFixed(3)})';
}

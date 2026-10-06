/// Modelo inmutable de una receta de maquillaje `makeup-recipe/2`.
///
/// Espeja 1:1 `docs/ar_engine/recipe_v2.schema.json`. Una receta solo
/// describe parámetros (colores, opacidades, enums cerrados): nunca código.
/// Para construirla desde JSON no confiable usá `RecipeValidator`.
///
/// Dominio puro: sin dependencias de Flutter ni de Firebase.
library;

/// Identificador de esquema que debe traer toda receta v2.
const String kMakeupRecipeSchemaV2 = 'makeup-recipe/2';

/// Límites del esquema, compartidos con el validador.
abstract final class RecipeLimits {
  static const int nameMaxLength = 60;
  static const int maxShadowLayers = 4;
  static const int maxEffects = 3;
}

/// Color sRGB opaco de 24 bits, serializado como `#RRGGBB`.
final class RecipeColor {
  const RecipeColor(this.rgb) : assert(rgb >= 0 && rgb <= 0xFFFFFF);

  static final RegExp _hexPattern = RegExp(r'^#[0-9A-Fa-f]{6}$');

  /// Devuelve null si [hex] no respeta `^#[0-9A-Fa-f]{6}$`.
  static RecipeColor? tryParse(String hex) {
    if (!_hexPattern.hasMatch(hex)) return null;
    return RecipeColor(int.parse(hex.substring(1), radix: 16));
  }

  static bool isValidHex(String hex) => _hexPattern.hasMatch(hex);

  /// Valor 0xRRGGBB.
  final int rgb;

  int get red => (rgb >> 16) & 0xFF;
  int get green => (rgb >> 8) & 0xFF;
  int get blue => rgb & 0xFF;

  /// `#RRGGBB` en mayúsculas.
  String toHex() => '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';

  @override
  bool operator ==(Object other) => other is RecipeColor && other.rgb == rgb;

  @override
  int get hashCode => rgb.hashCode;

  @override
  String toString() => toHex();
}

/// Enum cerrado con su nombre en el JSON.
abstract interface class WireEnum {
  String get wireName;
}

T? _byWireName<T extends WireEnum>(List<T> values, Object? raw) {
  if (raw is! String) return null;
  for (final value in values) {
    if (value.wireName == raw) return value;
  }
  return null;
}

enum LipFinish implements WireEnum {
  matte('matte'),
  satin('satin'),
  gloss('gloss'),
  shimmer('shimmer');

  const LipFinish(this.wireName);

  @override
  final String wireName;

  static LipFinish? fromWire(Object? raw) => _byWireName(values, raw);
}

enum ShadowFinish implements WireEnum {
  matte('matte'),
  satin('satin'),
  shimmer('shimmer');

  const ShadowFinish(this.wireName);

  @override
  final String wireName;

  static ShadowFinish? fromWire(Object? raw) => _byWireName(values, raw);
}

enum ShadowRegion implements WireEnum {
  lid('lid'),
  crease('crease'),
  outerV('outer_v'),
  innerCorner('inner_corner'),
  browBone('brow_bone');

  const ShadowRegion(this.wireName);

  @override
  final String wireName;

  static ShadowRegion? fromWire(Object? raw) => _byWireName(values, raw);
}

enum CheekPlacement implements WireEnum {
  apple('apple'),
  high('high'),
  low('low');

  const CheekPlacement(this.wireName);

  @override
  final String wireName;

  static CheekPlacement? fromWire(Object? raw) => _byWireName(values, raw);
}

enum EffectType implements WireEnum {
  freckles('freckles'),
  glitter('glitter'),
  sheen('sheen');

  const EffectType(this.wireName);

  @override
  final String wireName;

  static EffectType? fromWire(Object? raw) => _byWireName(values, raw);
}

enum EffectRegion implements WireEnum {
  cheeksNose('cheeks_nose'),
  eyes('eyes'),
  lips('lips'),
  fullFace('full_face');

  const EffectRegion(this.wireName);

  @override
  final String wireName;

  static EffectRegion? fromWire(Object? raw) => _byWireName(values, raw);
}

/// Par color + opacidad (delineador de labios, contorno, iluminador).
final class ColorLayer {
  const ColorLayer({required this.color, required this.opacity});

  final RecipeColor color;

  /// 0..1.
  final double opacity;

  Map<String, Object?> toJson() => {'color': color.toHex(), 'opacity': opacity};
}

final class LipsSpec {
  const LipsSpec({
    required this.color,
    required this.opacity,
    this.finish,
    this.gloss,
    this.lumaFollow,
    this.liner,
  });

  final RecipeColor color;
  final double opacity;
  final LipFinish? finish;

  /// 0..1, intensidad del especular.
  final double? gloss;

  /// 0..1, cuánto sigue la luminosidad del color objetivo.
  final double? lumaFollow;
  final ColorLayer? liner;

  Map<String, Object?> toJson() => {
        'color': color.toHex(),
        'opacity': opacity,
        if (finish != null) 'finish': finish?.wireName,
        if (gloss != null) 'gloss': gloss,
        if (lumaFollow != null) 'lumaFollow': lumaFollow,
        if (liner != null) 'liner': liner?.toJson(),
      };
}

final class CheeksSpec {
  const CheeksSpec({required this.color, required this.opacity, this.spread, this.placement});

  final RecipeColor color;
  final double opacity;
  final double? spread;
  final CheekPlacement? placement;

  Map<String, Object?> toJson() => {
        'color': color.toHex(),
        'opacity': opacity,
        if (spread != null) 'spread': spread,
        if (placement != null) 'placement': placement?.wireName,
      };
}

final class EyeShadowLayer {
  const EyeShadowLayer({required this.color, required this.opacity, required this.region, this.finish});

  final RecipeColor color;
  final double opacity;
  final ShadowRegion region;
  final ShadowFinish? finish;

  Map<String, Object?> toJson() => {
        'color': color.toHex(),
        'opacity': opacity,
        'region': region.wireName,
        if (finish != null) 'finish': finish?.wireName,
      };
}

final class EyeLinerSpec {
  const EyeLinerSpec({required this.color, required this.opacity, this.thickness, this.wing});

  final RecipeColor color;
  final double opacity;
  final double? thickness;
  final double? wing;

  Map<String, Object?> toJson() => {
        'color': color.toHex(),
        'opacity': opacity,
        if (thickness != null) 'thickness': thickness,
        if (wing != null) 'wing': wing,
      };
}

final class LashesSpec {
  const LashesSpec({required this.opacity, this.length, this.volume});

  final double opacity;
  final double? length;
  final double? volume;

  Map<String, Object?> toJson() => {
        'opacity': opacity,
        if (length != null) 'length': length,
        if (volume != null) 'volume': volume,
      };
}

final class EyesSpec {
  /// [shadow] se copia a una lista inmodificable.
  EyesSpec({List<EyeShadowLayer>? shadow, this.liner, this.lashes})
      : shadow = shadow == null ? null : List.unmodifiable(shadow);

  /// Máximo [RecipeLimits.maxShadowLayers] capas; null si no vino en el JSON.
  final List<EyeShadowLayer>? shadow;
  final EyeLinerSpec? liner;
  final LashesSpec? lashes;

  Map<String, Object?> toJson() => {
        if (shadow != null) 'shadow': [for (final layer in shadow ?? const <EyeShadowLayer>[]) layer.toJson()],
        if (liner != null) 'liner': liner?.toJson(),
        if (lashes != null) 'lashes': lashes?.toJson(),
      };
}

final class FoundationSpec {
  const FoundationSpec({required this.color, required this.coverage});

  final RecipeColor color;

  /// 0..1.
  final double coverage;

  Map<String, Object?> toJson() => {'color': color.toHex(), 'coverage': coverage};
}

final class SkinSpec {
  const SkinSpec({this.foundation, this.contour, this.highlight});

  final FoundationSpec? foundation;
  final ColorLayer? contour;
  final ColorLayer? highlight;

  Map<String, Object?> toJson() => {
        if (foundation != null) 'foundation': foundation?.toJson(),
        if (contour != null) 'contour': contour?.toJson(),
        if (highlight != null) 'highlight': highlight?.toJson(),
      };
}

final class MakeupEffect {
  const MakeupEffect({required this.type, required this.intensity, this.region});

  final EffectType type;
  final double intensity;
  final EffectRegion? region;

  Map<String, Object?> toJson() => {
        'type': type.wireName,
        'intensity': intensity,
        if (region != null) 'region': region?.wireName,
      };
}

final class MakeupRecipe {
  /// [effects] se copia a una lista inmodificable.
  MakeupRecipe({
    required this.name,
    this.lips,
    this.cheeks,
    this.eyes,
    this.skin,
    List<MakeupEffect>? effects,
  }) : effects = effects == null ? null : List.unmodifiable(effects);

  /// Siempre [kMakeupRecipeSchemaV2].
  String get schema => kMakeupRecipeSchemaV2;

  /// 1..60 caracteres (code points).
  final String name;
  final LipsSpec? lips;
  final CheeksSpec? cheeks;
  final EyesSpec? eyes;
  final SkinSpec? skin;

  /// Máximo [RecipeLimits.maxEffects]; null si no vino en el JSON.
  final List<MakeupEffect>? effects;

  /// JSON canónico: colores en mayúsculas y solo las claves presentes.
  Map<String, Object?> toJson() => {
        'schema': schema,
        'name': name,
        if (lips != null) 'lips': lips?.toJson(),
        if (cheeks != null) 'cheeks': cheeks?.toJson(),
        if (eyes != null) 'eyes': eyes?.toJson(),
        if (skin != null) 'skin': skin?.toJson(),
        if (effects != null) 'effects': [for (final effect in effects ?? const <MakeupEffect>[]) effect.toJson()],
      };
}

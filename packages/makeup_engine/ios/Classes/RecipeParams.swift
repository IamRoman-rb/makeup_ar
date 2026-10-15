import Foundation

// Port de android/.../RecipeParams.kt: receta `makeup-recipe/2` (ya validada en
// Dart) llegada por el canal como diccionario, reducida a lo que dibuja el
// motor. Segunda línea de defensa: lo ausente, mal tipado o fuera de rango se
// recorta o apaga la región; nunca rompe el render. Mismas constantes que
// NativeBridge.kt (los enums de face_style.h / renderer.h).
enum EngineConst {
  static let regionFull: Int32 = 0
  static let regionMakeup: Int32 = 1
  static let lipMatte: Int32 = 0, lipSatin: Int32 = 1, lipGloss: Int32 = 2, lipShimmer: Int32 = 3
  static let cheekApple: Int32 = 0, cheekHigh: Int32 = 1, cheekLow: Int32 = 2
  static let eyeLid: Int32 = 0, eyeCrease: Int32 = 1, eyeOuterV: Int32 = 2, eyeInnerCorner: Int32 = 3
  static let eyeBrowBone: Int32 = 4
  static let shadowMatte: Int32 = 0, shadowSatin: Int32 = 1, shadowShimmer: Int32 = 2
  static let maxEyeShadows = 4
  static let effectFreckles: Int32 = 0, effectGlitter: Int32 = 1, effectSheen: Int32 = 2
  static let effectCheeksNose: Int32 = 0, effectEyes: Int32 = 1, effectLips: Int32 = 2, effectFullFace: Int32 = 3
  static let maxEffects = 3
  static let cropNone: Int32 = 0, cropDetector: Int32 = 1, cropLandmarks: Int32 = 2
  static let stillDetector: Int32 = 0, stillLandmarks: Int32 = 1
  static let stillStatusBadImage: Int32 = 5
  static let frameFlagCropReady: Int32 = 1
}

/// Número en [0, 1] (recortado); nil si falta, no es número o es NaN.
private func unit(_ value: Any?) -> Float? {
  guard let number = value as? NSNumber, !(value is Bool) else { return nil }
  let f = number.floatValue
  if f.isNaN { return nil }
  return min(max(f, 0), 1)
}

struct ColorParams {
  var enabled = false
  var r: Float = 0, g: Float = 0, b: Float = 0
  var amount: Float = 0

  static let disabled = ColorParams()

  /// Apagado si falta el mapa, el color no es #RRGGBB o [amountKey] no es > 0.
  static func from(_ map: [String: Any]?, amountKey: String) -> ColorParams {
    guard let map = map, let hex = map["color"] as? String, hex.count == 7, hex.hasPrefix("#"),
          let rgb = Int(hex.dropFirst(), radix: 16),
          hex.dropFirst().allSatisfy({ $0.isHexDigit }),
          let amount = unit(map[amountKey]), amount > 0 else {
      return .disabled
    }
    return ColorParams(enabled: true, r: Float((rgb >> 16) & 0xFF) / 255, g: Float((rgb >> 8) & 0xFF) / 255,
                       b: Float(rgb & 0xFF) / 255, amount: amount)
  }
}

struct LipParams {
  var color = ColorParams.disabled
  var finish = EngineConst.lipSatin
  var gloss: Float = 0
  var lumaFollow: Float = 0
  var liner = ColorParams.disabled

  private static let finishes: [String: Int32] = [
    "matte": EngineConst.lipMatte, "satin": EngineConst.lipSatin, "gloss": EngineConst.lipGloss,
    "shimmer": EngineConst.lipShimmer,
  ]
  // Brillo por acabado si la receta no lo trae (docs/ar_engine/LIPS.md).
  private static let defaultGloss: [Int32: Float] = [
    EngineConst.lipMatte: 0, EngineConst.lipSatin: 0.3, EngineConst.lipGloss: 0.6, EngineConst.lipShimmer: 0.5,
  ]

  static func from(_ lips: [String: Any]?) -> LipParams {
    let color = ColorParams.from(lips, amountKey: "opacity")
    guard color.enabled, let lips = lips else { return LipParams() }
    let finish = finishes[lips["finish"] as? String ?? ""] ?? EngineConst.lipSatin
    return LipParams(
      color: color, finish: finish, gloss: unit(lips["gloss"]) ?? defaultGloss[finish] ?? 0,
      lumaFollow: unit(lips["lumaFollow"]) ?? 0.8,
      liner: ColorParams.from(lips["liner"] as? [String: Any], amountKey: "opacity"))
  }
}

struct CheekParams {
  var color = ColorParams.disabled
  var spread: Float = 0.5
  var placement = EngineConst.cheekApple

  static func from(_ cheeks: [String: Any]?) -> CheekParams {
    let color = ColorParams.from(cheeks, amountKey: "opacity")
    guard color.enabled, let cheeks = cheeks else { return CheekParams() }
    let placements: [String: Int32] = [
      "apple": EngineConst.cheekApple, "high": EngineConst.cheekHigh, "low": EngineConst.cheekLow,
    ]
    return CheekParams(color: color, spread: unit(cheeks["spread"]) ?? 0.5,
                       placement: placements[cheeks["placement"] as? String ?? ""] ?? EngineConst.cheekApple)
  }
}

struct ShadowParams {
  var color = ColorParams.disabled
  var region = EngineConst.eyeLid
  var finish = EngineConst.shadowMatte

  static func from(_ shadow: [String: Any]?) -> ShadowParams {
    let regions: [String: Int32] = [
      "lid": EngineConst.eyeLid, "crease": EngineConst.eyeCrease, "outer_v": EngineConst.eyeOuterV,
      "inner_corner": EngineConst.eyeInnerCorner, "brow_bone": EngineConst.eyeBrowBone,
    ]
    let finishes: [String: Int32] = [
      "matte": EngineConst.shadowMatte, "satin": EngineConst.shadowSatin, "shimmer": EngineConst.shadowShimmer,
    ]
    let color = ColorParams.from(shadow, amountKey: "opacity")
    // La región es obligatoria: sin una válida, la sombra se apaga.
    guard color.enabled, let shadow = shadow, let region = regions[shadow["region"] as? String ?? ""] else {
      return ShadowParams()
    }
    return ShadowParams(color: color, region: region,
                        finish: finishes[shadow["finish"] as? String ?? ""] ?? EngineConst.shadowMatte)
  }
}

struct EyesParams {
  var shadows = Array(repeating: ShadowParams(), count: EngineConst.maxEyeShadows)
  var liner = ColorParams.disabled
  var thickness: Float = 0.5
  var wing: Float = 0
  var lashesEnabled = false
  var lashOpacity: Float = 0
  var lashLength: Float = 0.5
  var lashVolume: Float = 0.5
  var iris = ColorParams.disabled

  static func from(_ eyes: [String: Any]?) -> EyesParams {
    guard let eyes = eyes else { return EyesParams() }
    var out = EyesParams()
    let list = eyes["shadow"] as? [Any] ?? []
    for i in 0..<EngineConst.maxEyeShadows {
      out.shadows[i] = ShadowParams.from(i < list.count ? list[i] as? [String: Any] : nil)
    }
    let liner = eyes["liner"] as? [String: Any]
    out.liner = ColorParams.from(liner, amountKey: "opacity")
    if out.liner.enabled, let liner = liner {
      out.thickness = unit(liner["thickness"]) ?? 0.5
      out.wing = unit(liner["wing"]) ?? 0
    }
    // Pestañas sin opacidad numérica > 0: apagadas.
    if let lashes = eyes["lashes"] as? [String: Any], let opacity = unit(lashes["opacity"]), opacity > 0 {
      out.lashesEnabled = true
      out.lashOpacity = opacity
      out.lashLength = unit(lashes["length"]) ?? 0.5
      out.lashVolume = unit(lashes["volume"]) ?? 0.5
    }
    out.iris = ColorParams.from(eyes["iris"] as? [String: Any], amountKey: "opacity")
    return out
  }
}

struct EffectParams {
  var enabled = false
  var type = EngineConst.effectGlitter
  var intensity: Float = 0
  var region = EngineConst.effectEyes

  static func list(_ effects: [Any]?) -> [EffectParams] {
    let types: [String: Int32] = [
      "freckles": EngineConst.effectFreckles, "glitter": EngineConst.effectGlitter, "sheen": EngineConst.effectSheen,
    ]
    let regions: [String: Int32] = [
      "cheeks_nose": EngineConst.effectCheeksNose, "eyes": EngineConst.effectEyes, "lips": EngineConst.effectLips,
      "full_face": EngineConst.effectFullFace,
    ]
    let list = effects ?? []
    return (0..<EngineConst.maxEffects).map { i in
      guard i < list.count, let effect = list[i] as? [String: Any],
            let type = types[effect["type"] as? String ?? ""],
            let intensity = unit(effect["intensity"]), intensity > 0 else {
        return EffectParams()
      }
      // Sin región, la del tipo: glitter en los ojos, sheen y pecas en mejillas y nariz.
      let fallback = type == EngineConst.effectGlitter ? EngineConst.effectEyes : EngineConst.effectCheeksNose
      return EffectParams(enabled: true, type: type, intensity: intensity,
                          region: regions[effect["region"] as? String ?? ""] ?? fallback)
    }
  }
}

struct RecipeParams {
  var lips = LipParams()
  var cheeks = CheekParams()
  var skin = [ColorParams.disabled, ColorParams.disabled, ColorParams.disabled]  // base, contorno, iluminador
  var eyes = EyesParams()
  var effects = EffectParams.list(nil)

  static func from(_ recipe: [String: Any]?) -> RecipeParams {
    var out = RecipeParams()
    out.lips = LipParams.from(recipe?["lips"] as? [String: Any])
    out.cheeks = CheekParams.from(recipe?["cheeks"] as? [String: Any])
    if let skin = recipe?["skin"] as? [String: Any] {
      out.skin = [
        ColorParams.from(skin["foundation"] as? [String: Any], amountKey: "coverage"),
        ColorParams.from(skin["contour"] as? [String: Any], amountKey: "opacity"),
        ColorParams.from(skin["highlight"] as? [String: Any], amountKey: "opacity"),
      ]
    }
    out.eyes = EyesParams.from(recipe?["eyes"] as? [String: Any])
    out.effects = EffectParams.list(recipe?["effects"] as? [Any])
    return out
  }

  /// Manda la receta entera al núcleo y la publica (commit).
  func apply(to engine: OpaquePointer) {
    let l = lips
    makeup_set_lips(engine, l.color.enabled, l.color.r, l.color.g, l.color.b, l.color.amount, l.finish, l.gloss,
                    l.lumaFollow)
    makeup_set_lip_liner(engine, l.liner.enabled, l.liner.r, l.liner.g, l.liner.b, l.liner.amount)
    let c = cheeks.color
    makeup_set_cheeks(engine, c.enabled, c.r, c.g, c.b, c.amount, cheeks.spread, cheeks.placement)
    for (layer, s) in skin.enumerated() {
      makeup_set_skin_layer(engine, Int32(layer), s.enabled, s.r, s.g, s.b, s.amount)
    }
    for (slot, shadow) in eyes.shadows.enumerated() {
      let s = shadow.color
      makeup_set_eye_shadow(engine, Int32(slot), s.enabled, s.r, s.g, s.b, s.amount, shadow.region, shadow.finish)
    }
    let ink = eyes.liner
    makeup_set_liner(engine, ink.enabled, ink.r, ink.g, ink.b, ink.amount, eyes.thickness, eyes.wing)
    makeup_set_lashes(engine, eyes.lashesEnabled, eyes.lashOpacity, eyes.lashLength, eyes.lashVolume)
    let iris = eyes.iris
    makeup_set_iris(engine, iris.enabled, iris.r, iris.g, iris.b, iris.amount)
    for (slot, effect) in effects.enumerated() {
      makeup_set_effect(engine, Int32(slot), effect.enabled, effect.type, effect.intensity, effect.region)
    }
    makeup_commit_recipe(engine)
  }
}

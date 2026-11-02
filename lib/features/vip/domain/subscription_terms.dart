/// Condiciones de un plan VIP para mostrar antes de comprar (Ley 24.240
/// art. 4; App Store 3.1.2; política de suscripciones de Google Play):
/// precio, período, renovación y oferta de introducción tal como las informa
/// la tienda. Dominio puro: el paywall lo traduce.
library;

enum PeriodUnit { day, week, month, year }

final class SubscriptionPeriod {
  const SubscriptionPeriod(this.count, this.unit);

  final int count;
  final PeriodUnit unit;

  static final RegExp _iso = RegExp(r'^P(?:(\d+)Y)?(?:(\d+)M)?(?:(\d+)W)?(?:(\d+)D)?$');

  /// Duración ISO 8601 de la tienda (`P1M`, `P3M`, `P1Y`, `P7D`...). null si
  /// falta, es ilegible o mezcla unidades (no se adivina: el paywall muestra
  /// entonces el texto de la tienda).
  static SubscriptionPeriod? parse(String? iso) {
    if (iso == null) return null;
    final match = _iso.firstMatch(iso.trim().toUpperCase());
    if (match == null) return null;
    const units = [PeriodUnit.year, PeriodUnit.month, PeriodUnit.week, PeriodUnit.day];
    SubscriptionPeriod? found;
    for (var i = 0; i < units.length; i++) {
      final value = int.tryParse(match.group(i + 1) ?? '') ?? 0;
      if (value == 0) continue;
      if (found != null) return null;
      found = SubscriptionPeriod(value, units[i]);
    }
    return found;
  }

  /// [cycles] períodos seguidos (una oferta de 3 ciclos de 1 mes = 3 meses).
  SubscriptionPeriod times(int cycles) => SubscriptionPeriod(count * (cycles < 1 ? 1 : cycles), unit);

  @override
  bool operator ==(Object other) => other is SubscriptionPeriod && other.count == count && other.unit == unit;

  @override
  int get hashCode => Object.hash(count, unit);

  @override
  String toString() => 'SubscriptionPeriod($count ${unit.name})';
}

/// Oferta de introducción o prueba gratuita.
final class IntroOffer {
  const IntroOffer({required this.isFreeTrial, required this.priceString, required this.duration});

  final bool isFreeTrial;
  final String priceString;

  /// Duración total de la oferta; null si la tienda no la informa legible.
  final SubscriptionPeriod? duration;
}

final class SubscriptionTerms {
  const SubscriptionTerms({required this.priceString, required this.period, this.rawPeriod, this.intro});

  /// Datos crudos del producto de la tienda (StoreProduct de RevenueCat).
  factory SubscriptionTerms.fromStore({
    required String priceString,
    required String? subscriptionPeriod,
    double? introPrice,
    String? introPriceString,
    String? introPeriod,
    int introCycles = 1,
  }) {
    IntroOffer? intro;
    if (introPrice != null && introPriceString != null) {
      intro = IntroOffer(
        isFreeTrial: introPrice <= 0,
        priceString: introPriceString,
        duration: SubscriptionPeriod.parse(introPeriod)?.times(introCycles),
      );
    }
    final raw = subscriptionPeriod == null || subscriptionPeriod.trim().isEmpty ? null : subscriptionPeriod.trim();
    return SubscriptionTerms(
      priceString: priceString,
      period: SubscriptionPeriod.parse(raw),
      rawPeriod: raw,
      intro: intro,
    );
  }

  final String priceString;

  /// Período legible; null si es pago único o si la tienda mandó algo que no
  /// se pudo leer (ver [rawPeriod]).
  final SubscriptionPeriod? period;

  /// Período tal como lo mandó la tienda; null = pago único.
  final String? rawPeriod;
  final IntroOffer? intro;

  /// Suscripción que se renueva sola (la tienda informó un período).
  bool get isAutoRenewing => rawPeriod != null;
}

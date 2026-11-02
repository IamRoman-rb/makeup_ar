import '../../../l10n/app_localizations.dart';
import '../domain/subscription_terms.dart';

/// "mes", "3 meses", "año"...
String periodText(AppLocalizations l10n, SubscriptionPeriod period) => switch (period.unit) {
      PeriodUnit.day => l10n.vipPeriodDays(period.count),
      PeriodUnit.week => l10n.vipPeriodWeeks(period.count),
      PeriodUnit.month => l10n.vipPeriodMonths(period.count),
      PeriodUnit.year => l10n.vipPeriodYears(period.count),
    };

/// Precio con su período ("$ 4.999 cada mes"), o "pago único". Si la tienda
/// mandó un período que no se pudo leer, se muestra tal cual: nunca se
/// presenta una suscripción como pago único.
String priceText(AppLocalizations l10n, SubscriptionTerms terms) {
  final period = terms.period;
  if (period != null) return l10n.vipPricePerPeriod(terms.priceString, periodText(l10n, period));
  final raw = terms.rawPeriod;
  if (raw != null) return l10n.vipPricePerPeriod(terms.priceString, raw);
  return l10n.vipOneTime(terms.priceString);
}

/// Prueba gratis u oferta de introducción; null si no hay o si la tienda no
/// informa su duración (no se inventa).
String? introText(AppLocalizations l10n, SubscriptionTerms terms) {
  final intro = terms.intro;
  final duration = intro?.duration;
  if (intro == null || duration == null) return null;
  final length = periodText(l10n, duration);
  return intro.isFreeTrial ? l10n.vipFreeTrial(length) : l10n.vipIntroOffer(intro.priceString, length);
}

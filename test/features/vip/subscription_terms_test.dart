import 'package:ar_makeup_app/features/vip/domain/subscription_terms.dart';
import 'package:ar_makeup_app/features/vip/presentation/subscription_texts.dart';
import 'package:ar_makeup_app/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SubscriptionPeriod.parse', () {
    test('lee las duraciones ISO 8601 de las tiendas', () {
      expect(SubscriptionPeriod.parse('P1M'), const SubscriptionPeriod(1, PeriodUnit.month));
      expect(SubscriptionPeriod.parse('P3M'), const SubscriptionPeriod(3, PeriodUnit.month));
      expect(SubscriptionPeriod.parse('P1Y'), const SubscriptionPeriod(1, PeriodUnit.year));
      expect(SubscriptionPeriod.parse('P1W'), const SubscriptionPeriod(1, PeriodUnit.week));
      expect(SubscriptionPeriod.parse('p7d'), const SubscriptionPeriod(7, PeriodUnit.day));
    });

    test('no adivina: vacío, ilegible o con unidades mezcladas da null', () {
      expect(SubscriptionPeriod.parse(null), isNull);
      expect(SubscriptionPeriod.parse(''), isNull);
      expect(SubscriptionPeriod.parse('mensual'), isNull);
      expect(SubscriptionPeriod.parse('P1M15D'), isNull);
    });

    test('ciclos de una oferta', () {
      expect(const SubscriptionPeriod(1, PeriodUnit.month).times(3), const SubscriptionPeriod(3, PeriodUnit.month));
      expect(const SubscriptionPeriod(1, PeriodUnit.week).times(0), const SubscriptionPeriod(1, PeriodUnit.week));
    });
  });

  group('textos del paywall (es)', () {
    late AppLocalizations es;
    setUpAll(() async => es = await AppLocalizations.delegate.load(const Locale('es')));

    test('mensual con prueba gratis', () {
      final terms = SubscriptionTerms.fromStore(
        priceString: r'$ 4.999',
        subscriptionPeriod: 'P1M',
        introPrice: 0,
        introPriceString: r'$ 0',
        introPeriod: 'P1W',
      );
      expect(terms.isAutoRenewing, isTrue);
      expect(priceText(es, terms), r'$ 4.999 cada mes');
      expect(introText(es, terms), 'Prueba gratis: semana');
    });

    test('anual con precio de introducción por 3 ciclos', () {
      final terms = SubscriptionTerms.fromStore(
        priceString: r'$ 40.000',
        subscriptionPeriod: 'P3M',
        introPrice: 1000,
        introPriceString: r'$ 1.000',
        introPeriod: 'P1M',
        introCycles: 3,
      );
      expect(priceText(es, terms), r'$ 40.000 cada 3 meses');
      expect(introText(es, terms), r'Precio de introducción: $ 1.000 durante 3 meses');
    });

    test('pago único y período ilegible: nunca se muestra una suscripción como pago único', () {
      final once = SubscriptionTerms.fromStore(priceString: r'$ 9.999', subscriptionPeriod: null);
      expect(once.isAutoRenewing, isFalse);
      expect(priceText(es, once), r'$ 9.999, pago único');
      expect(introText(es, once), isNull);

      final odd = SubscriptionTerms.fromStore(priceString: r'$ 1', subscriptionPeriod: 'P1M15D');
      expect(odd.isAutoRenewing, isTrue);
      expect(priceText(es, odd), r'$ 1 cada P1M15D');
    });

    test('oferta sin duración legible no se muestra', () {
      final terms = SubscriptionTerms.fromStore(
        priceString: r'$ 1',
        subscriptionPeriod: 'P1M',
        introPrice: 0,
        introPriceString: r'$ 0',
        introPeriod: 'raro',
      );
      expect(introText(es, terms), isNull);
    });
  });
}

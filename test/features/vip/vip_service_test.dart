import 'package:ar_makeup_app/features/vip/data/revenue_cat_config.dart';
import 'package:ar_makeup_app/features/vip/data/vip_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sin key (tests corren sin --dart-define): el VIP queda desactivado sin tocar el SDK', () async {
    expect(RevenueCatConfig.androidKey, isEmpty);
    await VipService.configure();
    expect(VipService.isAvailable, isFalse);
    expect(await VipService.fetchCurrentOffering(), isNull);
    expect(await VipService.restore(), isNull);
    expect(await VipService.activeUntil(), isNull);
    await VipService.loginUser('u1');
  });

  test('el entitlement por defecto es "vip"', () {
    expect(RevenueCatConfig.entitlementId, 'vip');
  });

  group('vencimiento del entitlement', () {
    test('inactivo: null aunque tenga fecha', () {
      expect(VipService.untilFrom(isActive: false, expirationDate: '2030-01-01T00:00:00Z'), isNull);
    });

    test('activo con fecha: esa fecha', () {
      expect(VipService.untilFrom(isActive: true, expirationDate: '2030-01-01T00:00:00Z'), DateTime.utc(2030));
    });

    test('activo sin fecha (de por vida) o con fecha ilegible: no vence', () {
      expect(VipService.untilFrom(isActive: true), VipService.lifetime);
      expect(VipService.untilFrom(isActive: true, expirationDate: 'mañana'), VipService.lifetime);
    });
  });
}

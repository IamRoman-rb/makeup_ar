import 'package:ar_makeup_app/features/vip/data/revenue_cat_config.dart';
import 'package:ar_makeup_app/features/vip/data/vip_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sin key (tests corren sin --dart-define): el VIP queda desactivado sin tocar el SDK', () async {
    expect(RevenueCatConfig.androidKey, isEmpty);
    await VipService.configure();
    expect(VipService.isAvailable, isFalse);
    expect(await VipService.fetchCurrentOffering(), isNull);
    expect(await VipService.restore(), isFalse);
    await VipService.loginCurrentUser();
  });

  test('el entitlement por defecto coincide con el del webhook', () {
    expect(RevenueCatConfig.entitlementId, 'vip');
  });
}

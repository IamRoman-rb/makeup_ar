import 'package:ar_makeup_app/vip/premium_content.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 10, 16, 12);

  test('VIP solo con premium_until en el futuro', () {
    expect(isPremiumUser({'premium_until': Timestamp.fromDate(now.add(const Duration(days: 1)))}, now: now), isTrue);
    expect(isPremiumUser({'premium_until': now.add(const Duration(minutes: 1))}, now: now), isTrue);
    expect(isPremiumUser({'premium_until': Timestamp.fromDate(now.subtract(const Duration(seconds: 1)))}, now: now),
        isFalse);
    expect(isPremiumUser({'premium_until': Timestamp.fromDate(now)}, now: now), isFalse);
  });

  test('is_premium viejo, datos raros o sin documento: no es VIP', () {
    expect(isPremiumUser({'is_premium': true}, now: now), isFalse);
    expect(isPremiumUser({'premium_until': '2099-01-01'}, now: now), isFalse);
    expect(isPremiumUser({}, now: now), isFalse);
    expect(isPremiumUser(null, now: now), isFalse);
  });
}

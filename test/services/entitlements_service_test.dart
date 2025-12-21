import 'package:flutter_test/flutter_test.dart';
import 'package:seayou_app/services/entitlements_service.dart';

class DummyEntitlementsService extends EntitlementsService {
  final String tier;
  DummyEntitlementsService(this.tier);
  @override
  Future<String> getTier(String userId) async => tier;
}

void main() {
  test('Premium mapping returns true for premium', () async {
    final svc = DummyEntitlementsService('premium');
    expect(await svc.isPremium('user'), isTrue);
    expect(await svc.isElite('user'), isFalse);
  });

  test('Elite mapping returns true for elite', () async {
    final svc = DummyEntitlementsService('elite');
    expect(await svc.isPremium('user'), isTrue);
    expect(await svc.isElite('user'), isTrue);
  });

  test('Free mapping returns false for premium/elite', () async {
    final svc = DummyEntitlementsService('free');
    expect(await svc.isPremium('user'), isFalse);
    expect(await svc.isElite('user'), isFalse);
  });
}

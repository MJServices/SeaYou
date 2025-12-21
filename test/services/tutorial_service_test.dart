import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:seayou_app/services/tutorial_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('TutorialService new keys default to false and set to true', () async {
    SharedPreferences.setMockInitialValues({});
    final t = TutorialService();

    expect(await t.hasSeenSignupCoachmark(), false);
    await t.setSeenSignupCoachmark();
    expect(await t.hasSeenSignupCoachmark(), true);

    expect(await t.hasSeenQuoteTip(), false);
    await t.setSeenQuoteTip();
    expect(await t.hasSeenQuoteTip(), true);

    expect(await t.hasSeenAudioTip(), false);
    await t.setSeenAudioTip();
    expect(await t.hasSeenAudioTip(), true);

    expect(await t.hasSeenPremiumGateTip(), false);
    await t.setSeenPremiumGateTip();
    expect(await t.hasSeenPremiumGateTip(), true);
  });
}

import 'package:shared_preferences/shared_preferences.dart';

class TutorialService {
  static const _keySeenHomeTutorial = 'seen_home_tutorial';
  static const _keySeenPhotoTooltip = 'seen_photo_tooltip';
  static const _keySeenSignupCoachmark = 'seen_signup_coachmark';
  static const _keySeenQuoteTip = 'seen_quote_tip';
  static const _keySeenAudioTip = 'seen_audio_tip';
  static const _keySeenPremiumGateTip = 'seen_premium_gate_tip';

  Future<bool> hasSeenHomeTutorial() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_keySeenHomeTutorial) ?? false;
  }

  Future<void> setSeenHomeTutorial() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_keySeenHomeTutorial, true);
  }

  Future<bool> hasSeenPhotoTooltip() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_keySeenPhotoTooltip) ?? false;
  }

  Future<void> setSeenPhotoTooltip() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_keySeenPhotoTooltip, true);
  }

  Future<bool> hasSeenSignupCoachmark() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_keySeenSignupCoachmark) ?? false;
  }

  Future<void> setSeenSignupCoachmark() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_keySeenSignupCoachmark, true);
  }

  Future<bool> hasSeenQuoteTip() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_keySeenQuoteTip) ?? false;
  }

  Future<void> setSeenQuoteTip() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_keySeenQuoteTip, true);
  }

  Future<bool> hasSeenAudioTip() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_keySeenAudioTip) ?? false;
  }

  Future<void> setSeenAudioTip() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_keySeenAudioTip, true);
  }

  Future<bool> hasSeenPremiumGateTip() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_keySeenPremiumGateTip) ?? false;
  }

  Future<void> setSeenPremiumGateTip() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_keySeenPremiumGateTip, true);
  }

  /// Clears all tutorial flags - call this on logout to ensure tutorials show for new accounts
  Future<void> clearAllTutorials() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_keySeenHomeTutorial);
    await p.remove(_keySeenPhotoTooltip);
    await p.remove(_keySeenSignupCoachmark);
    await p.remove(_keySeenQuoteTip);
    await p.remove(_keySeenAudioTip);
    await p.remove(_keySeenPremiumGateTip);
  }
}

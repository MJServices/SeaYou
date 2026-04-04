import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/language_selection_screen.dart';
import '../screens/home_screen.dart';
import '../screens/splash_screen.dart';
import 'database_service.dart';
import '../screens/create_account_screen.dart';
import '../screens/verification_screen.dart';
import '../screens/create_password_screen.dart';
import '../screens/profile_info_screen.dart';
import '../screens/gender_identity_screen.dart';
import '../screens/sexual_orientation_screen.dart';
import '../screens/expectations_screen.dart';
import '../screens/interests_screen.dart';
import '../screens/upload_picture_screen.dart';
import '../models/user_profile.dart';
import 'localization_service.dart';
import 'presence_service.dart';

enum OnboardingStep {
  languageSelection,
  createAccount,
  verification,
  createPassword,
  profileInfo,
  genderIdentity,
  sexualOrientation,
  expectations,
  interests,
  uploadPicture,
  completed
}

class OnboardingService {
  static const String _stepKey = 'onboarding_step';
  static const String _emailKey = 'onboarding_pending_email';
  static const String _tempPasswordKey = 'onboarding_temp_password';

  static final OnboardingService _instance = OnboardingService._internal();
  factory OnboardingService() => _instance;
  OnboardingService._internal();

  Future<void> saveStep(OnboardingStep step) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_stepKey, step.name);
  }

  Future<OnboardingStep> getStep() async {
    final prefs = await SharedPreferences.getInstance();
    final stepName = prefs.getString(_stepKey);
    if (stepName == null) return OnboardingStep.languageSelection;
    return OnboardingStep.values.firstWhere(
      (e) => e.name == stepName,
      orElse: () => OnboardingStep.languageSelection,
    );
  }

  Future<void> savePendingEmail(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_emailKey, email);
  }

  Future<String?> getPendingEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_emailKey);
  }

  Future<void> saveTempPassword(String password) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tempPasswordKey, password);
  }

  Future<String?> getTempPassword() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tempPasswordKey);
  }

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_stepKey);
    await prefs.remove(_emailKey);
    await prefs.remove(_tempPasswordKey);
  }

  /// Strict state machine for onboarding resumption
  Future<void> resumeOnboarding(
    BuildContext context,
    Map<String, dynamic>? profile, {
    OnboardingStep? currentStep,
    OnboardingStep? forcedStep,
    User? user, 
  }) async {
    final activeUser = user ?? Supabase.instance.client.auth.currentUser;
    debugPrint('AUTH_DEBUG: resumeOnboarding (Ideal Router). User: ${activeUser?.id}, forcedStep: $forcedStep, currentStep: $currentStep');

    OnboardingStep resumeStep;
    final localStep = await getStep();

    // 0. IMMEDIATE BLOCK CHECK
    if (profile != null && profile['is_blocked'] == true) {
      debugPrint('🚫 AUTH_DEBUG: User is BLOCKED. Terminating session.');
      await Supabase.instance.client.auth.signOut();
      DatabaseService.clearCache();
      if (context.mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const SplashScreen()),
          (route) => false,
        );
      }
      return;
    }

    // 1. If NO user session
    if (activeUser == null) {
      resumeStep = forcedStep ?? localStep;
      debugPrint('AUTH_DEBUG: No session. Resuming from Local Step: $resumeStep');
      if (context.mounted) {
        await navigateToStep(context, resumeStep, currentStep: currentStep);
      }
      return;
    }

    // 2. Verification screen sticky behavior
    if (currentStep == OnboardingStep.verification && forcedStep == null) {
      debugPrint('AUTH_DEBUG: User is on Verification Screen. Respecting active step.');
      resumeStep = OnboardingStep.verification; 
      if (context.mounted) {
        await navigateToStep(context, resumeStep, currentStep: currentStep);
      }
      return;
    }

    // 3. Determine progress based on profile
    if (profile == null) {
      debugPrint('AUTH_DEBUG: Session exists but profile is null. Waiting for data...');
      return;
    }

    bool isFieldEmpty(dynamic value) {
      if (value == null) return true;
      if (value is String) return value.trim().isEmpty;
      if (value is List) return value.isEmpty;
      return false;
    }

    // NEW: Respect forcedStep for authenticated users too!
    // This allows VerificationScreen to force the "Create Password" step
    if (forcedStep != null) {
      debugPrint('AUTH_DEBUG: Respecting forcedStep for authenticated user: $forcedStep');
      if (context.mounted) {
        await navigateToStep(context, forcedStep, currentStep: currentStep);
      }
      return;
    }

    if (!isFieldEmpty(profile['avatar_url'])) {
      // ALL STEPS COMPLETE.
      debugPrint('AUTH_DEBUG: Avatar found. User is fully onboarded. Entering Home.');
      await clearAll();
      PresenceService.instance.init();
      
      if (currentStep != OnboardingStep.completed && context.mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
          (route) => false,
        );
      }
      return;
    }

    // Determine incomplete step
    if (isFieldEmpty(profile['full_name'])) {
      resumeStep = OnboardingStep.profileInfo;
    } else if (isFieldEmpty(profile['gender'])) {
      resumeStep = OnboardingStep.genderIdentity;
    } else if (isFieldEmpty(profile['sexual_orientation'])) {
      resumeStep = OnboardingStep.sexualOrientation;
    } else if (isFieldEmpty(profile['expectation'])) {
      resumeStep = OnboardingStep.expectations;
    } else if (isFieldEmpty(profile['interests'])) {
      resumeStep = OnboardingStep.interests;
    } else {
      resumeStep = OnboardingStep.uploadPicture;
    }

    debugPrint('AUTH_DEBUG: Final determined resumeStep: $resumeStep');
    if (context.mounted) {
      await navigateToStep(context, resumeStep, currentStep: currentStep);
    }
  }

  /// Screen navigation based on onboarding step - shared across the app
  Future<void> navigateToStep(BuildContext context, OnboardingStep step,
      {OnboardingStep? currentStep}) async {
    debugPrint('AUTH_DEBUG: navigateToStep called. Step: $step, currentStep: $currentStep');
    if (step == currentStep) {
      debugPrint('AUTH_DEBUG: Skipping redundant navigation to $step');
      return;
    }

    final email = await getPendingEmail() ?? '';
    debugPrint('AUTH_DEBUG: pendingEmail: $email');
    final lang = LocalizationService.instance.locale.value.languageCode;

    Widget? targetScreen;

    switch (step) {
      case OnboardingStep.languageSelection:
        targetScreen = const LanguageSelectionScreen();
        break;
      case OnboardingStep.createAccount:
        targetScreen = CreateAccountScreen(selectedLanguage: lang);
        break;
      case OnboardingStep.verification:
        if (email.isNotEmpty) {
          targetScreen = VerificationScreen(email: email);
        } else {
          targetScreen = CreateAccountScreen(selectedLanguage: lang);
        }
        break;
      case OnboardingStep.createPassword:
        final tempPass = await getTempPassword();
        targetScreen = CreatePasswordScreen(
          email: email,
          tempPassword: tempPass,
          selectedLanguage: lang,
        );
        break;
      case OnboardingStep.profileInfo:
        targetScreen = ProfileInfoScreen(email: email, selectedLanguage: lang);
        break;
      case OnboardingStep.genderIdentity:
        targetScreen = GenderIdentityScreen(
            userProfile: UserProfile(email: email, language: lang));
        break;
      case OnboardingStep.sexualOrientation:
        targetScreen = SexualOrientationScreen(
            userProfile: UserProfile(email: email, language: lang));
        break;
      case OnboardingStep.expectations:
        targetScreen = ExpectationsScreen(
            userProfile: UserProfile(email: email, language: lang));
        break;
      case OnboardingStep.interests:
        targetScreen = InterestsScreen(
            userProfile: UserProfile(email: email, language: lang));
        break;
      case OnboardingStep.uploadPicture:
        targetScreen = UploadPictureScreen(
            userProfile: UserProfile(email: email, language: lang));
        break;
      default:
        break;
    }

    if (targetScreen != null && context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => targetScreen!),
      );
    }
  }
}

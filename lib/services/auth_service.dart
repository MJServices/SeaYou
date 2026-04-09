import 'package:supabase_flutter/supabase_flutter.dart';
import 'onboarding_service.dart';
import 'database_service.dart';
import 'entitlements_service.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Sign up with email (sends OTP via email)
  // This will send a 6-digit OTP code to the user's email
  // Creates user if doesn't exist
  Future<void> _log(String message) async {
    print('AUTH_DEBUG: $message');
  }

  // Sign up with email (sends OTP via email)
  Future<String> signUpWithEmail(String email, {String? password}) async {
    try {
      await _log('🚀 signUpWithEmail called for: $email');

      // Use provided password or generate a temporary one
      final finalPassword =
          password ?? 'temp-${DateTime.now().millisecondsSinceEpoch}';

      await _log(
          '🔐 Sending OTP (signUp with temp password, redirect=seayou://login-callback) to: $email');

      // 🔐 DELAYED SIGNUP: We no longer call _supabase.auth.signUp here.
      // Instead, we only send the Custom OTP.
      // The user record will be created in the verify-otp Edge Function ONLY after successful verification.
      
      // Use standard signUp instead of Magic Link to trigger "Confirm Signup" template
      // await _supabase.auth.signUp(
      //   email: email,
      //   password: finalPassword,
      // );

      // CUSTOM OTP FLOW: Send OTP immediately after signup
      await sendCustomOtp(email);

      await _log('✅ Signup confirmed - Custom OTP sent to: $email');
      await _log('✅ Signup confirmed - Verification email sent to: $email');
      return finalPassword;
    } catch (e) {
      await _log('❌ Error sending OTP: $e');
      rethrow;
    }
  }

  // Check if email exists (Secure Edge Function)
  // Replaces direct query to avoid RLS issues for unauthenticated users
  Future<bool> checkEmailExists(String email) async {
    try {
      await _log('🔍 Checking email existence via Edge Function: $email');
      final response = await _supabase.functions.invoke(
        'check-email',
        body: {'email': email},
      );

      if (response.status != 200) {
        throw Exception('Failed to check email: ${response.data}');
      }

      final exists = response.data['exists'] as bool;
      await _log('Search result for $email: ${exists ? "FOUND" : "NOT FOUND"}');
      return exists;
    } catch (e) {
      await _log('⚠️ Error checking email existence: $e');
      // Fail safely: If we can't check, assume it exists to prevent overwrites?
      // Or false to allow flow? Let's return false but log it.
      return false;
    }
  }

  // Sign in with email (sends OTP only if user exists)
  Future<void> signInWithEmailOtp(String email) async {
    try {
      await _log('🚀 signInWithEmailOtp called for: $email');
      await _log('🔍 Pre-check if email exists: $email');
      // First check if email exists in profiles table
      final emailExists = await checkEmailExists(email);

      if (!emailExists) {
        await _log('❌ Email not found, aborting sign in: $email');
        throw Exception(
            'No account found with this email. Please sign up first.');
      }

      await _log(
          '🔐 Email exists, sending CUSTOM OTP via Edge Function for: $email');
      // Always use Custom OTP for consistency with VerificationScreen
      await sendCustomOtp(email);
      await _log('✅ Custom OTP sent successfully to: $email');
    } catch (e) {
      await _log('❌ Error in signInWithEmailOtp: $e');
      rethrow;
    }
  }

  // Sign in with email and password
  Future<AuthResponse> signInWithPassword(String email, String password) async {
    return await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  // Sign in with Magic Link (Standard Supabase fallback)
  Future<void> signInWithMagicLink(String email) async {
    try {
      await _log('🚀 signInWithMagicLink called for: $email');
      await _supabase.auth.signInWithOtp(
        email: email,
        emailRedirectTo: 'seayou://login-callback',
      );
      await _log('✅ Magic Link initiated for: $email');
    } catch (e) {
      await _log('❌ Error in signInWithMagicLink: $e');
      rethrow;
    }
  }

  // Verify OTP
  Future<AuthResponse> verifyOtp(String email, String token,
      {OtpType type = OtpType.email}) async {
    await _log('🔐 Verifying OTP for: $email, Token: $token, Type: $type');
    final response = await _supabase.auth.verifyOTP(
      email: email,
      token: token,
      type: type,
    );
    await _log('✅ Verify OTP success. User: ${response.user?.id}');
    return response;
  }

  // Update password (for new account creation)
  Future<UserResponse> updatePassword(String password) async {
    return await _supabase.auth.updateUser(
      UserAttributes(password: password),
    );
  }

  // --- Custom OTP Methods ---

  // Send Custom OTP via Edge Function
  Future<void> sendCustomOtp(String email) async {
    try {
      await _log('🚀 Sending Custom OTP to: $email');
      final response = await _supabase.functions.invoke(
        'send-otp',
        body: {'email': email.toLowerCase().trim()},
      );

      if (response.status != 200) {
        throw Exception('Failed to send OTP: ${response.data}');
      }
      await _log('✅ Custom OTP Sent Successfully');
    } catch (e) {
      await _log('❌ Error sending Custom OTP: $e');
      rethrow;
    }
  }

  // Verify Custom OTP via Edge Function
  // Handles both verification and establishing a session if the Edge Function returns a session token
  Future<AuthResponse?> verifyCustomOtp(String email, String code) async {
    try {
      await _log('🔐 Verifying Custom OTP for: $email');
      final response = await _supabase.functions.invoke(
        'verify-otp',
        body: {'email': email.toLowerCase().trim(), 'code': code},
      );

      await _log('📡 Edge Function Response Status: ${response.status}');
      await _log('📡 Edge Function Response Data: ${response.data}');

      if (response.status != 200) {
        final errorMsg = response.data is Map ? response.data['message'] : response.data.toString();
        await _log('❌ Edge Function Error: $errorMsg (Status ${response.status})');
        throw Exception(errorMsg ?? 'Invalid or expired code (Status ${response.status})');
      }

      await _log('✅ Custom OTP Verified Successfully');

      final data = response.data;
      final tempPassword = data?['temp_password'] as String?;

      if (data != null && tempPassword != null) {
        final verificationTypeStr = data['verification_type'] as String? ?? 'signup';
        await _log('🎟️ Verification successful. Type: $verificationTypeStr');

        // Save temp password for recovery if present
        await _log('🔐 Saving temp password for session recovery fallback');
        await OnboardingService().saveTempPassword(tempPassword);

        // Establish standard session via temporary password
        // This is 100% more reliable than magic links across screen transitions
        final authRes = await signInWithPassword(
          email.toLowerCase().trim(),
          tempPassword,
        );

        await _log('✅ Client Authenticated! User ID: ${authRes.user?.id}');
        return authRes;
      } else {
        await _log('⚠️ Verified but NO temp_password in response data.');
        return null;
      }
    } catch (e) {
      await _log('❌ Error verifying Custom OTP: $e');
      rethrow;
    }
  }

  // Resend verification code (Standard + Custom)
  Future<void> resendVerificationCode(String email, OtpType type) async {
    try {
      print('🔄 Resending verification code ($type) to: $email');
      await _supabase.auth.resend(
        type: type,
        email: email,
      );
      print('✅ Verification code resent successfully');
    } catch (e) {
      print('❌ Error resending verification code: $e');
      rethrow;
    }
  }

  // Reset password for email (Recovery Flow)
  Future<void> resetPasswordForEmail(String email) async {
    try {
      print('🔐 Sending password reset email to: $email');
      await _supabase.auth.resetPasswordForEmail(
        email,
        redirectTo: 'seayou://login-callback',
      );
      print('✅ Password reset email sent successfully');
    } catch (e) {
      print('❌ Error sending reset email: $e');
      rethrow;
    }
  }

  // Update email (requires verification at new email address)
  Future<UserResponse> updateEmail(String newEmail) async {
    try {
      print('🔄 Updating email to: $newEmail');
      final response = await _supabase.auth.updateUser(
        UserAttributes(email: newEmail),
        emailRedirectTo: null,
      );
      print('✅ Email update initiated - verification email sent');
      return response;
    } catch (e) {
      print('❌ Error updating email: $e');
      rethrow;
    }
  }

  // Change password
  Future<UserResponse> changePassword(String newPassword) async {
    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null || currentUser.email == null) {
        throw Exception('No user logged in');
      }

      print('✅ Updating to new password...');
      final response = await _supabase.auth.updateUser(
        UserAttributes(password: newPassword),
      );

      print('✅ Password updated successfully');
      return response;
    } catch (e) {
      print('❌ Error changing password: $e');
      rethrow;
    }
  }

  // Sign out
  Future<void> signOut() async {
    DatabaseService.clearCache();
    EntitlementsService.clearCache();
    await _supabase.auth.signOut();
  }

  // Sign in anonymously (Bypass)
  Future<AuthResponse> signInAnonymously() async {
    try {
      await _log('🕵️ signInAnonymously called');
      final response = await _supabase.auth.signInAnonymously();
      await _log('✅ Anonymous sign in success. User: ${response.user?.id}');
      return response;
    } catch (e) {
      await _log('❌ Error in signInAnonymously: $e');
      rethrow;
    }
  }

  // Get current user
  User? get currentUser => _supabase.auth.currentUser;
}

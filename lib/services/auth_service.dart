import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Sign up with email (sends OTP via email)
  // This will send a 6-digit OTP code to the user's email
  // Creates user if doesn't exist
  Future<void> signUpWithEmail(String email) async {
    try {
      print('🔍 Checking if email already exists: $email');
      // First check if email already exists in profiles table
      final emailExists = await checkEmailExists(email);
      
      if (emailExists) {
        print('❌ Email already exists: $email');
        throw Exception('An account with this email already exists. Please sign in instead.');
      }

      print('🔐 Email is new, sending OTP to: $email');
      await _supabase.auth.signInWithOtp(
        email: email,
        shouldCreateUser: true, // Creates user if doesn't exist
        emailRedirectTo: null, // No redirect - pure OTP flow for mobile
      );
      print('✅ OTP sent successfully to: $email');
    } catch (e) {
      print('❌ Error sending OTP: $e');
      rethrow;
    }
  }

  // Check if email exists in profiles table
  Future<bool> checkEmailExists(String email) async {
    try {
      final response = await _supabase
          .from('profiles')
          .select('email')
          .eq('email', email)
          .maybeSingle();
      
      return response != null;
    } catch (e) {
      print('Error checking email existence: $e');
      return false;
    }
  }

  // Sign in with email (sends OTP only if user exists)
  Future<void> signInWithEmailOtp(String email) async {
    try {
      print('🔍 Checking if email exists: $email');
      // First check if email exists in profiles table
      final emailExists = await checkEmailExists(email);
      
      if (!emailExists) {
        print('❌ Email not found: $email');
        throw Exception('No account found with this email. Please sign up first.');
      }

      print('🔐 Email exists, sending OTP to: $email');
      // Email exists, send OTP
      await _supabase.auth.signInWithOtp(
        email: email,
        shouldCreateUser: false, // Don't create user - they must exist
        emailRedirectTo: null, // No redirect - pure OTP flow for mobile
      );
      print('✅ OTP sent successfully to: $email');
    } catch (e) {
      print('❌ Error in signInWithEmailOtp: $e');
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

  // Verify OTP
  Future<AuthResponse> verifyOtp(String email, String token) async {
    return await _supabase.auth.verifyOTP(
      email: email,
      token: token,
      type: OtpType.email,
    );
  }

  // Update password (for new account creation)
  Future<UserResponse> updatePassword(String password) async {
    return await _supabase.auth.updateUser(
      UserAttributes(password: password),
    );
  }

  // Sign out
  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  // Get current user
  User? get currentUser => _supabase.auth.currentUser;
}

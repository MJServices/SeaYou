import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sf;
import 'package:supabase/supabase.dart';

/// Tracks loading, error and current user for Facebook auth actions.
class FacebookAuthState {
  final bool isLoading;
  final String? errorMessage;
  final User? user;

  const FacebookAuthState({
    this.isLoading = false,
    this.errorMessage,
    this.user,
  });

  FacebookAuthState copyWith(
      {bool? isLoading, String? errorMessage, User? user}) {
    return FacebookAuthState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      user: user ?? this.user,
    );
  }
}

/// Handles Facebook sign-in and account linking without interfering with existing flows.
///
/// Notes:
/// - Facebook does not issue OpenID Connect ID tokens; Supabase sign-in uses OAuth.
/// - Session events are delivered via `auth.onAuthStateChange` and reflected in `state`.
class FacebookAuthService {
  final sf.SupabaseClient _supabase;
  final FacebookAuth _facebookAuth;
  final ValueNotifier<FacebookAuthState> state =
      ValueNotifier(const FacebookAuthState());
  StreamSubscription<AuthState>? _authSub;

  FacebookAuthService({sf.SupabaseClient? supabase, FacebookAuth? facebookAuth})
      : _supabase = supabase ?? sf.Supabase.instance.client,
        _facebookAuth = facebookAuth ?? FacebookAuth.instance {
    _authSub = _supabase.auth.onAuthStateChange.listen((event) {
      final sessionUser = event.session?.user;
      state.value = state.value
          .copyWith(isLoading: false, errorMessage: null, user: sessionUser);
    });
  }

  /// Starts Facebook login and signs in to Supabase via OAuth.
  ///
  /// Provide `redirectTo` with an app URL scheme configured in iOS and Android
  /// so Supabase can redirect back to the app after the OAuth flow.
  Future<bool> signInWithFacebook({String? redirectTo}) async {
    try {
      state.value = state.value.copyWith(isLoading: true, errorMessage: null);

      // Facebook does not provide an ID token; use Supabase OAuth flow.
      debugPrint('Launching Facebook OAuth...');
      final launched = await _supabase.auth.signInWithOAuth(
        sf.OAuthProvider.facebook,
        redirectTo: redirectTo,
      );
      debugPrint('Facebook OAuth launched: $launched');

      if (!launched) {
        state.value = state.value.copyWith(
            isLoading: false, errorMessage: 'Unable to launch Facebook OAuth');
      } else {
        final user = await waitForAuthResult(const Duration(seconds: 60));
        if (user == null) {
          state.value = state.value.copyWith(
            isLoading: false,
            errorMessage:
                'Facebook login did not complete. Check app status and configuration.',
          );
        }
      }

      return launched;
    } catch (e) {
      state.value =
          state.value.copyWith(isLoading: false, errorMessage: e.toString());
      rethrow;
    }
  }

  Future<sf.User?> waitForAuthResult(Duration timeout) async {
    final completer = Completer<sf.User?>();
    final sub = _supabase.auth.onAuthStateChange.listen((event) {
      final u = event.session?.user;
      if (u != null && !completer.isCompleted) completer.complete(u);
    });
    try {
      final user = await completer.future.timeout(timeout, onTimeout: () {
        return null;
      });
      return user;
    } finally {
      await sub.cancel();
    }
  }

  /// Links the current Supabase user with a Facebook identity.
  ///
  /// Requires the user to be authenticated. Uses Supabase OAuth linking flow.
  Future<void> linkWithFacebook({String? redirectTo}) async {
    try {
      state.value = state.value.copyWith(isLoading: true, errorMessage: null);
      await _supabase.auth
          .linkIdentity(sf.OAuthProvider.facebook, redirectTo: redirectTo);
      state.value = state.value.copyWith(isLoading: false);
    } catch (e) {
      state.value =
          state.value.copyWith(isLoading: false, errorMessage: e.toString());
      rethrow;
    }
  }

  /// Logs out from Facebook SDK (does not affect Supabase session).
  Future<void> revokeFacebook() async {
    try {
      await _facebookAuth.logOut();
    } catch (_) {}
  }

  /// Signs out from Supabase and revokes Facebook SDK session.
  Future<void> signOutAll() async {
    try {
      state.value = state.value.copyWith(isLoading: true);
      await revokeFacebook();
      await _supabase.auth.signOut();
      state.value = state.value.copyWith(isLoading: false, user: null);
    } catch (e) {
      state.value =
          state.value.copyWith(isLoading: false, errorMessage: e.toString());
      rethrow;
    }
  }

  void dispose() {
    _authSub?.cancel();
    state.dispose();
  }
}

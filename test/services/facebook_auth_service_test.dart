import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sf;
import 'package:supabase/supabase.dart';
import 'package:seayou_app/services/facebook_auth_service.dart';

class MockSupabaseClient extends Mock implements sf.SupabaseClient {}
class MockGotrueClient extends Mock implements sf.GoTrueClient {}
class MockFacebookAuth extends Mock implements FacebookAuth {}

void main() {
  late MockSupabaseClient supabase;
  late MockGotrueClient auth;
  late MockFacebookAuth fb;
  late StreamController<AuthState> authController;

  setUp(() {
    supabase = MockSupabaseClient();
    auth = MockGotrueClient();
    fb = MockFacebookAuth();
    authController = StreamController<AuthState>.broadcast();

    when(() => supabase.auth).thenReturn(auth);
    when(() => auth.onAuthStateChange).thenAnswer((_) => authController.stream);
  });

  tearDown(() async {
    await authController.close();
  });

  test('Successful Facebook OAuth updates state with user', () async {
    when(() => auth.signInWithOAuth(sf.OAuthProvider.facebook, redirectTo: any(named: 'redirectTo'))).thenAnswer((_) async => true);

    final service = FacebookAuthService(supabase: supabase, facebookAuth: fb);

    expect(service.state.value.user, isNull);
    await service.signInWithFacebook(redirectTo: 'io.supabase.flutter://login-callback/');

    // simulate Supabase providing a session
    final session = sf.Session.fromJson({
      'access_token': 'a',
      'token_type': 'bearer',
      'user': {
        'id': 'user-id',
        'email': 'user@example.com',
      },
    });
    authController.add(sf.AuthState(sf.AuthChangeEvent.signedIn, session));

    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(service.state.value.user?.id, equals('user-id'));
    expect(service.state.value.errorMessage, isNull);
  });

  test('Unable to launch OAuth sets error message', () async {
    when(() => auth.signInWithOAuth(sf.OAuthProvider.facebook, redirectTo: any(named: 'redirectTo'))).thenAnswer((_) async => false);

    final service = FacebookAuthService(supabase: supabase, facebookAuth: fb);

    final res = await service.signInWithFacebook();
    expect(res, isFalse);
    expect(service.state.value.errorMessage, equals('Unable to launch Facebook OAuth'));
  });

  test('Failed Facebook login surfaces message', () async {
    when(() => fb.login(permissions: any(named: 'permissions'))).thenAnswer((_) async => LoginResult(status: LoginStatus.failed, message: 'permission denied'));

    final service = FacebookAuthService(supabase: supabase, facebookAuth: fb);

    final res = await service.signInWithFacebook();
    expect(res, isFalse);
    expect(service.state.value.errorMessage, equals('permission denied'));
  });

  test('Network error during Supabase OAuth shows error', () async {
    when(() => auth.signInWithOAuth(sf.OAuthProvider.facebook, redirectTo: any(named: 'redirectTo'))).thenThrow(Exception('Network failure'));

    final service = FacebookAuthService(supabase: supabase, facebookAuth: fb);
    expectLater(() async => await service.signInWithFacebook(), throwsException);
    expect(service.state.value.errorMessage, isNotNull);
  });
}

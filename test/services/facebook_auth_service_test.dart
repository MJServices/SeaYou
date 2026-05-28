import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sf;
import 'package:supabase/supabase.dart';
import 'package:seayou_app/services/facebook_auth_service.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockSupabaseClient extends Mock implements sf.SupabaseClient {}
class MockGotrueClient extends Mock implements sf.GoTrueClient {}
class MockFacebookAuth extends Mock implements FacebookAuth {}
class MockUrlLauncherPlatform extends Mock with MockPlatformInterfaceMixin implements UrlLauncherPlatform {}

class FakeLaunchOptions extends Fake implements LaunchOptions {}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeLaunchOptions());
  });

  late MockSupabaseClient supabase;
  late MockGotrueClient auth;
  late MockFacebookAuth fb;
  late StreamController<AuthState> authController;

  setUp(() {
    supabase = MockSupabaseClient();
    auth = MockGotrueClient();
    fb = MockFacebookAuth();
    authController = StreamController<AuthState>.broadcast();
    
    final mockUrlLauncher = MockUrlLauncherPlatform();
    when(() => mockUrlLauncher.launchUrl(any(), any())).thenAnswer((_) async => true);
    UrlLauncherPlatform.instance = mockUrlLauncher;

    when(() => supabase.auth).thenReturn(auth);
    when(() => auth.onAuthStateChange).thenAnswer((_) => authController.stream);
  });

  tearDown(() async {
    await authController.close();
  });

  test('Successful Facebook OAuth updates state with user', () async {
    when(() => auth.getOAuthSignInUrl(provider: sf.OAuthProvider.facebook, redirectTo: any(named: 'redirectTo')))
        .thenAnswer((_) async => const sf.OAuthResponse(provider: sf.OAuthProvider.facebook, url: 'https://example.com'));

    final service = FacebookAuthService(supabase: supabase, facebookAuth: fb);

    expect(service.state.value.user, isNull);
    // don't await yet, it will block waiting for auth
    final futureRes = service.signInWithFacebook(redirectTo: 'io.supabase.flutter://login-callback/');

    // wait a tiny bit for the future to launch the OAuth
    await Future<void>.delayed(const Duration(milliseconds: 50));

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

    final res = await futureRes;
    expect(res, isTrue);

    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(service.state.value.user?.id, equals('user-id'));
    expect(service.state.value.errorMessage, isNull);
  });

  test('Unable to launch OAuth sets error message', () async {
    final mockUrlLauncher = MockUrlLauncherPlatform();
    when(() => mockUrlLauncher.launchUrl(any(), any())).thenAnswer((_) async => false);
    UrlLauncherPlatform.instance = mockUrlLauncher;

    when(() => auth.getOAuthSignInUrl(provider: sf.OAuthProvider.facebook, redirectTo: any(named: 'redirectTo')))
        .thenAnswer((_) async => const sf.OAuthResponse(provider: sf.OAuthProvider.facebook, url: 'https://example.com'));

    final service = FacebookAuthService(supabase: supabase, facebookAuth: fb);

    final res = await service.signInWithFacebook();
    expect(res, isFalse);
    expect(service.state.value.errorMessage, equals('Unable to launch Facebook OAuth'));
  });

  test('Network error during Supabase OAuth shows error', () async {
    when(() => auth.getOAuthSignInUrl(provider: sf.OAuthProvider.facebook, redirectTo: any(named: 'redirectTo'))).thenThrow(Exception('Network failure'));

    final service = FacebookAuthService(supabase: supabase, facebookAuth: fb);
    try {
      await service.signInWithFacebook();
      fail('Should have thrown');
    } catch (_) {}
    expect(service.state.value.errorMessage, isNotNull);
  });
}

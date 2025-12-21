# Facebook Authentication (Supabase + Flutter)

## Overview

Implements Facebook sign-in using the `flutter_facebook_auth` SDK, and Supabase OAuth for session creation. Facebook does not provide OpenID Connect ID tokens; Supabase session is established via `signInWithOAuth(Provider.facebook)`.

## Dependencies

```yaml
dependencies:
  supabase_flutter: ^2.10.3
  flutter_facebook_auth: ^6.0.0
dev_dependencies:
  mocktail: ^1.0.3
```

## Native Setup

Configure Facebook SDK credentials and URL schemes:

- iOS: add `FacebookAppID`, `FacebookDisplayName`, URL Types, and `LSApplicationQueriesSchemes` in `Info.plist`.
- Android: add `meta-data` for `com.facebook.sdk.ApplicationId` and client token, and set intent filters for your app scheme.

Supabase OAuth redirect should use an app URL scheme you control, e.g. `seayou://login-callback`.

## API Usage

```dart
final fbService = FacebookAuthService();

// Sign in
await fbService.signInWithFacebook(
  redirectTo: 'io.supabase.flutter://login-callback/',
);

// Observe state
fbService.state.addListener(() {
  final s = fbService.state.value;
  if (s.user != null) {
    // Authenticated
  }
  if (s.errorMessage != null) {
    // Show error
  }
});

// Link identity (user must be signed in)
await fbService.linkWithFacebook(
  redirectTo: 'io.supabase.flutter://login-callback/',
);

// Sign out & revoke Facebook
await fbService.signOutAll();
```

## UI Integration

Use `FacebookSignInButton` widget in your auth screens. It will update based on the service state and navigate on success:

```dart
FacebookSignInButton(
  redirectTo: 'seayou://login-callback',
  onSuccess: () => Navigator.pushReplacementNamed(context, '/home'),
)
```

## Error Handling

- Cancellation: `LoginStatus.cancelled` is surfaced as `errorMessage: 'Login cancelled'`.
- Permission denial: `LoginStatus.failed` message is surfaced.
- Network failures: exceptions during Supabase OAuth are caught and surfaced.

## Tests

Unit tests cover: success path, cancellation, failed login, and network errors using `mocktail`.

## References

- Supabase Dart: Sign in with ID token (Facebook uses OAuth, not ID tokens): https://supabase.com/docs/reference/dart/auth-signinwithidtoken
- Supabase Flutter: Auth guides and OAuth deep-linking: https://supabase.com/docs/guides/getting-started/tutorials/with-flutter

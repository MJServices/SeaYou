# Localization and Auth Enhancements (FR/DE/ES) with Email Branding

## Localization Infrastructure

1. Add Flutter localization support in `MaterialApp`:
   - Set `supportedLocales: [Locale('en'), Locale('fr'), Locale('de'), Locale('es')]`.
   - Add `localizationsDelegates: [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate, AppLocalizations.delegate]`.
   - Drive `locale` from a `LocalizationService` (ValueNotifier<Locale>). 

2. Create `lib/i18n/app_localizations.dart`:
   - Custom `LocalizationsDelegate` loading JSON from `assets/i18n/{lang}.json`.
   - Helper `tr(String key)` returning translated string with fallbacks.

3. Add translation files under `assets/i18n/`:
   - `en.json`, `fr.json`, `de.json`, `es.json`.
   - Include keys for all UI strings used across screens (home, auth, modals, buttons, errors). Example keys:
     - `home.ongoing_conversations`, `home.discover`, `home.secret_souls`, `home.door_of_desires`, `home.premium_cta`, `home.discovery_card_title`, `home.discovery_card_cta`, `home.conversation_list_header`.
     - `auth.sign_up`, `auth.log_in`, `auth.email`, `auth.password`, `auth.forgot_password`, `auth.send_code`, `auth.continue`, `auth.sign_in_title`, `auth.sign_in_description`, `auth.verification_title`, `auth.create_password_title`, `auth.password_requirements`.
     - Shared: `common.back`, `common.ok`, `common.cancel`.

4. Persistence & detection:
   - Add `LocalizationService` in `lib/services/localization_service.dart` with:
     - `SharedPreferences` storage key `preferred_locale` (e.g., `fr`, `de`, `es`).
     - On app launch: detect system locale via `PlatformDispatcher.instance.locale`; if stored preference exists, override; else default to system (fallback to `en` if unsupported).
     - Expose `setLocale(Locale l)` to update `ValueNotifier` and persist.
   - Wire `MaterialApp.builder` to rebuild on locale changes.

5. Language change UX:
   - Update `LanguageSelectionScreen` to use `LocalizationService`:
     - Default option shows system language.
     - On selection, call `setLocale(Locale('fr'|'de'|'es'|'en'))` and push to next screen.
     - Immediately reflect new language across all screens (no restart).

## Homepage French Content

1. Replace hardcoded strings in `lib/screens/home_screen.dart` with `tr()` keys:
   - Tiles: `home.ongoing_conversations` → "Conversations en cours"; `home.secret_souls` → "Les âmes secrètes"; `home.door_of_desires` → "La porte des désirs"; tile actions, badges, microcopy via keys.
   - Discovery card: title → "3 nouveaux messages" (`home.discovery_card_title`), CTA → "Découvrir" (`home.discovery_card_cta`).
   - Premium banner: `home.premium_cta` → "DÉCOUVRIR SEAYOU PREMIUM".
   - Conversation list header: `home.conversation_list_header` → "Vous avez {count} conversations"; include parameter interpolation.
   - Ensure all strings use proper Unicode diacritics; JSON UTF‑8 encoded.

2. Verify arrow indicator and visuals remain unchanged.

## Authentication UX Changes

1. Launch (onboarding) modifications:
   - Add a `Log in` button adjacent to existing `Sign up for free` on the onboarding/start screen (after language selection or on the first auth page):
     - Both buttons use `CustomButton` and share style.
     - Respect spacing & hierarchy; place them side‑by‑side or stacked with equal visual weight.
     - Strings via `auth.sign_up` and `auth.log_in` keys.

2. Login flow enhancements:
   - Extend `SignInEmailPasswordScreen` to support two modes:
     - Mode A: Email + Password (returning users) → calls `AuthService.signInWithPassword(...)`.
     - Mode B: Email only (OTP) remains available; toggle via a tab or segmented control labeled `auth.login_with_password` / `auth.login_with_code`.
   - Add `Forgot password` screen & flow:
     - New `ForgotPasswordScreen` to capture email and send reset link: `Supabase.auth.resetPasswordForEmail(...)` with redirect to an in‑app deep link if configured.
     - Provide UI to set new password via existing `CreatePasswordScreen` triggered after reset link/OTP verification.
   - Keep OTP verification exclusively for sign‑up flows (`AuthService.signUpWithEmail(...)` then `VerificationScreen` → `CreatePasswordScreen`).

3. Seamless transitions:
   - From onboarding, user picks `Log in` → choose password or code; from sign‑up → continue existing OTP → set password.
   - Navigation uses existing modals/screens for consistency.

## Email Customization (Supabase)

1. Sender and domain:
   - Configure Supabase Auth SMTP settings to use a verified `@seayou` domain (DKIM/SPF setup).
   - Set sender name to "SeaYou" in SMTP configuration.

2. Templates:
   - In Supabase Dashboard → Authentication → Email Templates:
     - Replace all templates (Confirmation, Magic Link/OTP, Recovery) with SeaYou‑branded HTML.
     - Remove Supabase branding; include SeaYou logo and color scheme.
     - Provide French versions and optionally DE/ES variants; detect locale from user preference and send corresponding template (via separate project or dynamic template selection if supported; otherwise maintain French default for FR locale users).

3. App configuration:
   - Update any `emailRedirectTo`/deep‑link settings to point to SeaYou app scheme for password recovery.

## Technical Implementation

1. Packages:
   - Add `flutter_localizations` and `shared_preferences` to `pubspec.yaml` (no heavy i18n libs to keep control).

2. App wiring:
   - In `lib/main.dart`:
     - Initialize `LocalizationService` before `runApp()`.
     - Set `locale` and `supportedLocales` on `MaterialApp`.
     - Keep global mute overlay via `builder` (already implemented).

3. Screen updates:
   - Replace string literals with `tr('...')` calls in:
     - `home_screen.dart`, `splash_screen.dart` subtitle, `create_account_screen.dart`, `sign_in_email_password_screen.dart`, `verification_screen.dart`, `create_password_screen.dart`, `profile_info_screen.dart`, and shared widgets.
   - Ensure every button label, hint text, error message goes through localization.

4. QA checklist:
   - Cold start: detect device locale; verify French is applied when device locale is fr.
   - Toggle language to FR/DE/ES and ensure immediate UI updates without restart.
   - Homepage: all specified modules and CTAs display in French with correct diacritics.
   - Auth: login with password works; recovery flow works; sign‑up OTP remains for new users.
   - Emails: verify sender shows "SeaYou", branding removed, and French content used.

## Deliverables

- `lib/i18n/app_localizations.dart`, `lib/services/localization_service.dart`.
- `assets/i18n/{en,fr,de,es}.json` with comprehensive keys.
- MaterialApp localization wiring.
- Updated screens using `tr()`.
- New `ForgotPasswordScreen` and updated Sign‑in screen modes.
- Supabase dashboard configuration doc for email branding.

If this plan looks good, I’ll implement the localization service and files, wire MaterialApp, translate the homepage/auth strings, update onboarding with a Log in button, add password login + recovery, and provide the email template assets and configuration steps.
## Overview
- Add two premium experiences: Secret Souls (anonymous photo gallery) and Chamber of Secrets (anonymized fantasies feed).
- Enforce consent, anonymity, and subscription tiers (free → premium → elite). No direct contact from Secret Souls; optional elite-only anonymous DM for fantasies.

## Data Model (Supabase)
1. Profiles & Photos
- `profiles`: add `tier ENUM('free','premium','elite') DEFAULT 'free'`, keep `face_photo_url` for 100% Feeling reveal.
- `profile_photos`: `id, user_id, url, is_face BOOLEAN, show_in_secret_souls BOOLEAN DEFAULT false, created_at`.
- Rationale: manage multiple photos and per-photo gallery visibility.

2. Consent & Preferences
- `user_preferences`: add `show_in_secret_souls BOOLEAN DEFAULT false` (user-level opt-in), keep `consent_photo_reveal` for private 100% feeling reveal.
- Gallery visibility rule: requires `user_preferences.show_in_secret_souls = true` AND per-photo `show_in_secret_souls = true`.

3. Fantasies
- `fantasies`: `id, user_id, text, is_active BOOLEAN DEFAULT true, visibility ENUM('global','friends','none') DEFAULT 'global', created_at`.
- `fantasy_reports`: moderation: `id, fantasy_id, reporter_id, reason, created_at`.
- Indexes: `(created_at DESC)`, `(is_active)`, `(user_id)`.

4. Anonymous Elite DM (Fantasies)
- `conversations`: add `is_anonymous_elite BOOLEAN DEFAULT false, fantasy_id UUID NULL`.
- Pseudonyms: extend `conversations` with `mask_a TEXT, mask_b TEXT` (system-generated handles).
- RLS: enforce participants can only see messages of their conversations; prohibit fetching counterpart profiles when `is_anonymous_elite = true`.

## Storage & Security
- Buckets: `avatars` (public), `face_photos` (private, signed URL on reveal), `gallery_photos` (public but only show via consent flags).
- Strip EXIF on upload; standardize to 1080px, JPEG/WebP; background job for cleanup.
- RLS policies:
  - `profile_photos`: only owners can insert/update; read allowed where `show_in_secret_souls = true` and owner tier ≥ premium.
  - `fantasies`: anyone can read `is_active=true`; insert by authenticated; update/delete only by owner or moderator.
  - `conversations/messages`: standard 2-party RLS; if `is_anonymous_elite=true`, block any joins to `profiles` via PostgREST.

## Subscription & Gating
- `profiles.tier` controls access: premium: can view Secret Souls & Chamber of Secrets; elite: can send anonymous fantasy DMs.
- Add server checks in RPC or policies (e.g., `WITH CHECK` on selects for tiers).
- Non-premium bubble copy: shows CTA to subscribe.

## Services (Flutter)
- `DatabaseService` additions:
  - Photos: `getSecretSoulsPhotos(page, pageSize)`, `setPhotoGalleryVisibility(photoId, visible)`, `uploadGalleryPhoto(file)`, `uploadFacePhoto(file)`.
  - Fantasies: `createFantasy(text)`, `listFantasies(page, pageSize)`, `reportFantasy(...)`.
  - Elite DM: `startAnonymousFantasyConversation(fantasyId)`, `sendMessageAnonymous(conversationId, ...)`.
  - Tier: `getUserTier()`, `upgradeTier(tier)` (stub for payments provider integration).

## UI Implementation
1. Secret Souls (Premium Gallery)
- New `SecretSoulsGalleryScreen`: grid of consented photos, infinite scroll, tap → fullscreen viewer (no profile metadata, no contact controls).
- Profile photo management: in `ProfileScreen`, add per-photo toggle “Show in Secret Souls”.
- Home tile taps route to gating modal if tier < premium, otherwise open `SecretSoulsGalleryScreen`.

2. Chamber of Secrets (Fantasies)
- New `ChamberOfSecretsScreen`: list of random fantasies with minimal metadata (time ago), no names or avatars.
- Non-premium gating bubble on entry; premium can read; elite sees “Message anonymously” button → creates `is_anonymous_elite` conversation with pseudonyms.
- Registration: add mandatory “Your fantasy” step (single free-text field) after `interests_screen.dart`, persisted to `fantasies`.

## Anonymity Controls
- Secret Souls: no profile names, no contact buttons, watermark “SeaYou” overlay to discourage reuse.
- Fantasies: show only pseudonyms during elite DM; block media attachments if needed; ensure no profile links.

## Seeding Synthetic Profiles/Fantasies
- Admin-only script (Edge Function or SQL seed) to insert:
  - `profile_photos` with stock assets tagged as synthetic.
  - `fantasies` with curated texts.
- Add `is_synthetic BOOLEAN` for moderation filters.

## Moderation & Safety
- Report/Hide: add “Report” for fantasies; flagging hides `is_active=false`.
- Rate limit fantasy creation; anti-spam checks (min length, no PII/links).
- Optional content moderation API for uploads and texts.

## i18n
- Add keys for gallery toggles, gating bubbles, fantasies UI, elite DM CTA.

## Rollout Plan
1. Migrations and RLS policies.
2. Services: uploads, queries, toggles.
3. UI screens and routing; gating wired to `profiles.tier`.
4. Registration fantasy step and validation.
5. Seeding for launch; QA on anonymity and permissions.

## Validation
- Unit tests for service methods.
- Manual QA with two test accounts (free/premium/elite) to verify gating and anonymity.
- Storage access checks (public vs signed URLs).

Please confirm this plan. Once approved, I will implement migrations, services, UI screens, gating modals, and registration updates accordingly.
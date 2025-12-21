## Premium Gating System
- Add centralized gating helper (`EntitlementsService`) that exposes: `isPremium(userId)`, `isElite(userId)`, `requirePremium(context, feature)`, `requireElite(context, feature)`.
- Wire gating in UI:
  - Secret Souls: wrap navigation with `requirePremium` and show info bubbles with CTA.
  - Chamber of Secrets: gate the screen for non‑premium with upsell, keep elite extras behind `requireElite`.
- i18n: add strings for benefits, CTAs, and tier explanations; reuse existing `premium.gate` keys.

## Elite Tier: Anonymous DM
- Conversations: use flags for elite anonymity (`is_anonymous_elite`, `mask_a`, `mask_b`).
- Service API:
  - `startAnonymousConversation(targetUserId|fantasyId)` → creates conversation with masking applied.
  - Identity masking: generate pseudonyms and hide avatars/display names in UI; never expose real `sender_id` in UI for the masked side.
- Privacy safeguards:
  - Prevent profile queries resolving real identity for masked conversations.
  - Audit logs server‑side (Edge Function) for abuse detection without exposing identity to clients.

## Backend Data Model Updates (Supabase)
### Conversations
- Ensure columns:
  - `title` (rename support), `feeling_percent`, `unlock_state`, `exchanges_count`, `last_sender_id`, `is_anonymous_elite`, `mask_a`, `mask_b`, optional `fantasy_id`.
- Add policies:
  - RLS: participants only (user_a_id=user OR user_b_id=user), restrict updates to title and client‑safe fields.
- Add trigger functions:
  - Recompute `feeling_percent` on message insert; update `unlock_state` thresholds (25/50/75/100).

### Messages
- Columns: `type`, `text`, `media_url`, `qa_group_id` (for question/answer pairing), `is_question`, `is_answer`, `feeling_delta`.
- Logic:
  - On insert, derive complete exchange counts; update `conversations.exchanges_count` and `feeling_percent`.

### Photos (profile_photos)
- Columns:
  - `is_first_face_photo` (bool), `is_visible_in_secret_souls` (bool), `is_hidden` (bool), `ai_face_score` (numeric CHECK 0..100).
- Validation:
  - Constraint: `ai_face_score BETWEEN 0 AND 100`.
- RLS:
  - Owner RW, public read (only when `is_visible_in_secret_souls` is true).

### Fantasies
- Columns: `text`, `user_id`, `is_active`, `is_anonymous_submission` (bool).
- RLS:
  - Anyone can read active fantasies; only owners can modify; gating checks in services for premium visibility.

## Subscription Management
- Entitlements table:
  - `entitlements (user_id uuid pk, tier text CHECK ('free','premium','elite'), source text, expires_at timestamptz, updated_at)`.
- Sync paths:
  - Stripe Webhooks (Edge Function) → upsert `entitlements`, set tier; fallback admin panel for manual changes.
  - Client reads `profiles.tier` and `entitlements` for redundancy; primary gate: `entitlements.tier`.
- Edge Function:
  - `subscriptions/index.ts`: handle `checkout.session.completed`, `customer.subscription.updated/deleted`, map products to `premium`/`elite`, update `expires_at`.
- Client logic:
  - `EntitlementsService.refresh()` pulls `entitlements` and caches in `shared_preferences` for offline gates.
  - Handle expirations/upgrades/downgrades; emit events to update UI.

## Email System
- Branded templates:
  - Welcome to Premium, Upgrade to Elite, Expiration warning, Feature tips.
- Infrastructure:
  - Use Supabase Functions + Resend/SendGrid; store `email_events` table for tracking (sent, delivered, opened).
- Templating:
  - HTML templates with inlined styles; variables: `user_name`, `tier`, `cta_url`.

## Security Controls
- RLS everywhere: messages, conversations, profile_photos, fantasies, entitlements.
- Do not trust client tier; server enforces via policies.
- Masked conversations: never return real names/avatars for masked side; include pseudonyms in views.
- Input validation: title rename length, `ai_face_score` bounds, message types.

## App Integration (Client)
- Services:
  - `EntitlementsService` (read entitlements, cache, notify).
  - `ConversationService` (rename, feeling progress, unlocks, anon start).
  - `MessageService` (insert, subscribe, QA pairing, feeling progress updates).
  - `PhotoService` (flags set/get, face score write via admin/ML pipeline).
- UI:
  - Secret Souls: gate + gallery filtered by `is_visible_in_secret_souls`.
  - Chamber of Secrets: gate + elite DM button with masked identity.
  - FeelingProgress: show milestones (25/50/75/100) based on `conversations.unlock_state`.

## Testing
- Unit tests:
  - Entitlements gating scenarios: free/premium/elite, expiration.
  - Conversation rename, unlock state transitions, feeling progress math.
  - Messages QA pairing and exchange completion.
  - Photo flags and validation.
- Integration tests:
  - Mock entitlement changes and verify UI gates.
  - Anonymous DM flow: mask shown, RLS prevents leakage.
- Edge Function tests:
  - Stripe webhook payloads for trial, renewal, cancel; idempotent upsert.

## Migration Tasks
- SQL migrations to add/alter tables/columns and constraints; create RLS policies and triggers.
- Backfill `entitlements` from existing `profiles.tier`.
- Seed i18n strings for new bubbles and emails.

## Rollout & Observability
- Feature flags for elite DM rollout.
- Logs and metrics in Functions; error alerts for webhook failures.
- Admin screen to manually set entitlements for support.

## References in Current Codebase
- Chamber of Secrets screen present (`lib/screens/chamber_of_secrets_screen.dart`), UI hooks for elite DM.
- Database service stubs for conversations/messages/photos/fantasies.
- Existing i18n keys for premium gating; extend for new flows.

Confirm to proceed and I will implement migrations, services, UI gates, and tests in increments, validating each step with analyzer and test runs.
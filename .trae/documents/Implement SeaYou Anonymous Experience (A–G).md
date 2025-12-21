## Overview
- Deliver A–G with minimal friction by extending existing services and triggers while keeping UX anonymous-first. Below, each requirement maps to concrete UI, service, and DB work with references to current code.

## A. Tutorial Bubbles
- Centralize in `TutorialService` (`lib/services/tutorial_service.dart`) with new keys: `seen_signup_coachmark`, `seen_quote_tip`, `seen_audio_tip`, `seen_premium_gate_tip`.
- Create reusable `CoachmarkBubble` widget for non-modal tips (accessible, focusable), and keep `AlertDialog` for blocking walkthroughs. Hook points:
  - After sign-up: show intro bubble from `HomeScreen.initState` (lib/screens/home_screen.dart:59–95) using new keys and coachmark widget.
  - First interactions: on quote/audio/photo screens, gate via post-frame callbacks similar to photo tooltip pattern.
  - Premium-only areas: show explainer bubble on Secret Souls and Chamber entry when `EntitlementsService.isPremium/isElite` fails.
- i18n: add `tutorial.*` and `tooltip.*` keys in `assets/i18n/en.json`/`fr.json`; ensure `Semantics` labels and keyboard navigation.

## B. Feeling‑Based Progression
- Server: keep `conversations.feeling_percent` and `unlock_state` trigger updates (supabase/migrations/20251203203000_update_feeling_logic.sql). Confirm Q/A pairing via `qa_group_id` and sender symmetry.
- Client: render `FeelingProgress` milestones (25/50/75/100) with unlock banners in chat and home (`lib/widgets/feeling_progress.dart`, `lib/screens/chat/chat_conversation_screen.dart`).
- Unlock gates: at thresholds, enable UI for secret quote (25%), voice (50%), sexy questions (75%), reveal request (100%). Enforce disabled actions until threshold is met.

## C. Premium & Elite Differentiations
- Use `EntitlementsService.isPremium/isElite` (`lib/services/entitlements_service.dart`) to gate:
  - Secret Souls tile in Home (`lib/screens/home_screen.dart:1068–1186`) → premium-only bubble; proceed when tier not `free`.
  - Chamber of Secrets (`lib/screens/chamber_of_secrets_screen.dart`) → premium bubble; elite-only anonymous DM actions.
- Ensure navigation returns to Home and preserves counters/state as implemented.

## D. Anonymous‑First Profile System
- Mandatory but hidden face photo: require first face photo capture during registration; store in `profile_photos` with `is_face=true`, `is_first_face_photo=true`, `ai_face_score`.
- Secret quote/audio: add onboarding steps for quote and 10–30s voice; store as message types (`quote`, `voice`) visible only after thresholds.
- Optional photos: allow gallery photos with `is_face=false`; visibility flags `is_visible_in_secret_souls`, `is_hidden` already present.
- RLS: ensure hidden face cannot be publicly queried; expose only at reveal with consent flags.

## E. Conversation System
- Named conversations: keep `title` and `feeling_percent` subscription via `FeelingController` (`lib/services/feeling_controller.dart`); UI shows name and `FeelingProgress` (home list `lib/screens/home_screen.dart:1356–1459`).
- Unlockable features: bind composer/toolbars to `unlock_state` and show contextual banners; maintain anonymous masks for elite DMs in Chamber (`is_anonymous_elite`, `mask_a/b`).

## F. Special Interaction at 75%
- Modal with sexy questions (already present patterns) in chat; enforce mandatory answer before continuing by disabling inputs until at least one answer is submitted.
- Server: couple `sendAnswer` with `qa_group_id` validation; trigger increments `feeling_percent` only on paired answers.
- i18n: ensure `surprise.*` keys exist and are localized.

## G. Controlled Reveals at 100%
- Mutual 100% required: both sides must be `unlock_state=4` and consent via `user_preferences.consent_photo_reveal`.
- Flow: user initiates reveal request; other accepts; only then reveal `profiles.face_photo_url` in conversation context. Allow skip by user choice.
- Logging: audit reveal events; add revoke option if desired.

## Backend & RPC Additions
- Outbox: already implemented (`process_outbox_one`/`process_outbox` in supabase/migrations/20251203201500_process_outbox.sql, used in `DatabaseService.triggerMatching`).
- Face‑verify function: add Supabase Edge Function `face_verify` to score uploaded face photo, update `ai_face_score`; enforce threshold 75 before allowing `is_first_face_photo=true`.
- Triggers:
  - Photo limit enforcement and friendly errors on client.
  - Conversation updates: keep `fn_update_conversation_on_message` with Q/A checks; ensure `unlock_state` transitions.

## Accessibility & Performance
- Semantics: labels/roles on all tutorial bubbles, sliders, dropdowns, tiles; keyboard focus order.
- Contrast and tap targets ≥44px; responsive layout uses current max width constraints.
- Performance: debounce sliders, lazy load grids/lists, use `CachedNetworkImage` for gallery; skeletons while loading.

## Testing
- Unit: validations (outbox form, ranges), entitlements gating, feeling math for Q/A pairs, photo flags.
- Integration: anonymous send → queue → RPC matching → inbox; Secret Souls gating/visibility toggles; Chamber pagination + elite DM.
- UAT: end‑to‑end anonymous experience, registration steps with face‑verify pass/fail, premium vs free flows.

## Documentation
- Update `docs/verification.md` with new pages/flows; add usage docs for `process_outbox_*` and `face_verify`; record accessibility/performance standards.

## Notes on Current Code
- Matching RPC is present (`supabase/migrations/20251203201500_process_outbox.sql:2–44,47–60`), and client calls exist in `lib/services/database_service.dart:595–651` and compose screen `lib/screens/outbox_compose_screen.dart:69–90`.
- Entitlements gating exists on Home and Chamber; we will reuse and extend it.
- FeelingProgress and related triggers/controllers exist; plan leverages them for A–G.

Please confirm this plan; once approved, I’ll implement step‑by‑step with tests and docs.
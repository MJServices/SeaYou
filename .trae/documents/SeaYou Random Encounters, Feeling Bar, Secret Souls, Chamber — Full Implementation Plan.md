## Overview

* Implement random anonymous messaging with recipient filtering (distance, gender, age) and automatic matching.

* Enforce conversation “Feeling” progress based on complete Q/A exchanges, with unlockable features at 25/50/75/100.

* Add AI-verified face photo at registration, photo limits, and Secret Souls gallery with anonymity options and premium gating.

* Build Chamber of Secrets with anonymous fantasy submissions and elite anonymous DM.

## Current Code Context

* Feeling UI exists (`lib/widgets/feeling_progress.dart`) and is shown on Home (`lib/screens/home_screen.dart:1389–1393`).

* Messages and conversations services exist (`lib/services/database_service.dart:530–589`, `:590–613`).

* Premium gating UI exists for Secret Souls and Chamber (`lib/screens/home_screen.dart:1066–1166`).

* Chamber screen exists with fantasy list and elite DM stub (`lib/screens/chamber_of_secrets_screen.dart:120–147`).

## Data Model (Supabase, Postgres)

1. Users/Profiles

* profiles: add `gender text`, `birth_year int`, `city text`, `lat numeric`, `lng numeric`.

* Maintain `tier` for free/premium/elite.

1. Matching

* messages\_outbox: store anonymous messages to be matched

  * id, sender\_id, text, filters (min\_age, max\_age, max\_distance\_km, gender), created\_at

* matches: store recipient assignments

  * id, outbox\_id, recipient\_id, assigned\_at, delivered\_at

1. Conversations

* Ensure columns present: `title`, `feeling_percent int`, `unlock_state int`, `exchanges_count int`, `last_sender_id`, `user_a_id`, `user_b_id`, `is_anonymous_elite`, `mask_a`, `mask_b`, `fantasy_id`.

1. Messages

* Columns for Q/A:

  * `qa_group_id uuid`, `is_question boolean`, `is_answer boolean`, `feeling_delta int` (already extended)

* Maintain `type text` (text/voice/photo/quote)

1. Photos (profile\_photos)

* Flags:

  * `is_first_face_photo boolean`, `is_visible_in_secret_souls boolean`, `is_hidden boolean`, `ai_face_score numeric check 0..100` (already extended)

* Limit total photos per user to 6 via policy or function.

1. Fantasies

* Add `is_anonymous_submission boolean default true`; link to conversations via `fantasy_id` (already present).

1. Entitlements

* `entitlements (user_id, tier, source, expires_at, updated_at)` (added).

## Backend Logic

1. Random Matching Job (Edge Function)

* `functions/random-matching/index.ts`:

  * Fetch new `messages_outbox` rows.

  * For each, compute candidate recipients:

    * Filter by age: `birth_year` within `min_age/max_age` relative to current year.

    * Filter by gender.

    * Filter by distance using Haversine between `(lat,lng)`.

  * Select random N recipients (e.g., 20) and insert into `matches`.

  * Deliver by inserting a `messages` row per recipient in conversation (create conversation lazily when recipient replies).

1. Conversation Progress Trigger (Server)

* Pl/pgSQL trigger (`fn_update_conversation_on_message`) already set to update exchanges and feeling; extend to only increment when both `is_question` and a subsequent `is_answer` exist for same `qa_group_id`.

* Unlock mapping:

  * `unlock_state`: 1 for 25%, 2 for 50%, 3 for 75%, 4 for 100%.

1. First Face Photo Verification

* `functions/face-verify/index.ts`:

  * Accept uploaded image URL, call Face API (e.g., AWS Rekognition or Google Vision) to get face confidence score.

  * Store result in `profile_photos.ai_face_score` and set `is_first_face_photo=true`.

  * Reject by returning error when score < threshold; client shows message.

1. Photo Count Enforcement

* DB policy or function: before insert into `profile_photos`, ensure count < 6 for user.

1. Secret Souls Gallery

* Query `profile_photos` where `is_visible_in_secret_souls=true` and `is_hidden=false`.

* Add ability to toggle `is_visible_in_secret_souls` and `is_hidden` per photo.

1. Chamber of Secrets

* Fantasies are listed randomised (order by `random()` with pagination).

* Elite DM starter: already present; keep masked identities.

## Client Implementation

1. Registration Flow (New Screen Group)

* Add mandatory steps:

  * Quote: text input saved as user preference.

  * Voice: record 10–30s; upload to storage.

  * First face photo: capture/upload; call face-verify function; threshold (e.g., 75/100) must pass.

  * Fantasy: text; stored in `fantasies`.

* Enforce completion before home.

1. Anonymous Message Send (New UI action)

* Compose text and set filters (age range, gender, distance slider).

* Submit to `messages_outbox`; background job assigns recipients.

* When recipient replies, create conversation and show feeling bar; usernames visible.

1. Feeling Bar (UI)

* Existing `FeelingProgress` extended to show 10% increments, with labels and milestones (25 Quote, 50 Voice, 75 Surprise, 100 Photo).

* Disable gated actions until unlock state reached; show tooltips.

1. Conversation Q/A

* Sending a question sets `is_question=true` and `qa_group_id`.

* Reply sets `is_answer=true` with same `qa_group_id`.

* Feeling increments only for completed Q/A.

1. Secret Souls

* Tile on Home triggers gate for free users.

* Premium users browse grid of anonymous photos; toggle visibility/hide on own photos.

1. Chamber of Secrets

* Free users see info bubble.

* Premium users view anonymized fantasies and start elite anonymous DM if tier==elite.

## Subscription & Gating

* Use `EntitlementsService` to determine `premium`/`elite`.

* UI gates call `isPremium`/`isElite`.

* Backend entitlements kept in sync by Stripe webhook (`functions/subscriptions`).

## Security & RLS

* RLS: participants-only read on conversations/messages.

* profile\_photos: owner RW; public read only when `is_visible_in_secret_souls=true and is_hidden=false`.

* fantasies: public read of `is_active=true`; write owned.

* entitlements: per-user read; updates via webhook (service role).

## Testing

* Unit tests:

  * Feeling progress calculation for Q/A pairs.

  * Photo flag toggles and AI score validation.

  * Entitlements mapping gates for free/premium/elite.

* Integration tests:

  * Anonymous message send → match assignment → recipient replies → conversation created and feeling increments.

* Edge tests:

  * Stripe webhook mapping to tiers; idempotency.

  * Face verify threshold boundary cases.

## Rollout Plan

* Phase 1: Data migrations, face verify function, Secret Souls gating.

* Phase 2: Anonymous outbox & random matching job; conversation Q/A; feeling bar milestones.

* Phase 3: Chamber: fantasies and elite DM; subscription webhooks.

* Phase 4: Registration mandatory steps; photo limits; observability and fine-tuning.

## Observability

* Log to Functions for matching runs, webhook events, and face verification outcomes.

* Add admin dashboard queries for entitlements and photo moderation.

## Notes

* Use existing `DatabaseService` patterns for CRUD.

* Keep deep links and OAuth unchanged; subscription requires Stripe keys configured in environment.

* AI verification threshold to be set by customer (e.g., 75).


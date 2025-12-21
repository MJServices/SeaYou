## Data Model (Server)
1. Create `conversations` table (Supabase, RLS enabled):
   - Fields: `id`, `user_a_id`, `user_b_id`, `title`, `exchanges_count` (int), `feeling_percent` (int, 0–100), `exchange_open` (bool), `last_sender_id`, `unlock_state` (jsonb), `created_at`, `updated_at`.
   - RLS: only `user_a_id` or `user_b_id` can select/insert/update.
2. Create `messages` table:
   - Fields: `id`, `conversation_id`, `sender_id`, `type` (`text|voice|image|quote|surprise`), `text`, `media_url`, `created_at`.
   - RLS: only participants can insert/select; updates disabled.
3. Extend `profiles` or `user_preferences` for preconfigured features:
   - Add flags: `has_quote_feature`, `has_voice_feature`, `consent_photo_reveal` and optional `face_photo_url`.
4. Trigger/functions (Postgres):
   - `fn_update_feeling_on_message(conversation_id, sender_id)`:
     - If `last_sender_id` is null: set `last_sender_id=sender_id`, `exchange_open=true`.
     - Else if `last_sender_id != sender_id` and `exchange_open=true`: increment `exchanges_count` by 1 and set `exchange_open=false` (completed exchange).
     - Else set `exchange_open=true` (awaiting reply).
     - `feeling_percent = LEAST(100, exchanges_count * 10)`.
     - Update `unlock_state` based on thresholds (25/50/75/100) and user preconfig flags.
     - At 100%: set `unlock_state.photo_reveal_unlocked = (consent_photo_reveal of both participants AND both `face_photo_url` present)`.
   - AFTER INSERT trigger on `messages` calls the function and updates `conversations`.
5. Realtime: enable Supabase Realtime on `conversations` row updates.

## Progress Rules
- Strict 10% steps: `feeling_percent = exchanges_count * 10`.
- Only completed exchanges (message by A followed by reply by B) advance.
- One‑sided messages do not advance (enforced in trigger).

## Unlockable Features
- 25%: Quote feature visible only if `has_quote_feature=true` in user settings.
- 50%: Voice message enabled only if `has_voice_feature=true`.
- 75%: Surprise feature (intimate questions) visible/enabled.
- 100%: Photo reveal eligible only if both users at 100% and both consent + face photo available; reveal requires explicit tap, never auto‑opens.
- Server owns threshold checks and sets `unlock_state` in `conversations`.

## Client Integration (Flutter)
- New `FeelingProgress` widget (`lib/widgets/feeling_progress.dart`):
  - Renders "Feeling" label above a linear progress bar and percent.
  - Props: `percent`, optional `title` to show renamed thread inline.
- Chat conversation header (`lib/screens/chat/chat_conversation_screen.dart:159–181`):
  - Replace fixed `"75%"` circular chip with a tappable chip showing current `feeling_percent` and open `ConnectionLevelModal`.
  - Show renamed title next to progress chip when present.
- Connection level modal (`lib/screens/chat/connection_level_modal.dart:75–105, 101–155`):
  - Insert "Feeling" label above the progress bar; drive progress from `feeling_percent`.
  - List unlocks bound to `unlock_state`.
- Conversations list (`lib/screens/chat/chat_list_screen.dart:487–541`):
  - Add "Feeling xx%" preview text for each item from server without opening the chat.
  - Subscribe to conversation changes to keep the list in sync.
- Home screen preview (`lib/screens/home_screen.dart:1050–1143`):
  - Replace static list with server data for conversations and display `Feeling xx%` as already designed.
- Thread renaming:
  - Allow rename from conversation header overflow menu; update `conversations.title` via service.
  - Display the renamed title inline with Feeling progress wherever the progress bar appears.
- Input gating:
  - Disable voice message button until 50% (and `has_voice_feature` true).
  - Show Quote at 25% and Surprise at 75%.
  - Photo reveal button appears at 100% and requires explicit tap to view.

## Services & State
- Extend `DatabaseService` to include:
  - `getUserConversations(userId)`, `getConversation(conversationId)`, `renameConversation(...)`.
  - `sendMessage(conversationId, senderId, type, payload)` (server handles progress).
- Add `FeelingController` using `ValueNotifier<FeelingState>` + Supabase realtime subscription to `conversations`.
- Persist progress by reading `feeling_percent` from server on app start and after every send.

## Real‑time UI Updates
- Subscribe to `conversations` row updates for each open chat to reflect progress changes immediately.
- For list screens, use a batched subscription or periodic refresh.

## QA Plan
- Unit test trigger logic with message sequences: A→A (no progress), A→B (advance), A→B→A→B (advance twice), edge cases.
- Verify unlocks at exact thresholds: 25/50/75/100 using seeded data.
- Mutual 100% photo reveal: ensure both consents/face photos required; confirm no auto‑open.
- Persistence: restart app/session and confirm progress remains.
- UI tests: Feeling label displays in all required locations; gating disables/enables correctly.

## Migration & Backfill
- Create new tables and policies.
- Backfill conversations from current mock lists (optional seed to demo).
- Tie existing profile/registration flow to `has_quote_feature`, `has_voice_feature`, `consent_photo_reveal` flags.

## Delivery Steps
1. Implement Supabase schema, RLS, and triggers/functions.
2. Wire `DatabaseService` methods and realtime subscriptions.
3. Add `FeelingProgress` widget and update the three UI areas.
4. Implement thread renaming UI and service.
5. Gate features in input and modals.
6. Write tests and verify thresholds + persistence.

## Notes
- All threshold checks and progress computation happen server‑side; client treats `feeling_percent` and `unlock_state` as read‑only.
- Photo reveal is an explicit, user‑initiated action; no auto‑open or background reveal.
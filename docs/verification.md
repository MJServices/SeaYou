# SeaYou Anonymous Experience — Verification

## Tutorial Bubbles
- After sign-up: Home shows coachmark if not seen.
- First interactions: photo/quote/audio tips triggered once.
- Premium areas: Home coachmark for free tier; dialogs on tile taps.

## Feeling-Based Progression
- 25%: quote icon enabled; banner shows progress.
- 50%: voice mic enabled.
- 75%: surprise modal blocks until answered; inputs disabled.
- 100%: photo reveal icon appears; consent flow required.

## Premium & Elite
- Secret Souls: gated for premium.
- Chamber: gated; Elite DM confirm dialog.

## Anonymous-First Profile
- Face photo required but hidden; coachmark prompts if missing.
- Secret quote and audio captured in chat; unlocked by thresholds.

## Conversation
- Named threads; Feeling bar visible in header and lists.
- Unlock features as thresholds advance.

## Special 75%
- Sexy questions modal; must answer ≥1 to continue.

## Controlled Reveals
- Consent persisted in `user_preferences.consent_photo_reveal`.
- Reveal only after mutual 100% and explicit consent.

## Backend
- Outbox RPC: `process_outbox_one`, `process_outbox`.
- Face verify SQL: `public.face_verify(photo_id, score, threshold)` and trigger limiting first-face.

## Accessibility
- Semantics on coachmarks, sliders, dropdowns, tiles.
- Keyboard navigation and contrast verified.

## Performance
- Debounced sliders; skeletons on Secret Souls; image prefetch.

## Testing
- Unit: TutorialService keys; feeling logic.
- Integration: chat gating; elite DM confirm; outbox compose queue.

## Rollback
- UI changes via VCS; DB migrations reversible with stored dump.

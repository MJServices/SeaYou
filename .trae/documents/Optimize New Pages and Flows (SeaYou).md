## Pages to Update

### Outbox Compose

* Replace temporary “Compose Outbox (temp)” entry with a real CTA in Home (e.g., “Send Anonymous Message”).

* Validate inputs: non-empty message, age range start ≤ end, distance within 10–200, gender in allowed values.

* Disable submit while processing; show success/Error snackbars.

* Navigate: After submit and matching RPC return, route to Home with a toast and optional link to Inbox.

* Accessibility: labels for sliders/dropdowns, `Semantics` for controls, larger hit areas, focus order.

* Performance: debounce slider updates, avoid rebuilds; lazy load any heavy widgets; prefetch user profile where needed.

### Home Screen

* Remove all temporary TextButtons (Open Gallery temp, Compose Outbox temp, Open Chamber temp).

* Add proper tiles/cards:

  * “Secret Souls” → gated by `EntitlementsService.isPremium`; show explainer bubble for free tier.

  * “Chamber of Secrets” → gated; elite DM visible only for `isElite`.

  * “Send Anonymous Message” → opens Outbox Compose.

* Navigation flow: return consistently to Home after actions; preserve state and message counters.

* Accessibility: `Semantics` on tiles, keyboard navigation, color contrast.

### Secret Souls Gallery

* Real grid with paging; placeholders/skeletons until load.

* Owner controls: toggle `is_visible_in_secret_souls` and `is_hidden` on own photos.

* Gating for free tier → modal with benefits and subscription CTA.

* Performance: `CachedNetworkImage` or equivalent; prefetch thumbnails; limit initial load.

### Chamber of Secrets

* Randomized pagination for fantasies; report button wired.

* Elite anonymous DM: confirm dialog, start masked conversation, feedback.

* Accessibility: list semantics, button labels, focus order.

### Registration Flow (new group)

* Steps: Quote → Voice (10–30s) → First Face Photo (AI verify) → Fantasy.

* Integrate `face-verify` function; enforce threshold (e.g., 75); show immediate feedback and block step progression on failure.

* Persist per step; resume if interrupted.

## Logic & Backend Enhancements

* Matching: Prefer DB RPC `process_outbox_one`/`process_outbox`; optional scheduled job.

* Feeling: Q/A gating enforced server-side (trigger updated); client sets `qa_group_id` for question and answer.

* Photo limit: enforced trigger; show user-friendly error when exceeding.

## Responsiveness & Cross-Browser

* Responsive layout: max width constraints already used; ensure components scale down to small screens.

* Cross-browser (mobile browsers): test webview and external browser OAuth flows; ensure tap targets ≥ 44 px.

## Accessibility (WCAG 2.1 AA)

* Color contrast for text/buttons.

* Keyboard navigation and focus indicators.

* Semantics: descriptive labels, dropdown/slider roles.

* Error messages with text and role alerts.

## Performance (<2s perceived)

* Defer heavy requests; show skeletons while loading.

* Cache images and results; paginate lists.

* Avoid rebuild hot paths; use `const` widgets; memoize expensive logic.

## Testing

* Unit tests:

  * Validation: outbox form (message non-empty, ranges).

  * Entitlements gating.

  * Feeling progress math for Q/A pairs.

  * Photo flags toggle.

* Integration tests:

  * Compose → queue → matching RPC → inbox shows message.

  * Secret Souls gating flows and visibility toggles.

  * Chamber list + elite DM start.

* UAT scenarios:

  * End-to-end anonymous message send and reply.

  * Registration step completion and face verify pass/fail.

  * Premium vs free experiences for gallery and chamber.

## Documentation

* Update `docs/verification.md` with pages and flows.

* Add usage docs for new RPC functions (`process_outbox_one`, `process_outbox`) and `face-verify`.

* Record accessibility and performance standards.

## Execution Order

1. Home: remove temp buttons, add real CTAs; wire gating.
2. Outbox Compose: validations, async handling, navigation.
3. Secret Souls: grid, toggles, gating.
4. Chamber: pagination, elite DM flow, report.
5. Registration steps: quote/voice/face/fantasy; integrate face-verify.
6. Tests (unit/integration/UAT) and documentation.

## Rollback & Approvals

* Keep current DB dump; revert UI changes via VCS if needed.

* Obtain approval after UAT then deploy.


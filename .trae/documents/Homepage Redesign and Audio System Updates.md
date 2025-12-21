# Homepage Redesign and Audio System Updates

## Hero Section

* Swap hero characters: place `hero_male.png` left and `hero_female.png `right in the existing hero `Stack` in `lib/screens/home_screen.dart:106` using `Positioned` containers. If assets differ, use current `hero_image.png` split into two positioned images. these images are most likely named as avatar 1 and avatar 2 see the codebase then make and edit

* Keep decorative blur circles and profile header; adjust alignments to maintain balance at all screen sizes.

* Update subtitle under "SeaYou" in the splash to: `And if you let chance do the rest.` by changing the text at `lib/screens/splash_screen.dart:111`.

## Navigation Elements

* Insert a down arrow indicator between the hero and tiles using `assets/icons/nav_arrow_down.svg` as an `SvgPicture.asset` centered, with subtle fade-in on scroll.

## Content Tiles

* Use the existing card patterns to add four tiles:

  1. "Ongoing Conversations" with open bottle + scroll visual (compose `empty-bottle.png` or `fill bottle.png` with a scroll overlay SVG). Implement as a new `BottleCard` variant near `lib/widgets/bottle_card.dart:3` or reuse `_buildBottleCard` in `lib/screens/home_screen.dart:612`.
  2. "Écrire un message" tile leading to `SendBottleScreen` (`lib/screens/send_bottle_screen.dart`).
  3. "Les Âmes Secrètes" tile linking to a curated/locked list (new route or existing filtered list).
  4. "La Porte des Désirs" tile linking to the discovery/connection area.

* Render in a responsive 2×2 grid using the existing `_buildBottleRows()` (`lib/screens/home_screen.dart:445`) and `_buildDynamicBottleCard(...)` (`lib/screens/home_screen.dart:533`) patterns.

## Discovery Card

* Add a dedicated component under the tiles: shows `"3 nouveaux messages"`, bottle visual (`letter.png` or `check_letter.png`), and a `Découvrir` button. Place beneath `_buildBottleRows()` call (`lib/screens/home_screen.dart:318`) with a white card style consistent with the app.

## CTA Banner

* Insert a full-width promotional banner near page bottom with text `DÉCOUVRIR SEAYOU PREMIUM`, gradient background, and light shadow. Link to a Premium screen or placeholder route.

## Conversation List Variant

* Add a list section on the homepage summarizing conversations:

  * Header "Vous avez X (nombre) de conversations" using the dynamic count from Supabase (`_receivedCount` / or conversations data).

  * Show names and a `Feeling N%` indicator per item (reuse mood logic or connection percentage). Base list rendering on `ChatListScreen` methods beginning at `lib/screens/chat/chat_list_screen.dart:411`.

  * Include a `Lire` action that navigates to `ChatConversationScreen` (already used in `_buildConversationItem` at `lib/screens/chat/chat_list_screen.dart:462`).

## Audio System

* Add audio playback dependency (to pubspec): `audioplayers:^5.x` for simple SFX and ambient loop.

* Create `lib/services/audio_service.dart` with a `GlobalAudioController` to manage:

  * Ambient waves: loop `assets/sfx/ambient_waves.mp3` at baseline volume 0.7 (−30%).

  * Completion SFX: play `assets/sfx/progress_complete.wav` once at volume 1.0.

  * Global mute: a `ValueNotifier<bool>` that mutes/unmutes both ambient and SFX instantly.

* Integrate ambient audio start/stop in `HomeScreen` lifecycle (`initState`/`dispose`) at `lib/screens/home_screen.dart:37`.

* Implement one‑tap mute:

  * Wrap the app scaffold in a root-level `GestureDetector` in `lib/main.dart:21` with `behavior: HitTestBehavior.translucent` and toggle mute on any tap; add a small top-right mute status indicator overlay.

  * Ensure the toggle only affects audio state and does not disrupt existing gestures.

* Progress-bar completion SFX:

  * In `lib/screens/chat/connection_level_modal.dart:61`, drive the progress with an `AnimationController`; on `AnimationStatus.completed` play the SFX and set a heart icon to red.

  * Add a heart UI element near the bar and toggle its color to red precisely when progress reaches 100%.

* Optional ducking: momentarily reduce ambient volume to 0.5 while SFX plays, then restore to 0.7.

## Responsiveness

* Maintain the existing `ConstrainedBox` (`lib/screens/home_screen.dart:100`) and column layout; use `LayoutBuilder` to adjust grid spacing and card sizes for small/large screens.

## Assets

* Visuals: `hero_male.png`, `hero_female.png`, bottle + scroll icon, and any new section icons within `assets/images/` and `assets/icons/`.

* Audio: `assets/sfx/ambient_waves.mp3`, `assets/sfx/progress_complete.wav` added to `pubspec.yaml` under `assets:`.

* If named assets differ from provided designs, we’ll map to your filenames during implementation.

## Verification

* UI: Confirm hero swap, subtitle text, arrow indicator, tiles grid, discovery card, CTA banner, and list variant render correctly on common device sizes.

* Audio: Verify ambient plays at reduced volume; trigger the progress animation to confirm SFX fires exactly at 100% and heart turns red; test global tap mute/unmute and observe the visual indicator.

* Navigation: Ensure each tile/link navigates to the intended screens without regressions.

## Code References

* Home: `lib/screens/home_screen.dart:18`, `:106`, `:318`, `:445`, `:533`, `:612`

* Bottle card: `lib/widgets/bottle_card.dart:3`

* Splash subtitle: `lib/screens/splash_screen.dart:111`

* Conversation list: `lib/screens/chat/chat_list_screen.dart:411`, `:462`

* Progress bar: `lib/screens/chat/connection_level_modal.dart:61`

* Waveform visual: `lib/widgets/animated_waveform.dart:6`

* App root: `lib/main.dart:21`

If this plan looks good, I’ll implement the UI changes, add the audio controller and assets, wire up mute and completion SFX, and verify across screens.

# PrimeFlix App — Phase 1-6.1 (… + Settings & Polish + bug-fix pass)

Included: pubspec (all deps), dark/gold glass theme, `MovieBoxClient` (all endpoints),
models, content filter, SharedPreferences wrapper, login screen with auto-login.

## Setup (one time)

This zip contains only the Dart source (`lib/`, `pubspec.yaml`). Generate the
Android/native scaffolding inside this folder:

```bash
cd primeflix_app
flutter create . --org com.primeflix --project-name primeflix_app --platforms android
flutter pub get
flutter run            # test on device/emulator
```

`flutter create .` will not overwrite `lib/` or `pubspec.yaml`... if it replaces
`lib/main.dart`, re-copy it from this zip.

Notes:
- In `android/app/build.gradle(.kts)` set `minSdkVersion 21` (needed by better_player).
- Add `<uses-permission android:name="android.permission.INTERNET"/>` to
  `android/app/src/main/AndroidManifest.xml` if missing (release builds need it).

## Test (Phase 1)
App opens -> enter any member key -> Continue -> key saved -> restart app -> goes straight to Home.

## Phase 4 — Video Player (new)

Files: `lib/features/player/` (`player_screen.dart`, `srt_parser.dart`, `widgets/player_controls.dart`, `widgets/option_sheet.dart`).
Also changed: `details_screen.dart` (Play now opens the player), `prefs.dart` (progress storage), `pubspec.yaml` (+ `screen_brightness`, `volume_controller`).

Features: ExoPlayer via BetterPlayer (DASH/HEVC) with `Cookie: signCookie` header, glass controls
(play/pause, ±10s, gold progress bar with buffered track, time), quality / speed (0.5x-2x) / subtitle pickers,
SRT/VTT subtitle overlay, gestures (left swipe = brightness, right swipe = volume, double-tap = ∓10s),
autoplay next episode, auto-resume from last position (saved every 5s and on exit).

Setup after `flutter pub get`:
- `AndroidManifest.xml`: INTERNET permission (see above). If streams are plain http, also add `android:usesCleartextTraffic="true"` on `<application>`.
- The player now uses `better_player_plus` (maintained fork, Media3). Original `better_player` 0.0.84 is unmaintained and breaks on AGP 8.

Test (Phase 4): open a movie -> Play -> HEVC video plays; swipe/double-tap gestures; subtitles; quit mid-way and reopen -> resumes.

## Phase 5 — My List + Continue Watching (new)

New: `features/home/widgets/continue_row.dart`, `features/player/play_launcher.dart`.
Changed: `prefs.dart` (progress now stores title + season/episode, `continueWatching`, `clearProgress`, `progressRev` notifier),
`models.dart` (+`WatchEntry`), `player_screen.dart` (`item`, `startOver`), `home_screen.dart`, `details_screen.dart`, `mylist_screen.dart`.

- **Continue Watching row** on Home (above other rows): poster + gold progress bar + "S1 E3 • 24m left". Tap = resume directly, long-press = remove. Updates live when you come back from the player.
- **Resume dialog**: "Continue from 24:15?" -> Resume / Start over, shown from Details (Play button and episode tiles) when a saved position exists.
- **Episode tiles** on Details show a thin gold progress bar for partly-watched episodes.
- Progress saves every 5s, on pause and on exit; entries vanish at 95% watched.
- **My List**: visible (x) remove button on each poster (long-press still works).

Note: progress saved by Phase 4 builds has no title info, so it resumes but won't appear in Continue Watching until watched again.

Test (Phase 5): play something for >10s, back out -> Home shows Continue Watching with progress; tap resumes; reopen from Details -> resume dialog; finish video -> entry disappears.

## Phase 6 — Settings + Polish (new)

New: `features/splash/splash_screen.dart`, `assets/icon/*` (gold "P" on black).
Changed: `settings_screen.dart` (full iOS grouped), `prefs.dart`, `player_screen.dart`, `moviebox_client.dart`, `loading.dart` (+`EmptyState`), `mylist_screen.dart`, `search_screen.dart`, `poster_card.dart`, `main.dart`, `pubspec.yaml` (+`flutter_launcher_icons`).

- **Settings**: Family Filter, default playback speed, autoplay-next toggle, subtitle size / color / background (with live preview), clear watch history, clear My List, masked member key, About, Privacy, Logout (with confirm dialogs).
- Player now uses default speed, autoplay-next toggle and subtitle style from Settings.
- **Splash**: animated gold "P" then fade into Login / Home.
- **Empty states**: My List and Search (idle + no results) use the new `EmptyState` widget.
- **Friendly errors**: timeout / offline / 404 / 401-403 / server-busy messages (shown with Retry).
- **Performance**: poster images decoded at 400px (`memCacheWidth`) with fade-in.

Generate the app icon (after `flutter pub get`):
```bash
dart run flutter_launcher_icons
```
Test (Phase 6): change subtitle size/color -> preview updates and player subtitles match; set default speed 1.25x -> next video starts at 1.25x; turn Autoplay off -> series stops after the episode; clear history -> Continue Watching row disappears.

## Phase 6.1 — Bug-fix pass

- **Player**: `better_player` -> `better_player_plus`. On a playback error it auto-falls back to the next (lower) stream at the same position; error screen has a working Retry (keeps chosen stream) and *Choose quality*. Controller-not-ready no longer crashes the controls.
- **Series**: autoplay rolls into the next season; finishing an episode queues the next one as **Up next** in Continue Watching (also when Autoplay is off). Episodes fetched with perPage 300.
- **Family filter**: fixed `18+` pattern, added stems (porn*, erotic*, nude*...), small allow-list (Sex Education, Sex and the City, XXX: Xander Cage); toggling it in Settings now re-filters Home/Search instantly.
- **Home**: no unhandled async errors, pull-to-refresh keeps content (no skeleton flash), empty state.
- **Networking**: one shared HTTP client; accurate errors (offline / bad response / TLS / timeout).
- **Perf**: progress and My List decoded once and cached.
- **Search**: genre tap cancels pending typed query; keyboard dismisses on scroll.
- **Navigation**: Back on any tab goes to Home first; app locked to portrait (player = landscape, restored after).
- **Misc**: poster grid taller (no overflow with big fonts), `PopScope.onPopInvokedWithResult`, SDK >= 3.4, subtitle HTML entities decoded, Details no longer fails when `/info` fails but item data exists.

Still open: member key is not sent to the API (needs your API's auth scheme); Home/genre rows are keyword searches.

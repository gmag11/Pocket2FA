# Design

## Context

See `proposal.md` - Why. The relevant current state:

- `android/app/src/main/kotlin/net/gmartin/pocket2fa/MainActivity.kt` is a `FlutterFragmentActivity` registered in the main manifest as `.MainActivity` with `android:launchMode="singleTop"` and `android:taskAffinity=""`.
- The manifest declares no `<service>` and no extras; the app ships no Android string resources (the app label is the literal `"Pocket2FA"`) and no vector drawables of its own.
- `android/app/build.gradle.kts` uses `compileSdk = flutter.compileSdkVersion` with `targetSdk = 36` and `minSdk = 24` (Flutter's current default).
- Dart-side UI strings live in `lib/l10n/app_{en,es,fr}.arb`; Android resources are a separate namespace, so a tile label needs its own `res/values*/strings.xml`.
- `lib/screens/settings_screen.dart` builds every setting through `_buildSettingTile(...)` (`ListTile` + icon + title + optional subtitle + trailing).
- The app has its own lock flow (`local_auth`, settings-gated) that runs independently of the platform launch path.

Constraints: Flutter exposes no Quick Settings API; `targetSdk 36` changes which `startActivityAndCollapse` overload is legal; a tile is bound on demand by SystemUI, so it must not hold state or do work.

## Goals / Non-Goals

**Goals**

- A Quick Settings tile that opens Pocket2FA with a single tap from the notification shade.
- No security regression: no code becomes visible on the lock screen, and no lock step is skipped.
- Zero new Flutter dependencies and zero new runtime permissions.
- The tile behaves correctly on API 24 through 36, including the API 34+ launching rules.
- The user can discover and add the tile from inside the app.

**Non-Goals**

- Showing a one-time password, countdown or account name on the tile surface.
- Making the tile a toggle (e.g. "lock now") or a shortcut to a specific server/account.
- App Shortcuts / launcher long-press actions (a separate, Dart-only feature if ever wanted).
- Any change to Linux/Windows builds.
- Choosing the exact landing screen: the reporter's answer on issue #19 is still pending, so this design covers a plain launch and leaves deep-linking as a follow-up (see Open Questions).

## Decisions

### Decision 1: A native `TileService`, not a pub.dev package

Add `QuickTileService : TileService` in the app's own Kotlin package and declare it in the main manifest.

**Why:** the whole feature is ~40 lines that launch `MainActivity`; the project already owns Kotlin code and its manifest, so a dependency would add supply-chain and maintenance cost for no functionality. The available packages are also immature — `quick_settings_tile` is at `0.0.1` (Nov 2025) and `quick_settings` has not shipped since 2023 — and they only wrap this same `TileService` API.

**Alternative considered:** `quick_settings` / `quick_settings_tile` from pub.dev. Rejected: unmaintained/very young, and still requires the same manifest entries and icon work.

### Decision 2: Launch via `startActivityAndCollapse` with an API-level branch

`onClick()` builds an `Intent` for `MainActivity` with `FLAG_ACTIVITY_NEW_TASK`, then:

- API >= 34: `PendingIntent.getActivity(..., FLAG_IMMUTABLE)` and the `startActivityAndCollapse(PendingIntent)` overload.
- API < 34: the legacy `startActivityAndCollapse(Intent)` overload.

**Why:** with `targetSdk 36`, the `Intent` overload is deprecated *and* throws `UnsupportedOperationException` at runtime on API 34+, while the `PendingIntent` overload does not exist before API 34. Branching on `Build.VERSION.SDK_INT` is the only combination that works on every supported version. The published behavior matrix (runtime x target SDK) confirms the split at runtime API 34.

**Note:** `minSdk 24` means `unlockAndRun` is always available; no compatibility shim is needed for it.

### Decision 3: Require an unlock before showing the app, and keep the tile passive

`onClick()` calls `unlockAndRun { startActivityAndCollapse(pending) }` unconditionally (when the device is not secured, `unlockAndRun` runs the block immediately), and the tile sets no subtitle and holds no state.

**Why:** Quick Settings tiles can be shown on top of the lock screen, and this app's payload is by definition a secret. Prompting for the device credential before the UI appears is what the platform recommends for non-safe actions, and it keeps the feature a convenience rather than a bypass. Because the tile never renders a code, the risk of a code being photographed/observed on a locked shade is eliminated by construction.

**Alternatives considered:** (a) launch directly with `startActivity` — rejected, would put the app (and possibly codes) on the lock screen; (b) show the current code as a tile subtitle — rejected as a security anti-pattern and out of scope.

The app's own biometric/PIN lock still runs on top of this: launching from the tile does not mark the session as unlocked. The tile is an entry point, not an authentication step.

### Decision 4: Monochrome vector icon plus Android string resources

The tile uses a single-color `<vector>` drawable (system-tinted) and `android:label="@string/qs_tile_label"`, with `res/values/strings.xml`, `res/values-es/strings.xml` and `res/values-fr/strings.xml` to match the three languages the app already ships.

**Why:** Quick Settings icons are tinted by SystemUI, so adaptive/launcher icons or colored assets render wrong; label length must stay short (~12 chars) or the shade truncates it. Localizing in Android resources is the only mechanism the tile label understands.

**Trade-off:** this duplicates a handful of strings outside the ARB pipeline. Deliberately limited to one or two very short strings, and noted in the tasks as something to keep in sync when a language is added.

### Decision 5: Offer the tile from Settings through a tiny MethodChannel

Add a "Quick Settings tile" entry to Settings that, on Android, calls a new `requestAddTile` method on a `net.gmartin.pocket2fa/quick_tile` channel handled by `MainActivity` (`configureFlutterEngine`). The handler uses `requestAddTileService` on API 33+ and returns a status the UI turns into either the system prompt result or "add it manually from Settings > Quick settings > Edit tiles" instructions. On Linux/Windows the entry is not rendered.

**Why:** users rarely discover third-party tiles, and the system prompt only exists on API 33+; a status return keeps the Dart side platform-agnostic and testable. Keeping the channel in `MainActivity.kt` avoids a plugin package.

**Alternative considered:** no in-app entry, rely on the user knowing the tile editor. Rejected as poor discoverability, but the entry is isolated so it can be dropped without affecting the tile itself.

### Decision 6: Bring the existing instance forward, never a second one

The launch intent uses `FLAG_ACTIVITY_NEW_TASK` (required from a non-activity context) together with the manifest's `launchMode="singleTop"` and `taskAffinity=""`; `FLAG_ACTIVITY_CLEAR_TOP` is applied only if testing shows the tile can push a duplicate `MainActivity`.

**Why:** the tile is a launcher, so tapping it twice must not stack two Flutter engines (which would duplicate timers and sync work). `FLAG_ACTIVITY_CLEAR_TOP` is intentionally *conditional*: in an app where `MainActivity` is the only activity it is harmless, but it would discard navigation state if more activities are ever added.

## Risks / Trade-offs

- **Wrong overload on API 34+** → the tile would throw and appear dead. Mitigated by Decision 2's explicit branch, and called out as a manual test case on an Android 14+ device.
- **Duplicate app instances / duplicated sync** → mitigated by `singleTop` + `taskAffinity=""` and a verification task that taps the tile with the app both closed and backgrounded.
- **Extra unlock prompt feeling redundant** with the app's own lock → accepted; the security benefit outweighs one tap. Worth documenting in the release notes so it is not reported as a bug.
- **Localized label drift** from the ARB files → limited to one short string per language and flagged in the tasks.
- **Discoverability** → mitigated by the in-app entry (Decision 5); on API < 33 the user still has to use the tile editor.
- **Manual-only verification** → a `TileService` cannot be exercised by widget tests, and third-party tiles do not always appear on emulators. Mitigated by keeping the logic minimal and by the fact that no Dart code path is added beyond an opt-in Settings entry.

## Migration Plan

1. Add the `TileService` and its manifest entry; add the string resources and the vector drawable.
2. Add the `requestAddTile` channel handler and the Settings entry.
3. `flutter analyze` + a release `assembleRelease`/`assembleDebug` to prove the manifest merges and the Kotlin compiles.
4. Manual device pass: add the tile, tap it with the app closed / backgrounded / already open, locked and unlocked, on an Android 14+ device and on an older one.
5. Answer issue #19, then decide whether to extend the tile to deep-link (see Open Questions).

Rollback: delete the service file and its manifest entry, the drawable and the string resources, and the Settings entry. No stored data, no migration, no versioned schema is involved.

## Open Questions

1. **Landing behavior (open, gating)** — should the tile just open the app, or jump straight to the code list / focus the search field? The question was asked on issue #19 on 2026-10-17 (comment 6239106071) and the reporter had not answered as of 2026-10-20, so implementation is paused until that answer arrives. The current requirements only cover the plain launch, and deep-linking would be a small follow-up delta (an intent extra read through the same channel).
2. **Tile label wording (decided)** — use the brand name "Pocket2FA" in all three shipped languages. It is 9 characters (short enough for the shade), needs no translation, and matches the wording already described on issue #19. No spec change required.

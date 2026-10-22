# Design

## Context

See `proposal.md` - Why. Current state:

- `AccountTileUtils` is static and pure apart from Flutter `Color` values.
- `AccountTileAnimations` owns an `AnimationController` and uses the wall clock
  to pick the initial progress; it needs a `TickerProvider`.
- `AccountTileUi` contains static widget builders for avatars, shared indicators,
  HOTP controls and progress dots. It reads local files for icons and localized
  strings.
- `AccountTile` only dispatches to `AccountTileTOTP`/`AccountTileHOTP` and adds
  a pending-upload badge when `synchronized == false`.
- `pumpApp` already provides the localization/theme setup. `SettingsService`
  can be backed by `FakeSettingsStorage`, so formatting tests never reach
  shared preferences.
- No tests currently exercise these four files; all are at 0%.

## Goals / Non-Goals

**Goals:**

- Cover the observable presentation contracts: formatted text, colors, avatar
  fallbacks, indicators, HOTP controls, progress dots, dispatch and badge.
- Keep tests deterministic and free of plugins, real network and leaked timers.
- Reuse the existing widget/localization helpers.

**Non-Goals:**

- Covering `AccountTileTOTP`/`AccountTileHOTP` internals (copy flows, reveal
  timers, manage-mode layout). Those are stateful screens of their own and will
  get a later stage.
- Changing `SettingsService`, the tile widgets or any production file.
- Testing `SvgPicture` rendering pixel-perfectly; only assert that the SVG path
  is selected and falls back safely.
- Chasing animation boundary branches that depend on the exact wall-clock
  millisecond.

## Decisions

### Split pure utilities from widget tests

- `test/unit/widgets/account_tile_utils_test.dart`: no widget binding; drives
  `formatCode` with `SettingsService(storage: FakeSettingsStorage(...))` and
  calls the setters before asserting. Covers compact/spaced formats, disabled
  formatting, hidden OTPs, forced visibility, whitespace, offline text and the
  short-group fallback.
- `test/widget/account_tile_animations_test.dart`: uses `TestVSync` and a
  `testWidgets` body so `AnimationController` has a scheduler. Asserts duration,
  initial value range, controller replacement, stop and dispose. It does not
  depend on a particular initial progress.
- `test/widget/account_tile_ui_test.dart`: pumps the static builders inside
  `pumpApp` and covers `AccountTile` dispatch plus the pending badge.

Keeping the pure file binding-free mirrors the existing split between
`entry_creation_service_test.dart` and the widget SnackBar test.

### Use temporary files for avatar paths

Create one temporary directory per test group with
`Directory.systemTemp.createTempSync`, write a tiny PNG-like/non-SVG file and a
small SVG, then delete the directory in `tearDown`. This exercises the real
`FileImage`/`SvgPicture` branches without mocking `dart:io`.

The SVG fixture includes a percentage geometry value so the sanitizer path is
exercised, but assertions only check that an `SvgPicture` appears and that a
missing file falls back to the letter avatar.

### Drive static UI builders directly

Call `AccountTileUi.buildServiceAvatar`, `buildSharedIndicator`,
`buildHotpButton`, `buildHotpDisplay` and `buildProgressDots` with explicitly
constructed accounts/settings. This is narrower than pumping a full tile and
avoids its OTP timers for the presentation cases. `AnimatedBuilder`/`InkWell`
callbacks are asserted through `tester.tap` where they are observable.

### Dispose full tiles after dispatch tests

`AccountTileTOTP` starts an OTP refresh timer and an animation. Dispatch tests
pump the tile, assert the child type/badge, then replace the tree with
`const SizedBox()` and pump once so `dispose` cancels the timer. HOTP tiles do
not animate but still use the OTP service, so the same cleanup applies.

### Keep baseline measurement last

Run the full suite and the coverage gate after the tests land. Set
`.coverage-baseline` to the measured overall value; expected gain is roughly
2-3 points, but the measured value wins.

## Risks / Trade-offs

- **Pending timers from TOTP tiles** → replace the widget with `SizedBox` and
  pump before the test ends.
- **SVG/FileImage async rendering** → `pumpAndSettle` and assert widget types or
  fallback text, not decoded pixels.
- **Localization lookups in HOTP/progress widgets** → always pump inside
  `pumpApp` with the app delegates; never call `AppLocalizations.of` outside a
  MaterialApp.
- **Animation progress depends on `DateTime.now()`** → assert range/duration
  and controller lifecycle, not an exact value.
- **Color assertions are sensitive to theme data** → assert against
  `Colors.primaries[index]` computed from the same character-sum rule, not a
  hardcoded swatch.
- **Private `_sanitizeSvg` cannot be called directly** → cover it through an SVG
  local icon; accept that malformed-SVG fallback is best-effort.
- **Full tile tests can be brittle if layout changes** → assert only child types,
  badge icon and tooltip text, not pixel positions.

## Migration Plan

Not applicable: test-only change, no data or deployment migration. Rollback is
deleting the new tests and restoring the previous baseline.

## Open Questions

None that affect scope. Exact coverage will be measured after the tests run.

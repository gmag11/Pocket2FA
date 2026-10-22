# Proposal

## Why

The account-tile presentation helpers are now covered (overall coverage is
31.43%), but the two stateful tiles that users actually interact with are still
mostly unmeasured:

- `lib/widgets/account_tile_totp.dart`: 96 of 199 executable lines (48.2%).
- `lib/widgets/account_tile_hotp.dart`: 63 of 188 executable lines (33.5%).

That leaves 228 uncovered lines in the user-facing flows this app exists for:
copying the current or next code, revealing hidden OTPs, manage-mode selection
and editing, generating an HOTP code, the counter, offline/error feedback and
the automatic clearing timers. These paths are easy to break and hard to notice
because they need taps, long presses and timers.

## What Changes

- Add widget tests for `AccountTileTOTP`:
  - normal rendering at a fixed clock, current/next code formatting;
  - tapping the current code and the next code, with clipboard capture;
  - no-code and clipboard-error SnackBars;
  - long-press reveal for hidden current/next codes and the 10-second re-hide;
  - manage mode for owned/borrowed accounts, selection and edit callbacks;
  - wide-screen layout, `didUpdateWidget` recreation and timer disposal.
- Add widget tests for `AccountTileHOTP`:
  - initial Generate button, successful server request, code/counter display;
  - tapping the generated code, and the 30-second auto-clear;
  - offline/error state and its auto-clear;
  - manage mode, wide-screen layout, `didUpdateWidget` and timer disposal.
- Mock the clipboard platform channel and reuse `ApiTestHarness` for HOTP.
- Raise `.coverage-baseline` to the measured overall value after the stage.

No production code, dependencies or public behavior changes.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

None. This is test-only work; the change declares `skip_specs: true`.

## Impact

- New tests under `test/widget/`.
- Reuses `pumpApp`, `FakeSettingsStorage`, `ApiTestHarness`, the fixed-clock
  helper and the existing localization setup; no new dependencies.
- `.coverage-baseline` rises from 31.43 to the measured value (expected around
  34-37%, not guaranteed).
- No `lib/` changes, so the release APK and Android install are unaffected.
- `settings_storage.dart`, `window_geometry_service.dart` and the screens remain
  for later stages.

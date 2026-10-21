# Proposal

## Why

The corrected coverage baseline is 24.89% overall (69.21% for models and
services). The OTP service behind account tiles is now well tested, but the
presentation layer that decides what the user actually sees is still completely
unmeasured:

- `lib/widgets/account_tile_utils.dart`: 0 of 25 executable lines.
- `lib/widgets/account_tile_animations.dart`: 0 of 27.
- `lib/widgets/account_tile_ui.dart`: 0 of 116.
- `lib/widgets/account_tile.dart`: 0 of 36.

This layer contains user-visible behavior that is easy to regress: OTP
formatting and masking, service-color selection, the pending-upload badge, the
shared-account indicator, avatar fallbacks, HOTP controls and progress dots.
It is also testable without platform plugins or production seams.

`settings_storage.dart` remains the largest service gap, but its class methods
need injectable secure storage and local-auth plugins; that is a separate
decision. This stage takes the largest testable gap instead.

## What Changes

- Add unit tests for `AccountTileUtils.formatCode` and `getServiceColor`:
  compact/spaced formats, whitespace removal, disabled formatting, hidden OTPs,
  forced visibility, offline text, grouping fallbacks and color stability.
- Add tests for `AccountTileAnimations`: initial value/duration, zero/negative
  period fallback, controller replacement, stop and dispose.
- Add widget tests for `AccountTileUi`: avatar fallbacks, file and SVG local
  icons, shared indicator, HOTP button/display, copy callback and progress dots.
- Add widget tests for `AccountTile`: TOTP/HOTP dispatch and the
  pending-upload badge, disposing tile timers after each case.
- Raise `.coverage-baseline` to the measured overall value after the stage.

No production code, dependencies or public behavior changes.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

None. This is test-only work; the change declares `skip_specs: true`.

## Impact

- New tests under `test/unit/widgets/` and `test/widget/`.
- Reuses `pumpApp`, `SettingsService`, `FakeSettingsStorage` and the existing
  localization setup; no new dependencies.
- `.coverage-baseline` rises from 24.89 to the measured value (expected around
  27-28.5%, not guaranteed).
- No `lib/` changes, so the release APK and Android install are unaffected.
- `account_tile_totp.dart` and `account_tile_hotp.dart` behavior remains for a
  later stage; this change covers the shared presentation helpers and dispatch.

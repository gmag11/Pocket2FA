# Proposal

## Why

The small home-shell widgets are now covered (overall coverage is 38.65%).
`lib/screens/settings_screen.dart` is the next untested screen: 209 executable
lines at 0%. It is the control panel for theme, code formatting, biometrics,
PIN lock, hidden OTPs, synchronization and diagnostics, and it links to the
diagnostic log.

Testing it now gives broad coverage of a central screen with deterministic
`SettingsService` state and no new production seams. `settings_storage.dart`
still needs platform mocks before its class methods can be covered; that stays
for a later stage.

## What Changes

- Add widget tests for `SettingsScreen`:
  - section headers and the current setting values;
  - theme selection through the segmented control;
  - code-format enable switch and format buttons;
  - biometrics unsupported tooltip and disabled switch;
  - PIN row rendering (without opening PIN storage flows);
  - hide-OTP, sync-on-open and automatic-sync switches;
  - auto-sync interval add/remove controls;
  - debug-logging switch, the diagnostic-log button and navigation to
    `LogScreen`.
- Render one dark-theme case to cover the alternate tile surface.
- Raise `.coverage-baseline` to the measured overall value after the stage.

No production code, dependencies or public behavior changes.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

None. This is test-only work; the change declares `skip_specs: true`.

## Impact

- New test `test/widget/settings_screen_test.dart`.
- Reuses `pumpApp`, `FakeSettingsStorage` and the existing localization setup;
  no new dependencies.
- `.coverage-baseline` rises from 38.65 to the measured value (expected around
  41-43%, not guaranteed).
- No `lib/` changes, so the release APK and Android install are unaffected.
- PIN setup/disable dialogs and `settings_storage.dart` remain for later
  stages because they reach secure storage and local authentication.

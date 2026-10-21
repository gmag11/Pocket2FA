# Proposal

## Why

The account-tile widgets are now covered (overall coverage is 35.34%, with TOTP
at 99.5% and HOTP at 92%). The next untested layer is a set of small, isolated
UI pieces that the home screen is built from:

- `lib/widgets/about_dialog.dart`: 49 executable lines, 0% covered.
- `lib/screens/search_bar.dart`: 26 lines, 0%.
- `lib/screens/bottom_bar.dart`: 76 lines, 0%.
- `lib/screens/home_header_animation.dart`: 41 lines, 0%.
- `lib/screens/server_detail_screen.dart`: 17 lines, 0%.

They are small enough to test together, have clear observable behavior, and
start covering the screen layer without needing the large `home_screen.dart`
first. The largest remaining service gaps (`settings_storage.dart` and
`window_geometry_service.dart`) need platform seams or singleton setup and stay
for later stages.

## What Changes

- Add widget tests for `AboutDialogContent`: version/title/links, close action
  and the required 2FAuth note.
- Add widget tests for `HomeSearchBar`: hint text, change callback, clear
  button visibility/behavior, focus restoration and the light/dark surfaces.
- Add widget tests for `BottomBar`: empty and selected server summaries,
  online/offline indicators, selector callback and manage-mode delete/done
  states.
- Add unit/widget tests for `HomeHeaderAnimation`: initialization, scroll-driven
  hide/show, threshold behavior, viewport guard and disposal.
- Add widget tests for `ServerDetailScreen`: title and account list rendering.
- Raise `.coverage-baseline` to the measured overall value after the stage.

No production code, dependencies or public behavior changes.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

None. This is test-only work; the change declares `skip_specs: true`.

## Impact

- New tests under `test/widget/`.
- Reuses `pumpApp`, `FakeSettingsStorage`, `serverConnectionFixture` and the
  existing localization setup; no new dependencies.
- `.coverage-baseline` rises from 35.34 to the measured value (expected around
  38-40%, not guaranteed).
- No `lib/` changes, so the release APK and Android install are unaffected.
- Link launching is rendered but not exercised against the real URL launcher;
  that stays for the screen-level tests that need it.

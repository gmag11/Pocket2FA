# Proposal

## Why

`LogScreen` is 163 executable lines at 0% coverage and is the destination of the
settings screen's diagnostics section. It displays the in-memory diagnostic log,
filters by level, copies the report and clears entries. `LogService` itself is
already covered, so this stage can use its real API instead of mocks.

The screen is a contained next step after `settings_screen.dart`; the larger
home screens and `settings_storage.dart` remain for later stages.

## What Changes

- Add widget tests for `LogScreen`:
  - empty state;
  - entries at every level, including names, messages and level tags;
  - filter menu and filtered results;
  - copy-to-clipboard report and SnackBar;
  - clear dialog cancel/confirm and the resulting empty state;
  - scroll-to-bottom floating action button.
- Raise `.coverage-baseline` to the measured overall value after the stage.

No production code, dependencies or public behavior changes.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

None. This is test-only work; the change declares `skip_specs: true`.

## Impact

- New test `test/widget/log_screen_test.dart`.
- Reuses `pumpApp`, `LogService`, `resetLogService` and the existing clipboard
  mock pattern; no new dependencies.
- `.coverage-baseline` rises from 42.33 to the measured value (expected around
  44-46%, not guaranteed).
- No `lib/` changes, so the release APK and Android install are unaffected.
- Sharing/exporting the log file is left for a later stage because it reaches
  `path_provider` and `share_plus`.

# Proposal

## Why

`AccountList` is 101 executable lines at 0% and is the final list layer between
the home screen and the already-covered `AccountTile`. It chooses between empty
states, single-column tiles and a multi-column grid, applies group/search
filters, handles pull-to-refresh and wires manage-mode selection/editing.

The account-tile behavior is covered, so this stage can focus on list filtering
and layout without re-testing the tile internals.

## What Changes

- Add widget tests for `AccountList`:
  - no-server and empty-account states, including the add-server action;
  - deleted entries being filtered out;
  - group and search filtering, including the no-results state;
  - populated single-column list and wide multi-column grid;
  - manage-mode selection/editing callbacks;
  - pull-to-refresh callback.
- Raise `.coverage-baseline` to the measured overall value after the stage.

No production code, dependencies or public behavior changes.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

None. This is test-only work; the change declares `skip_specs: true`.

## Impact

- New test `test/widget/account_list_test.dart`.
- Reuses `pumpApp`, `FakeSettingsStorage`, `AccountEntry` and the existing
  account-tile tests; no new dependencies.
- `.coverage-baseline` rises from 48.17 to the measured value (expected around
  49-50%, not guaranteed).
- No `lib/` changes, so the release APK and Android install are unaffected.
- `home_screen.dart` integration remains for a later stage.

# Proposal

## Why

The home page now has a startup smoke test (74.91% overall), but its populated
list, search filtering and manage-mode wiring are still unmeasured. Those paths
exercise the real composition of `AccountList`, `AccountTile`, the search bar
and the home managers.

## What Changes

- Add a second `HomePage` widget test with one seeded server/account:
  - populated account list and header;
  - search filtering and no-results state;
  - manage-mode toggle and tile selection wiring;
  - clean disposal of tile timers/animations.
- Raise `.coverage-baseline` to the measured value; it stays pinned at 70.0 if
  already above it.

No production code, dependencies or public behavior changes.

## Impact

- Extends `test/widget/home_screen_test.dart`.
- Reuses `FakeSettingsStorage`, `serverConnectionFixture` and the covered child
  widgets; no new dependencies.
- No `lib/` changes; release APK and Android install are unaffected.

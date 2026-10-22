# Proposal

## Why

`HomeServerManager` is 223 executable lines at 0% and is the state owner behind
the home screen: it loads and normalizes servers, restores the selection,
persists changes, inserts created accounts and exposes groups. Testing it
directly with `FakeSettingsStorage` covers the core state transitions without
driving the full home screen.

## What Changes

- Add unit tests for `HomeServerManager`:
  - loading servers, restoring selection and excluding deleted accounts;
  - intentional-empty vs. cached-fallback behavior;
  - normalizing duplicate pending account ids;
  - selecting servers and persisting the selection;
  - persisting servers and handling locked storage;
  - inserting created accounts, updating accounts and adding to the selected
    server;
  - group computation and group-key parsing.
- Raise `.coverage-baseline` to the measured overall value after the stage.

No production code, dependencies or public behavior changes.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

None. This is test-only work; the change declares `skip_specs: true`.

## Impact

- New test `test/unit/screens/home_server_manager_test.dart`.
- Reuses `FakeSettingsStorage`, `serverConnectionFixture`, `AccountEntry` and
  `ApiService`; no new dependencies.
- `.coverage-baseline` rises from 51.48 to the measured value (expected around
  53-55%, not guaranteed).
- No `lib/` changes, so the release APK and Android install are unaffected.
- The real connectivity probe remains for a later stage because
  `validateServer` creates its own `Dio` and would use a real network.

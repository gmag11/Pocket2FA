# Design

## Context

See `proposal.md` - Why. `HomeServerManager` reads `settings.storage.box`,
selects a server, caches `currentItems`, persists `servers`/`selected`, and
normalizes duplicate pending ids. `FakeSettingsStorage` gives an in-memory box,
so all of this runs without Hive.

`ApiService.setServer` is called when a server is selected; close the singleton
around each test. Real connectivity checks are not exercised because
`validateServer` creates its own `Dio`.

## Goals / Non-Goals

**Goals:**

- Cover load/restore/fallback and normalization.
- Cover selection and persistence.
- Cover created/updated account mutations and groups.
- Keep storage and API state isolated per test.

**Non-Goals:**

- `initialConnectivityCheck` success/failure over a real socket.
- Widget rendering of the home screen.
- Persistence failures other than a locked box.

## Decisions

### Build a manager from a fake storage

```dart
final storage = FakeSettingsStorage(initialValues: {...});
final settings = SettingsService(storage: storage);
await settings.reloadFromStorage();
final manager = HomeServerManager(settings);
```

Call `loadServers()` and assert selected id/index, `currentItems` and
`servers`. Close `ApiService.instance` in `setUp`/`tearDown`.

### Load scenarios

- Stored server plus a `selected` map -> restored id/index; deleted accounts are
  filtered from `currentItems`.
- Empty box -> no selection and an empty list.
- Missing `servers` after a previous load -> cached fallback.
- Stored empty `servers` list -> respect the intentional empty state (no
  fallback).
- Unknown selected id -> first server.
- Two pending accounts with id `-1` -> normalized to unique negative ids and
  persisted.

### Selection and persistence

`selectServer('missing')` returns false; a valid id sets the selection, updates
`currentItems`, writes `selected` into the fake box and returns true.
`persistServersToStorage` writes the server maps. With a locked fake, both
persistence paths are no-ops and do not throw.

### Account mutations

- `insertCreatedAccount` without a selected/matching server is a no-op.
- Positive existing id replaces; positive new id appends.
- Non-positive id gets the next negative temporary id and `synchronized:false`.
- `addNewAccount` appends to the selected server or, without one, to the
  in-memory items.
- `updateAccount` replaces an existing account and ignores unknown ids.
- `updateServersInMemory` recomputes `currentItems` when the selected server is
  present.

### Groups

Seed items with `Work` (twice), `Personal` and an empty group. `getGroups`
returns `['All', 'Work', 'Personal']` (order follows insertion) and ignores the
empty group. `getGroupKey('Work (4)')` returns `Work`; a plain key is unchanged.

## Risks / Trade-offs

- **Global ApiService** → close in setup/teardown.
- **Fake storage box** → use `initialValues` and `box.put`/`delete` for
  fallback scenarios.
- **Pending ids** → inspect both `currentItems` and the persisted box.
- **Deleted entries** → verify they are absent from `currentItems`.
- **Network** → do not call `initialConnectivityCheck` beyond its early-return
  guard.
- **Mutation aliasing** → `addNewAccount` mutates the server's accounts list;
  build fresh fixtures per test.

## Migration Plan

Not applicable: test-only change. Rollback is deleting the new test and
restoring the previous baseline.

## Open Questions

None that affect scope. Exact coverage will be measured after the test runs.

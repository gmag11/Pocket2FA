# Design

## Context

See `proposal.md` - Why. `AccountList` reads the supplied items and settings;
it does not own storage except to distinguish "no servers configured" from "no
accounts". `FakeSettingsStorage` provides the box for that check. The actual
rows are `AccountTile`s, already covered, which start OTP timers.

## Goals / Non-Goals

**Goals:**

- Cover the empty, filtered, single-column and grid branches.
- Cover manage-mode selection/editing callback wiring.
- Cover pull-to-refresh.
- Dispose tile timers after each test.

**Non-Goals:**

- Re-testing `AccountTile` internals.
- Navigating into `AccountsScreen`.
- The defensive catch that renders an error tile.
- Home-screen integration.

## Decisions

### Empty-state storage

Use `FakeSettingsStorage` with `servers: []` for the no-servers message and with
one server for the no-accounts message. `AccountList` checks
`storage.box.get('servers')` when its item list is empty. Assert
`noServersConfigured` / `noAccounts`; assert the add-server button only in the
no-servers state.

### Filtering

Build a small list with two groups and matching/non-matching service/account
names. Test:

- `selectedGroup == 'All'` shows all non-deleted entries;
- a specific group shows only that group;
- `searchQuery` matches service or account case-insensitively;
- a query with no match shows `noResults`.

Always include one `deleted: true` entry and assert it never appears.

### Layout

Default test width (800) is single-column. Set the view width to 1000 for the
grid branch and assert `GridView`; reset the view size in `addTearDown`.

### Manage mode and editing

Pump with `isManageMode: true`, `selectedAccountIds: {1}` and callbacks. Tap the
checkbox and assert `onToggleAccountSelection(1)`. Tap the edit icon and assert
`onEditAccount` receives the entry. Borrowed entries have no checkbox/edit
action; assert that separately if needed.

### Refresh

Use a `RefreshIndicator` drag from a populated list and assert `onRefresh` was
called. `RefreshIndicator` needs a scrollable descendant and a drag of enough
distance.

### Timer cleanup

Every test that renders an `AccountTile` replaces the tree with
`const SizedBox()` and pumps before ending, as in the account-tile tests.

## Risks / Trade-offs

- **AccountTile timers** → replace the tree with `SizedBox` after assertions.
- **Empty-state storage lookup** → seed the fake box deliberately.
- **Refresh gesture** → use a drag from the top with enough offset; if flaky,
  call the callback through the refresh indicator's state instead.
- **Grid width** → set/reset `tester.view.physicalSize` explicitly.
- **Borrowed/manage behavior** → assert absence of the checkbox, not layout.
- **Error tile branch** → leave for a later defensive-path stage.

## Migration Plan

Not applicable: test-only change. Rollback is deleting the new test and
restoring the previous baseline.

## Open Questions

None that affect scope. Exact coverage will be measured after the test runs.

## Context

Pocket2FA uses a `_selectedGroup` string in `_HomePageState` (line 33, `home_screen.dart`) to track which group the user is filtering by. The default value is `'All'`. Every sync operation calls `HomeServerManager.loadServers()`, which calls `notifyListeners()`, which triggers `_onServerManagerChanged()` in the home screen, which unconditionally resets `_selectedGroup = 'All'`.

The current architecture:
- `HomeServerManager` (extends `ChangeNotifier`): owns server list, selected server, current items
- `HomeSyncManager` (extends `ChangeNotifier`): owns sync state
- `_HomePageState`: listens to both via `addListener` + `setState`
- Group filter is purely UI state in `_HomePageState` — not persisted, not in `HomeServerManager`

## Goals / Non-Goals

**Goals:**
- Preserve the user's selected group filter across all sync operations
- Fall back to "All" only when the selected group genuinely no longer exists in the data

**Non-Goals:**
- Persisting the group filter across app restarts
- Moving group filter state into `HomeServerManager` (unnecessary refactor for this fix)
- Adding group filter to the sync/load pipeline

## Decisions

### Decision 1: Remove the unconditional reset, add existence check

**Chosen approach:** In `_onServerManagerChanged()`, replace `_selectedGroup = 'All'` with a conditional that checks whether the currently selected group still exists in the available groups list. If it exists, keep it. If not, fall back to `'All'`.

```dart
void _onServerManagerChanged() {
  if (mounted) {
    setState(() {
      // Preserve the selected group if it still exists after sync;
      // only fall back to 'All' when the group was removed.
      final availableGroups = _serverManager.getGroups();
      if (!availableGroups.contains(_selectedGroup)) {
        _selectedGroup = 'All';
      }
    });
    _maybePerformInitialSync();
  }
}
```

**Alternatives considered:**

1. **Simply delete line 99** (`_selectedGroup = 'All'`): Simplest fix. The group filter persists across syncs. However, if the user had selected "Work" and all Work accounts were deleted during sync, they'd see an empty list with "Work" still selected — confusing. Rejected because it lacks the fallback.

2. **Move `_selectedGroup` into `HomeServerManager`**: More architecturally "correct" but touches many files (home_screen, home_server_manager, account_list) for a single-line bug fix. Over-engineering for this scope. Rejected.

3. **Reset only on server change, not on every `loadServers`**: The `_onServerManagerChanged` callback fires on every `notifyListeners()`, which includes server selection changes AND sync completions. We could differentiate, but `notifyListeners()` doesn't carry a reason. Adding a flag to `loadServers()` or `HomeServerManager` would add coupling. Rejected because the group existence check is simpler and more robust.

**Rationale for chosen approach:** It's a minimal, localized change (one block in one file) that satisfies both requirements: preserve the filter, and fall back gracefully when it becomes invalid. No changes to `HomeServerManager`, `HomeSyncManager`, or `AccountList`.

### Decision 2: Use `getGroups()` for the existence check

`HomeServerManager.getGroups()` (line 300) already computes available groups from `_currentItems`. It returns `['All', ...groupNames]`. Checking `availableGroups.contains(_selectedGroup)` is O(n) on group count (typically < 20 groups), which is negligible since this runs at most a few times per sync.

## Risks / Trade-offs

- **[Low] `_selectedGroup` may refer to a group by display name with count suffix** → `getGroupKey()` already handles stripping `" (N)"` suffixes in the UI layer. The `_selectedGroup` variable stores the raw group name (from `onSelected` in the PopupMenu), not the display string. Confirmed: line 698 sets `_selectedGroup = value` where `value` is the raw group name. Safe.
- **[Low] Sync that deletes the selected group followed by another sync before user interaction** → The fallback triggers on the first `_onServerManagerChanged` call. The second sync just reconfirms the fallback. No regression.
- **[None] Breaking changes** → None. This is purely a behavior fix.

## Migration Plan

1. Edit `_onServerManagerChanged()` in `lib/screens/home_screen.dart`
2. Test manually: select a group, trigger sync via button, verify filter persists
3. Test edge case: rename a group externally, sync, verify fallback to "All" works
4. Deploy as part of next release — no database migration, no API changes

Rollback: revert the three-line change to restore original behavior.

## Open Questions

None — the root cause is well-understood and the fix is straightforward.

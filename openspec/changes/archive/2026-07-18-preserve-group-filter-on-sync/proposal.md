## Why

When the user has an active group filter applied (e.g., "Work", "Personal"), every synchronization operation unconditionally resets the filter back to "All". This destroys the user's current view context and forces them to re-select the group after every sync — which is disruptive because syncs happen frequently (auto-sync timer, pull-to-refresh, app foreground, manual button, QR scan, manage-mode exit, server switch).

## What Changes

- Stop resetting `_selectedGroup` to `'All'` in `_onServerManagerChanged()` in `home_screen.dart`
- The group filter selection persists across sync operations so the user's view context is preserved
- Edge case: if the selected group no longer exists after sync (e.g., all its accounts were deleted), fall back to "All" gracefully

## Capabilities

### New Capabilities
- `group-filter-persistence`: The group filter selection survives synchronization operations without being reset

### Modified Capabilities
<!-- None: this is a bug fix, not a requirement change to existing capabilities -->

## Impact

- **Affected file:** `lib/screens/home_screen.dart` — remove or guard the `_selectedGroup = 'All'` assignment in `_onServerManagerChanged()`
- **No API changes**, no dependency changes, no breaking changes
- Low-risk: a single-line change with a defensive fallback for the edge case where the selected group disappears

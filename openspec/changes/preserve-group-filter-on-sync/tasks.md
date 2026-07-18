## 1. Implementation

- [ ] 1.1 In `lib/screens/home_screen.dart`, modify `_onServerManagerChanged()` to preserve `_selectedGroup` across sync operations: replace the unconditional `_selectedGroup = 'All'` with a guard that only resets to `'All'` when the currently selected group no longer exists in `_serverManager.getGroups()`

## 2. Verification

- [ ] 2.1 Manual test: select a non-"All" group, trigger a manual sync via the sync button, confirm the filter remains on the selected group after sync completes
- [ ] 2.2 Manual test: select a non-"All" group, perform pull-to-refresh, confirm the filter remains
- [ ] 2.3 Manual test: select a non-"All" group, trigger a sync via QR scan or server switch, confirm the filter remains
- [ ] 2.4 Manual test: select a group, have all its accounts removed during a sync (e.g., via external API), trigger another sync, confirm the filter gracefully falls back to "All"

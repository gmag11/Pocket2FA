# Tasks

## 1. Make new entries local-first

- [x] 1.1 In `lib/models/account_entry.dart`, restore `counter` propagation in `copyWith` and add a merge operation that copies a server record over a local record while retaining the local `seed`, `otpType`, `digits`, `algorithm`, `period`, `counter`, `localIcon`, and non-empty group when the server value is missing. Verify with `flutter analyze` and a manual HOTP create/edit that the counter survives every `copyWith`.
- [x] 1.2 In `lib/screens/home_server_manager.dart`, add a creation-specific insert operation: replace by positive server id when present, append a positive server id that is not cached, and assign a unique negative id to local-only entries. Rebuild `currentItems`, notify listeners, and await persistence. Verify by creating an entry with the server stopped and confirming it is present in `getSelectedServer().accounts` immediately and after `loadServers()`.
- [x] 1.3 Normalize duplicated non-positive ids when loading stored servers, assigning distinct negative ids while leaving a single `-1` untouched. Verify by injecting two stored pending accounts with `id: -1`, restarting, and confirming both are listed and selectable separately.
- [x] 1.4 In `lib/screens/home_screen.dart`, route creation results through the new insert operation instead of `updateAccount`, and keep the existing post-creation snackbar. Verify an online create appears before the background sync completes and an offline create appears with the pending badge.
- [x] 1.5 After inserting a created account, trigger an immediate pending upload through the sync manager instead of relying on `forceSyncCurrentServer`. Verify with a server stopped at creation time that the entry remains visible, and with a reachable server that it reconciles without waiting for a full sync.

## 2. Make pending uploads correct and durable

- [x] 2.1 In `lib/services/sync_service.dart`, change pending detection from `id == -1` to `id <= 0 && !synchronized && !deleted`, and expose a public operation that uploads pending accounts only (no groups/accounts fetch) and returns the number uploaded. Verify `flutter analyze` and confirm the operation performs no `GET` requests in the debug log.
- [x] 2.2 Rework `_uploadPendingAccounts` to keep a mutable working account list, replace each successful upload by its temporary id, persist after every success, and return the count. Verify with a mocked/debug log scenario or a server that accepts the first account and rejects the second, then restart and confirm the first is synchronized and the second is still pending.
- [x] 2.3 Use the merge operation from 1.1 in both `_uploadPendingAccounts` and `_updatePendingAccounts` so a response that omits `secret` or OTP parameters does not erase them; preserve `localIcon` and resolve the group name as today. Verify that a pending account keeps generating the same code immediately after upload and after an app restart without a full sync.
- [x] 2.4 In `lib/services/entry_creation_service.dart`, apply the same merge to `createEntryOnServer` results so a successful immediate create keeps the local secret and parameters when the response omits them. Verify an online QR/create shows the same code before and after the response.
- [x] 2.5 In `lib/services/api_service.dart`, send `entry.counter ?? entry.period` as `counter` for HOTP in `createAccountFromEntry`. Verify a pending HOTP account uploads with its local counter and the server record retains it.
- [x] 2.6 In `SyncService.forceSync`, after fetching accounts and applying the pending-delete filter, append stored accounts that are still unsynchronized and not deleted and whose id is not in the fetched list. Verify that a full sync while the create endpoint fails but the read endpoint works keeps the pending account visible and marked for upload.
- [x] 2.7 In `lib/screens/home_manage_mode.dart`, remove accounts with non-positive ids locally instead of marking them deleted, and only send positive ids to `DELETE /twofaccounts`. In `SyncService._deletePendingAccounts`, purge legacy `deleted && !synchronized && id <= 0` tombstones. Verify deleting a pending account makes it disappear without a delete request and it stays gone after restart and sync.

## 3. Schedule automatic pending-upload retries

- [x] 3.1 In `lib/screens/home_sync_manager.dart`, add a pending-upload retry loop with 5 s, 15 s, 30 s, and 60 s backoff, an in-flight guard, and cancellation when no pending entries remain. Ensure only one timer exists at a time. Verify by creating offline entries, restoring the server, and observing uploads complete without manual sync.
- [x] 3.2 Add pause/resume of pending retries for manage mode, and cancel the timer in `dispose`; call `dispose` from `HomePage.dispose` if it is not already called. Verify entering manage mode stops retries and leaving it performs the existing forced sync.
- [x] 3.3 In `lib/screens/home_screen.dart`, start pending uploads after servers load and on foreground resume whenever pending entries exist, even when `syncOnOpen` is disabled. Verify with sync-on-open and auto-sync disabled that an offline-created account uploads after resume once the server is reachable.
- [x] 3.4 After a successful pending upload or a forced sync, reload servers from storage so reconciled entries lose the pending badge, and cancel the timer if nothing remains. Verify the list updates in place without a manual refresh and the pending badge disappears.

## 4. Integration verification

- [x] 4.1 Run `flutter analyze` and confirm no new warnings or errors.
- [x] 4.2 Build and smoke-test Android (`flutter build apk --debug`) and, where available, Linux and Windows. Verify account creation works on each target.
- [x] 4.3 Offline matrix: create TOTP and HOTP entries with the server unreachable, confirm immediate display, correct codes, pending badge, persistence after restart, and no lost entries.
- [x] 4.4 Online matrix: with the server reachable from the start, create entries and confirm they appear immediately, reconcile once, and do not duplicate after a full sync.
- [x] 4.5 Reconnection matrix: create several entries while offline, restore connectivity with sync-on-open and auto-sync disabled, and confirm all pending entries upload automatically within the retry window and the badges disappear.
- [x] 4.6 Deletion matrix: delete a pending local-only entry and confirm no server request is made and it does not return after restart or sync.
- [x] 4.7 Regression checks: borrowed accounts still fetch codes from the server, synced account editing still updates by server id, and the existing group filter/search behavior is unchanged.
- [x] 4.8 Confirm no dependency was added to `pubspec.yaml`/`pubspec.lock` and that the diff contains only the files named in the proposal's Impact section (plus OpenSpec artifacts).

## Workflow follow-up

- Run `openspec validate add-offline-first-entry-creation --strict` after implementation.
- Archive the change once review and acceptance verification are complete.

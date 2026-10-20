# Tasks

## 1. Remove the edit affordance

- [x] 1.1 In `lib/screens/account_list.dart`, stop forwarding `onEditAccount` and `onToggleAccountSelection` for entries with `isBorrowed == true`; verify with `flutter analyze` that both list builders compile
- [x] 1.2 In `lib/widgets/account_tile_totp.dart` and `lib/widgets/account_tile_hotp.dart`, render the manage-mode edit button only when `onEdit != null`; verify a borrowed tile has no edit icon and an owned tile still shows it in manage mode
- [x] 1.3 In both tile variants, omit the manage-mode selection checkbox for borrowed accounts and keep the avatar/username alignment correct; verify a borrowed tile shows no selector while owned tiles still do

## 2. Prevent deletion

- [x] 2.1 In `lib/screens/home_manage_mode.dart`, ignore borrowed accounts when building the deletion set and when toggling selection; verify a selection containing a borrowed id only marks owned accounts
- [x] 2.2 In `lib/services/sync_service.dart`, exclude borrowed accounts from pending-delete filtering and from `_deletePendingAccounts`; verify a stale borrowed tombstone is not sent to the API and is restored by the next sync

## 3. Defensive edit guards

- [x] 3.1 In `lib/screens/home_screen.dart`, return early from `_editAccount` when `account.isBorrowed` (no navigation); verify by attempting to invoke the edit flow for a borrowed account and observing that no route is pushed
- [x] 3.2 In `lib/screens/advanced_form_screen.dart`, prevent the edit form from accepting `existingEntry?.isBorrowed == true` (render no editable form or pop) so no local unsynced copy can be produced; verify the form cannot be reached with a borrowed entry

## 4. Shared-account indicator

- [x] 4.1 Add a `sharedAccount` tooltip key to `lib/l10n/app_en.arb`, `app_es.arb` and `app_fr.arb`, then run `flutter gen-l10n` and verify the generated getter exists
- [x] 4.2 Add `AccountTileUi.buildSharedIndicator` and place it immediately before the username in `account_tile_totp.dart` and in both manage/normal UIs of `account_tile_hotp.dart`; verify it appears for borrowed accounts only

## 5. Verification

- [x] 5.1 Run `flutter analyze lib/` and confirm no new issues
- [x] 5.2 On a device with a 2FAuth instance with Sharing enabled: a borrowed account shows the shared icon next to its username, cannot be selected or deleted in manage mode, and shows no edit action, while owned accounts keep all three capabilities
- [x] 5.3 Restart the app and repeat 5.2 to confirm the guards and indicator still apply to borrowed accounts loaded from local storage

## Workflow follow-up

- Archive the change after implementation and device verification are complete.

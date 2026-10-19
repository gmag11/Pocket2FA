# Proposal

## Why

Accounts shared with the authenticated user through 2FAuth can currently be opened in the edit form and deleted from manage mode, although 2FAuth authorizes both operations only for the owner (`TwoFAccountPolicy`). Editing silently fails on the server and the client falls back to an "unsynced" local entry that is overwritten by the next sync; deleting marks a local tombstone whose server delete keeps failing with 403. Additionally, nothing in the UI distinguishes a borrowed account from an owned one, so the user cannot tell why such actions should not be available.

## What Changes

- Treat borrowed accounts (`is_borrowed` / `AccountEntry.isBorrowed`) as read-only in the client.
- Do not render the edit action for a borrowed account in manage mode (TOTP and HOTP tiles).
- Do not open the edit form for a borrowed account, even if an edit is requested through another code path; guard the navigation entry point and the form itself.
- Do not allow a borrowed account to be selected for deletion, and exclude it from bulk deletion if it is somehow selected.
- Ignore and clean up any stale local pending-delete marker for a borrowed account so sync does not retry a deletion the server will always reject.
- Show an icon immediately to the left of the account username to indicate that the account is shared with the user.
- Keep owned accounts fully editable and deletable exactly as today.
- Do **not** offer partial editing of service, account or group: the server does not accept any update to a borrowed account, so a local-only subset would still be unsynced and misleading.

## Capabilities

### New Capabilities

- `shared-account-readonly`: borrowed accounts are presented and treated as read-only and are visually identified as shared, with no path into the edit form or the deletion flow.

### Modified Capabilities

<!-- None: owned-account editing and shared-account OTP retrieval are unchanged. -->

## Impact

- **Affected code:** `lib/screens/account_list.dart` (no edit callback and no selectable deletion for borrowed accounts), `lib/widgets/account_tile_totp.dart` / `lib/widgets/account_tile_hotp.dart` (no edit control, shared indicator), `lib/widgets/account_tile_ui.dart` (shared indicator widget), `lib/screens/home_manage_mode.dart` (deletion guards), `lib/services/sync_service.dart` (ignore stale pending deletions of borrowed accounts), `lib/screens/home_screen.dart` and `lib/screens/advanced_form_screen.dart` (defensive guards), plus `lib/l10n/app_{en,es,fr}.arb` for the indicator tooltip.
- **Depends on:** the `isBorrowed` flag and its persistence introduced by `fix-shared-account-otp`; without that flag the client cannot distinguish borrowed accounts.
- **Server dependency:** none. The change mirrors the server's existing authorization rules instead of adding new requests.
- **No new dependencies**, no storage migration, no breaking changes.

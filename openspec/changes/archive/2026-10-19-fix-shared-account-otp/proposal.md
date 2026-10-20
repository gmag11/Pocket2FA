# Proposal

## Why

Accounts shared with the authenticated user through the 2FAuth Sharing feature sync **without their secret**, so Pocket2FA generates every shared TOTP locally from an empty seed and shows the same, incorrect code for all of them. Only accounts shared with me are affected; owned accounts keep working (GitHub issue #18).

## What Changes

- Parse the `is_borrowed` and `shared_by` properties returned by `GET /twofaccounts` into `AccountEntry` so the client can identify accounts shared with the user.
- For TOTP accounts that have no locally available secret (shared/borrowed accounts), do **not** generate the code from the empty seed. Instead, request the current and next code from the server via `GET /twofaccounts/{id}/otp` and schedule the next refresh at the next period boundary derived from the server-reported `generated_at` and `period` (`generated_at - generated_at % period + period`). The server reports the generation instant, not the start of the period, so using `generated_at + period` would keep the code one period behind.
- Fix `ApiService.fetchAccountOtp` so the `next_password` field is parsed correctly (it currently reads `nextPassword`, so `next_password` is always `null`).
- Keep owned accounts (those with a secret) computing OTP locally and offline exactly as today.

## Capabilities

### New Capabilities
- `shared-account-otp`: Correct codes for accounts shared with the user, obtained from the server's One-Time Password endpoint and refreshed on the server-reported period.

### Modified Capabilities
<!-- None: existing capabilities (local OTP generation for owned accounts) are unchanged. -->

## Impact

- **Affected code:** `lib/models/account_entry.dart` (parse sharing flags), `lib/services/api_service.dart` (fix `next_password` parsing), `lib/widgets/account_tile_otp_service.dart` (server-backed refresh for shared TOTP accounts). Possibly `lib/models/server_connection.dart`/`lib/services/sync_service.dart` if the new fields need to round-trip through storage.
- **Server dependency:** requires the 2FAuth instance to have the Sharing feature enabled; for instances without it, nothing changes.
- **No new dependencies**, no database migration, no breaking changes. Offline behavior for shared accounts degrades to the last known code / "offline" state, consistent with how HOTP is already handled.

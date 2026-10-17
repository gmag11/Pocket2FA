# Design

## Context

See `proposal.md` - Why. The relevant current state:

- `lib/services/sync_service.dart:145` fetches `GET /twofaccounts?withSecret=true` and maps every returned entry through `AccountEntry.fromMap`.
- For accounts shared with the user, 2FAuth does **not** include `secret` (see the *"account shared with me"* example in `2FAuth-API/2fauth-api-latest.yaml:105`), so `AccountEntry.seed` is empty for all of them.
- `AccountTileOtpService.refreshCodes()` (`lib/widgets/account_tile_otp_service.dart:46`) computes TOTP locally via `OtpService.generateOtp(acct, ...)`. With an empty seed the HMAC key is identical for every account, producing the same wrong code for all shared accounts.
- `ApiService.fetchAccountOtp()` (`lib/services/api_service.dart:453`) already calls `GET /twofaccounts/{id}/otp`, which the API explicitly supports for accounts "shared with him" (`2fauth-api-latest.yaml:440`). It is currently used only for the manual HOTP flow.
- `ApiService` is configured for the currently selected server (`home_server_manager.dart:132,169`), so tile-level requests target the right instance.

Constraints: shared-account secrets are never available, so correct codes require the server. Offline correctness for shared accounts is therefore impossible by design; only owned accounts can be computed offline.

## Goals / Non-Goals

**Goals**

- Shared accounts produce their real, per-account codes.
- Codes advance in step with the server's periods.
- Owned accounts are untouched (still local/offline).
- The client can tell which accounts are shared (persisted across restarts).

**Non-Goals**

- Creating or managing shares (recipients, scopes) from the client.
- A visual "shared by" badge or any UI redesign.
- Blocking edit/delete of borrowed accounts (server already enforces with 403).
- Server-side push/polling optimizations or code caching shared across accounts.

## Decisions

### Decision 1: Signal shared accounts by parsed `is_borrowed` plus an empty secret

`AccountEntry` gains `isBorrowed` (bool) and `sharedBy` (String?). They are parsed from `is_borrowed`/`shared_by` and included in `toMap()` so they round-trip through local storage. The server OTP path is chosen when the account has no local secret — `isBorrowed || seed.trim().isEmpty` — and the type is not HOTP.

**Why the empty-secret fallback:** relying only on `is_borrowed` couples us to a server property that is absent on older servers or when sharing is disabled; an owned account never legitimately has an empty secret, so the fallback is safe and also covers the reported symptom directly.

**Alternative considered:** detect only by `seed.isEmpty`. Simpler, but loses the `shared_by` metadata the proposal promises to preserve. Rejected.

### Decision 2: Fetch the code from `GET /twofaccounts/{id}/otp` for shared accounts

For a shared TOTP/STEAM account, `refreshCodes()` delegates to a new server-backed path that reuses `ApiService.fetchAccountOtp()`. The response's `password` becomes the current code and `next_password` the next code.

`fetchAccountOtp` is extended and fixed to also return `otp_type`, `period` and `generated_at`, and to actually read `next_password` (today it tests for `next_password` but reads `nextPassword`, so the next code is always null).

**Alternative considered:** cache one decrypted "server-derived secret". Impossible — the server never reveals it.

### Decision 3: Schedule refresh at the server-reported boundary, with epoch fallback

After a successful fetch, the next refresh is scheduled at `generated_at + period`. If that instant is already in the past (client clock ahead of server) or implausibly far, fall back to the epoch-aligned boundary (`period - nowMs % periodMs`), which is the same alignment the local TOTP path already uses. A small epsilon (+250 ms) avoids re-fetching the expiring code.

### Decision 4: Graceful degradation to an "offline" state

On any failure (network, 4xx/5xx, invalid shape), the shared tile shows the existing `offline` sentinel instead of a code. `AccountTileUtils.formatCode` and the copy handlers already special-case `offline`. A retry is scheduled (short backoff, capped at the period) so the tile recovers when connectivity returns.

## Risks / Trade-offs

- **Extra server load** → one `GET /otp` per shared account per period while its tile is built. Mitigation: only shared non-HOTP accounts take this path; requests are serialized per tile by cancelling the pending timer, and scheduling never fires faster than the period.
- **Clock skew between client and server** → mitigate by clamping the computed delay and falling back to epoch alignment when it is out of range.
- **Shared accounts cannot work offline** → inherent to the 2FAuth sharing model (no secret). The tile degrades to `offline` rather than showing a wrong code; documented as expected behavior in the spec.
- **Repeated failures causing a request loop** → the timer is always rescheduled (never a tight loop) with a minimum delay of ~30 s on failure.

## Migration Plan

1. Extend `AccountEntry` (`is_borrowed`/`shared_by` parse + round-trip). Old stored data simply lacks the keys and defaults to `false`/`null`; no migration needed.
2. Fix/extend `ApiService.fetchAccountOtp`.
3. Add the server-backed branch to `AccountTileOtpService.refreshCodes()`.
4. Verify with a real 2FAuth instance that has Sharing enabled: two accounts shared with the user must show two different, correct codes, and owned accounts must still work offline.

Rollback: revert the three files; stored accounts with the extra keys are still readable because parsing is key-tolerant.

## Open Questions

None.

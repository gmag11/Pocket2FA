# Proposal

## Why

The corrected coverage baseline is 15.62% over all non-generated `lib/` files.
Two high-value modules remain mostly unmeasured:

- `lib/services/entry_creation_service.dart`: 0 of 105 executable lines covered.
  It parses untrusted QR content, builds entries and decides whether a create
  request can be merged back into local state.
- `lib/widgets/account_tile_otp_service.dart`: 46 of 124 executable lines
  covered. Local TOTP/Steam refresh, server-backed borrowed accounts, retries
  and HOTP request handling are untested.

These are the next small stage after the API service tests and before the much
larger `sync_service.dart`.

## What Changes

- Add unit tests for `EntryCreationService.parseOtpAuthUrl`: TOTP and HOTP
  parsing, issuer/label/group rules, Base32 secret validation, defaults and
  invalid input.
- Add unit tests for `EntryCreationService.buildManualEntry` and
  `isValidBase32`, including colon replacement and period/counter selection.
- Add unit tests for `EntryCreationService.createEntryOnServer`: payload shape
  for TOTP and HOTP, group-id/name merging, empty host short-circuit and
  failure fallback to the local entry.
- Add unit tests for `AccountTileOtpService`: local TOTP and Steam generation,
  borrowed/empty-seed server routing, offline and retry states, server refresh
  scheduling, HOTP success/error handling and timer disposal.
- Add one small widget test for the invalid-QR SnackBar, because that branch
  needs a mounted `BuildContext` and localized text; keep it in its own file so
  the unit tests do not need the Flutter test binding.
- Keep the coverage import test in sync and raise `.coverage-baseline` to the
  measured overall value after the stage.

No production code, dependencies or public behavior changes.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

None. This is test-only work; the change declares `skip_specs: true`.

## Impact

- New tests under `test/unit/services/`, `test/unit/widgets/` and
  `test/widget/`.
- Existing `test/unit/services/shared_account_otp_test.dart` keeps its routing
  smoke tests; new coverage goes in focused files.
- `.coverage-baseline` rises from 15.62 to the measured value (expected around
  18.5%, not guaranteed).
- No `lib/` changes, so the release APK and Android install are unaffected.

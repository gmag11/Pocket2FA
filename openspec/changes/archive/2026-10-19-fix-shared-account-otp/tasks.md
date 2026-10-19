# Tasks

## 1. Model: identify shared accounts

- [x] 1.1 In `lib/models/account_entry.dart`, add `isBorrowed` (bool, default false) and `sharedBy` (String?) fields, parse them in `fromMap` from `is_borrowed`/`shared_by`, emit them in `toMap`, and thread them through `copyWith`
- [x] 1.2 Confirm the new keys round-trip through `ServerConnection.toMap`/`fromMap` and that neither `createAccountFromEntry` nor `updateAccountFromEntry` send them to the server

## 2. API: server OTP retrieval

- [x] 2.1 In `lib/services/api_service.dart`, fix `fetchAccountOtp` so `next_password` is parsed from either `next_password` or `nextPassword`
- [x] 2.2 Extend the returned map with `otp_type`, `period` and `generated_at` (nullable, best-effort parsing) for scheduling

## 3. Tile: server-backed codes for shared accounts

- [x] 3.1 In `lib/widgets/account_tile_otp_service.dart`, add a `_requiresServerCode` check (`isBorrowed || seed.isEmpty`, type not `hotp`) and route those accounts to a new `_refreshFromServer()` instead of local generation
- [x] 3.2 Implement `_refreshFromServer()`: fetch the OTP, set `currentCode`/`nextCode`, schedule the next fetch at the server-reported period boundary (corrected in 3.5), and fire `startAnimationCallback`
- [x] 3.3 On failure, set `currentCode` to the `offline` sentinel (never a locally-derived code), clear `nextCode`, and schedule a bounded retry
- [x] 3.4 Guard against scheduling work after `dispose()` and against overlapping requests
- [x] 3.5 Fix refresh scheduling found during device testing: `generated_at` is the code generation instant (not the period start), so schedule at the next period boundary (`periodMs - generated_at_ms % periodMs`) instead of `generated_at + period`; fall back to client epoch alignment when `generated_at` is missing

## 4. Verification

- [x] 4.1 `flutter analyze` passes with no new issues for the modified `lib/` files (the dormant test file left in `test/` reports one `depend_on_referenced_packages` info until test infrastructure is added)
- [x] 4.2 With a 2FAuth instance that has Sharing enabled: two accounts shared with the user display two different codes, each matching the web UI, and the next code matches too
- [x] 4.3 Owned TOTP accounts still generate locally and work in airplane mode (unchanged)
- [x] 4.4 Stop the server / enable airplane mode: shared tiles show the `offline` indication (not a wrong code) and recover once connectivity returns
- [x] 4.5 Restart the app: shared accounts are still recognised as borrowed after loading from local storage

## 5. Test artifact (infrastructure deferred)

- [x] 5.1 Leave `test/shared_account_otp_test.dart` in the repo covering model parsing/round-trip, the empty-seed root cause, and tile routing (8 cases, verified green with `flutter_test` temporarily declared)

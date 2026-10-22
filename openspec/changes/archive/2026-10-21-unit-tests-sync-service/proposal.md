# Proposal

## Why

The corrected coverage baseline is 19.15% over all non-generated `lib/` files.
`lib/services/sync_service.dart` is now the largest completely untested module:
0 of 343 executable lines. It decides when a server sync is throttled, pushes
pending creates/edits/deletes, downloads and persists server accounts, and
preserves local-only work when the network fails.

These are the most failure-prone paths in the app, and a regression can lose
accounts or overwrite local edits. Testing them is the highest-value next stage
after the API, settings, entry-creation and OTP modules.

## What Changes

- Add `test/unit/services/sync_service_test.dart` covering `syncIfNeeded`:
  throttle skip, forced-sync override, corrupt/missing timestamps, locked
  storage and result propagation.
- Cover `forceSync` happy paths: pending mutations, group and account fetches,
  group-name mapping, persistence into the actual server entry, last-sync keys
  and the success summary.
- Cover failure and merge paths: groups/accounts request failures, network
  failure without overwriting cached accounts, pending-delete filtering,
  keeping local-only pending creates, malformed or locked storage and icon
  download cancellation.
- Cover the pending mutation paths reached through `forceSync` and
  `uploadPendingAccounts`: delete tombstones, local-only tombstone purge,
  create with/without server id, update with group-name/local-icon retention,
  API failures and missing server entries.
- Keep the coverage import test in sync and raise `.coverage-baseline` to the
  measured overall value after the stage.

No production code, dependencies or public behavior changes.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

None. This is test-only work; the change declares `skip_specs: true`.

## Impact

- New test file `test/unit/services/sync_service_test.dart`.
- Reuses `ApiTestHarness`, `FakeSettingsStorage` and the existing
  `ServerConnection` fixture; no new test dependencies.
- `.coverage-baseline` rises from 19.15 to the measured value (expected around
  24-26%, not guaranteed).
- No `lib/` changes, so the release APK and Android install are unaffected.
- Icon *download success* paths and `icon_cache_service.dart` remain out of
  scope; this stage covers the no-icon and cancelled-icon sync paths.

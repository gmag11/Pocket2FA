# Proposal

## Why

Two image-intake services remain almost entirely uncovered:

- `icon_cache_service.dart` (55 executable lines, 0%)
- `incoming_image_processor.dart` (52 lines, 5.5%)

They cover icon caching and the pure parts of shared/dropped image handling.
Both can be tested with a temporary app-support directory, a local HTTP server
and a widget context for the early no-server branch, without touching the
camera or QR decoder plugins.

## What Changes

- Add tests for `IconCacheService`:
  - cache hit from a pre-seeded temporary file;
  - file-name and server-id sanitization;
  - `getIconFile`, `evict` and `clearAll`;
  - the application-support path-provider channel mock.
- Add tests for `IncomingImageProcessor`:
  - descriptor parsing and rejection;
  - localized rejection/failure messages;
  - working-copy deletion;
  - the early server-missing branch.
- Raise `.coverage-baseline` to the measured overall value after the stage.

No production code, dependencies or public behavior changes.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

None. This is test-only work; the change declares `skip_specs: true`.

## Impact

- New tests under `test/unit/services/`.
- Uses `HttpServer` from `dart:io` and the existing path-provider channel mock.
- `.coverage-baseline` rises from 61.94 to the measured value (expected around
  63-64%, not guaranteed).
- No `lib/` changes, so the release APK and Android install are unaffected.
- The HTTP download branch is deferred because Flutter's test binding answers
  every `HttpClient` request with 400; the cache read/path lifecycle is covered
  here.
- QR decoding and the full process flow remain for a later stage because they
  need the native decoder plugin.

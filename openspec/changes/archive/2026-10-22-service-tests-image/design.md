# Design

## Context

See `proposal.md` - Why. `IconCacheService` resolves the app-support directory
through `path_provider`, sanitizes ids/file names, reads existing files, creates
the icons directory, downloads with a fresh `Dio`, writes bytes and supports
evict/clear. `IncomingImageProcessor` has a pure descriptor/message layer plus a
`process` method that returns server-missing before reaching the QR decoder.

## Goals / Non-Goals

**Goals:**

- Cover the cache read/path/evict/clear lifecycle with real temporary files.
- Cover descriptor/message/delete helpers and the server-missing branch.
- Keep the QR decoder, camera plugins and HTTP client out of the tests.

**Non-Goals:**

- Downloading an icon over HTTP: Flutter's test binding intercepts every
  `HttpClient` and returns 400, so the download branch is deferred.
- Decoding real QR images.
- The full `process` success/failure flow (decoder plugin).
- Self-signed TLS behavior.

## Decisions

### Mock the path-provider channel

Install a handler for `plugins.flutter.io/path_provider` returning a temporary
directory for `getApplicationSupportDirectory`. Reset it and delete the
directory in teardown. This is the same channel pattern as `log_service_test`.

### Pre-seed the cache

Use `getIconFile` to resolve the sanitized path, create the parent directory and
write known bytes. `getIconBytes` should return those bytes without a download.
A second call exercises the same cache-hit path. No HTTP client is created.

### Cache lifecycle

Call `getIconFile` to assert the expected sanitized path, `evict` to remove it,
and `clearAll` to remove the icons directory. Call both again when the files are
already absent to cover the harmless no-op paths.

### Incoming descriptors and messages

Use `IncomingImageDescriptor.fromMap` for image and rejected maps. Instantiate
`AppLocalizationsEn` directly and assert every `incomingRejectionMessage` and
`incomingFailureMessage` branch; `invalidQr` must return null.

### Working-copy deletion and server-missing

Create a temp file, call `deleteIncomingWorkingCopy`, assert it is gone, then
call it with null/empty/missing paths. For `process`, pump a `Builder` context
and call with `serverHost: ''`; assert `serverMissing` and that no decoder is
reached.

## Risks / Trade-offs

- **Flutter test HTTP interception** → pre-seed cache files instead of
  downloading; leave `_downloadIcon` for a separate HTTP-adapter seam.
- **path_provider channel is global** → set/reset it around each test.
- **Temporary files** → create/delete a unique directory per test.
- **QR decoder** → never call `process` with a non-empty server host.
- **Localizations** → use the English generated class directly; no widget tree
  is needed for the helper functions.

## Migration Plan

Not applicable: test-only change. Rollback is deleting the new tests and
restoring the previous baseline.

## Open Questions

None that affect scope. Exact coverage will be measured after the tests run.

# Tasks

## 1. Test harness and fixtures

- [x] 1.1 Add a `test/helpers/fixtures/server_connection_fixture.dart` builder for `ServerConnection` with required defaults and optional URL/API key/self-signed overrides; verify `flutter analyze` reports no issues.
- [x] 1.2 Add a recording interceptor helper that captures `RequestOptions` and a `DioAdapter` factory using `UrlRequestMatcher`; verify the helper is exercised by the first API test.

## 2. Server lifecycle

- [x] 2.1 Test `isReady`, first `setServer`, same-server short-circuit, server switch, trailing-slash trimming, and `close`; verify each assertion passes in the new API test file.
- [x] 2.2 Test the `Authorization` header with and without an API key, the self-signed adapter branch, and the `addInterceptor`/`interceptors` guard when no server is configured; verify the tests pass.

## 3. Request methods

- [x] 3.1 Test `fetchAccountOtp` success (snake_case and camelCase `next_password`, string counters), missing password, non-map body, non-200 status, and invalid ids; verify the tests pass.
- [x] 3.2 Test `createAccount` 201 success, unexpected status, null/non-map data, and transport error; verify the tests pass.
- [x] 3.3 Test `createAccountFromEntry` payloads for TOTP, HOTP (counter fallback), group presence/absence, optional fields, and error propagation; verify the tests pass.
- [x] 3.4 Test `deleteAccounts` empty-list short-circuit, 204 success, unexpected status, and transport error; verify the tests pass.
- [x] 3.5 Test `updateAccountFromEntry` TOTP and HOTP bodies, defaults, group/icon fields, missing server id, unexpected status, and transport error; verify the tests pass.
- [x] 3.6 Test `downloadIcon` byte response, URL-encoded file names, and non-200 status; verify the tests pass.
- [x] 3.7 Test `validateServer` success, non-200, and non-map responses against a loopback `HttpServer`; verify the server closes in `tearDown`.

## 4. Error messages and log redaction

- [x] 4.1 Test `friendlyErrorMessageFromDio` for 400 with map/string detail, 401, 403, 404, 405, 5xx, other statuses, timeouts, cancellation, bad response, socket errors, and the fallback message; verify every branch is asserted.
- [x] 4.2 Test `friendlyErrorMessage` for `DioException`, `StateError`, and a generic exception; verify the tests pass.
- [x] 4.3 Test that request/response logs redact `secret`, `seed`, `apiKey`, `account`, and `service` while keeping the rest of the payload; verify captured `LogService` entries contain no raw sensitive value.

## 5. Verification and coverage ratchet

- [x] 5.1 Run `dart format` on the new/changed test files and verify `flutter analyze` reports no issues.
- [x] 5.2 Run `flutter test --coverage`, verify the new API tests and the full suite pass, then run `dart run tool/check_coverage.dart` and raise `.coverage-baseline` to the measured overall percentage without lowering it.

## Workflow follow-up

- Archive the change after the coverage ratchet and the full suite pass.

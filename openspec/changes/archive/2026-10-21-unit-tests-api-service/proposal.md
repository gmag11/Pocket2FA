# Proposal

## Why

`ApiService` is the only path between the app and a 2FAuth server, and it is
almost entirely untested: 310 measurable lines with only 7 covered (2.3%).
Every regression here is user-visible and hard to diagnose: a wrong payload
field breaks account creation, an unparsed OTP shape shows `------`, and a
misleading error message sends users to fix the wrong thing (URL, API key or
network). Because the service also logs request data, an unmasked secret would
leak into the diagnostic log.

The class already exposes enough seams to test it without a device or a real
server: a public `dio` accessor, public request wrappers, and the
`http_mock_adapter` dependency that is declared but still unused.

## What Changes

- Add `test/unit/services/api_service_test.dart` covering:
  - server lifecycle: `isReady`, first configuration, re-selecting the same
    server without recreating Dio, switching servers, trailing-slash trimming,
    authorization header presence, `close`, and the `addInterceptor` /
    `interceptors` guards;
  - `validateServer`: successful `GET /api/v1/user` against a loopback-only
    `HttpServer`, plus non-200 and non-map responses;
  - `fetchAccountOtp`: full payload, snake_case and camelCase `next_password`,
    string counters, missing `password`, non-map data, non-200, and invalid ids;
  - `createAccount` and `createAccountFromEntry`: 201 success, non-201 errors,
    TOTP/HOTP payload shapes, optional fields, and group handling;
  - `deleteAccounts`: empty list short-circuit, 204 success, unexpected status,
    and transport errors;
  - `updateAccountFromEntry`: TOTP and HOTP bodies, defaults, group/icon fields,
    missing server id, unexpected status, and transport errors;
  - `downloadIcon`: byte response, URL encoding, and non-200 status;
  - `friendlyErrorMessageFromDio` / `friendlyErrorMessage`: HTTP status detail,
    timeouts, cancellation, socket errors and fallbacks;
  - log redaction of `secret`, `seed`, `apiKey`, `account` and `service`.
- Add test-only helpers to drive Dio through `http_mock_adapter` and to create
  `ServerConnection` fixtures.
- Raise `.coverage-baseline` to the measured overall percentage (expected
  around 65%) after the new tests pass.

No production code changes, no new dependencies, and no widget or device tests.

## Capabilities

### New Capabilities

None. This change only adds tests; no system behavior changes, so it declares
`skip_specs: true`.

### Modified Capabilities

None.

## Impact

- New tests under `test/unit/services/` (`api_service_test.dart` and
  `api_service_log_test.dart`) plus fixture helpers under `test/helpers/fixtures/`.
- `.coverage-baseline` pinned at 70.0 once overall coverage reached the target.
- Local loopback sockets are used only by the `validateServer` tests; no
  external network, device or platform channel is involved.
- No changes to `lib/`, `pubspec.yaml` or CI workflows.

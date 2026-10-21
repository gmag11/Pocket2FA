# Design

## Context

See `proposal.md` for the motivation. `ApiService` is a singleton that creates
its own `Dio` in `setServer`, and every request method goes through that
instance. The class exposes a public `dio` getter, but it does not accept an
adapter or a Dio factory, and `validateServer` builds a throwaway `Dio` that
the test cannot reach.

`http_mock_adapter` is already a declared dev dependency, and
`ApiService.instance.close()` already resets both the Dio instance and the
server, so the tests can isolate the singleton without touching production
code.

## Goals / Non-Goals

**Goals:**

- Exercise every public request method and every error branch that is reachable
  without a real 2FAuth server.
- Assert the actual request payloads, not only that the method returns a value.
- Verify that secrets and account identifiers are redacted from diagnostic
  logs.
- Keep the suite deterministic, offline and fast enough for `flutter test`.

**Non-Goals:**

- Refactoring `ApiService` for dependency injection.
- Testing the 2FAuth server itself, TLS certificate handling, or real
  connection timeouts.
- Adding widget or integration tests for the screens that call `ApiService`.

## Decisions

### Mock responses through the public `dio` accessor

`setServer` must run first so the singleton is configured. The test then
replaces `ApiService.instance.dio.httpClientAdapter` with a `DioAdapter`
configured with `UrlRequestMatcher`, which matches the relative path and the
method while ignoring headers and body. A recording `InterceptorsWrapper`
added to the same Dio captures each `RequestOptions`, so tests can assert the
exact body, query parameters and path without duplicating request fixtures in
the matcher.

Alternatives considered:

- **Local HTTP server for every test.** This exercises the full transport and
  needs no adapter, but it makes each test slower, requires a routing handler,
  and turns payload assertions into JSON parsing. Reserve loopback for
  `validateServer`, where the production code hides the Dio instance.
- **Hand-written `HttpClientAdapter`.** It would record requests directly, but
  reimplements response construction that `http_mock_adapter` already provides.

### Loopback server only for `validateServer`

`validateServer` creates its own short-timeout Dio, so the public accessor
cannot inject the mock adapter. The test binds an `HttpServer` on
`InternetAddress.loopbackIPv4` with port `0`, answers `/api/v1/user`, and
closes the server in `tearDown`. This keeps the test offline (no external
host or DNS) and covers the real success and non-200 paths. The rest of the
suite never opens a socket.

### Reset the singleton around every test

`setUp` calls `close()` and resets `LogService`; `tearDown` calls `close()`
again and closes the loopback server. Each test configures its own server
fixture with a distinct id, so `setServer` cannot take the "same server"
short-circuit by accident. The log-redaction test enables capture explicitly
and initializes the Flutter test binding because `LogService` schedules its
notification through `SchedulerBinding`.

### Keep the log test in its own file

`TestWidgetsFlutterBinding` installs an `HttpOverrides` implementation that
answers every real request with status 400, which breaks the loopback
`validateServer` tests. The log-redaction test therefore lives in
`api_service_log_test.dart`, while `api_service_test.dart` runs without a
widget binding so `validateServer` can use a real loopback socket. Test files
run in separate isolates, so the binding in one file does not affect the other.

### Fixtures instead of a shared constructor call

A small test helper builds a `ServerConnection` with required fields and
optional overrides (url, apiKey, allowSelfSigned). This keeps each test's
server state explicit and avoids repeating the five required constructor
arguments.

## Risks / Trade-offs

- **`DioAdapter` can throw `AssertionError` when a route is missing** → register
  every route a test uses, and keep one test per request shape so a missing
  mock fails with a clear path.
- **The singleton leaks state across tests** → `close()` in both `setUp` and
  `tearDown`, and never rely on a previous test's server configuration.
- **Loopback sockets may be unavailable in a restricted sandbox** → the
  `validateServer` group is the only place that binds a socket; if the
  environment forbids it, the failure is explicit and the rest of the suite
  still runs. No external network is used.
- **Response fixtures can drift from the 2FAuth API** → fixtures are derived
  from the shapes already parsed by the production code (snake_case and
  camelCase variants), and tests assert the parsed result rather than the raw
  JSON.

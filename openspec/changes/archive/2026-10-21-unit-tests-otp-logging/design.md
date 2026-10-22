# Design

## Context

Both services already have seed tests and deterministic helpers
(`withFixedTime`, `resetLogService`). The new cases extend those files and reuse
the RFC 6238 account builder. See `proposal.md` for motivation.

## Goals / Non-Goals

**Goals:**

- Cover every reachable branch of both services, including MD5 and Steam.
- Remove OTP code that cannot execute so coverage reflects reality.
- Keep every test deterministic: fixed clock, fixed secrets, no real files
  outside the system temp directory.
- Verify the log export contract (text content and failure handling).

**Non-Goals:**

- Changing OTP algorithms or output.
- Refactoring code that is reachable.
- Testing `ApiService` or the account tile timer/network flow.
- Reaching 70% coverage in this stage.

## Decisions

- **Do not hardcode an unverified Steam vector.** Assert the composition
  (`generateOtp` for `steamtotp` equals `generateSteamTotp` on the decoded
  secret), the 5-character Steam charset, determinism, and that a period offset
  changes the code. This validates behavior without inventing an oracle.
- **Test MD5 by properties plus a known seed.** The value is 6 digits and
  differs from SHA-1 for the same account and instant; the existing RFC vectors
  already pin the SHA family.
- **Mock only the `path_provider` channel.** A handler for
  `plugins.flutter.io/path_provider` points `getTemporaryDirectory` at a test
  directory; a second handler throws to cover the failure branch. Files are
  deleted in `tearDown`.
- **Use `testWidgets` only for `entryCount`.** The notification runs in a
  post-frame callback, so a pumped widget test is the honest way to observe it.
- **Delete unreachable code instead of documenting it.** `base32Decode` never
  throws, so the hex and UTF-8 fallbacks in `_decodeSecret` cannot run; `_hotp`
  and the commented persistence helpers have no callers. Removing them keeps
  the coverage signal honest and avoids misleading future readers. Tests for
  the remaining Base32 normalization already exist.

## Risks / Trade-offs

- [Platform channel mock can leak between tests] → Register the handler in each
  test and clear it in `tearDown`.
- [Log cap test creates 1001 entries] → It is in-memory and fast; assert length
  and the evicted entry rather than timing.
- [Steam property tests could miss a wrong-but-valid code] → Pair them with the
  composition check against `generateSteamTotp` and the charset assertion.
- [Removing a fallback could hide support for a legacy secret format] → The
  fallback never ran because `base32Decode` cannot throw; the RFC vectors and
  normalization tests pin the behavior that actually executes.

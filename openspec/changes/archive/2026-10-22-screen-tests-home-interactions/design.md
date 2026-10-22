# Design

## Context

See `proposal.md`. Seed one server with one TOTP account and disable
`sync_on_home_open`/auto-sync in the fake box so startup does not reach the
network. The desktop staging path is mocked as in the startup test.

## Decisions

- Pump `HomePage` with the seeded settings and explicit short pumps; never
  `pumpAndSettle` while `AccountTileTOTP` repeats its animation.
- Assert the service/account text, enter a matching search query and assert the
  row remains; enter a non-matching query and assert `No results`.
- Tap the Manage tooltip, pump, assert a checkbox appears and tap it to verify
  selection wiring; then replace the tree with `SizedBox` and pump to dispose
  timers.
- Keep the settings popup/startup assertions in the existing smoke test.

## Risks

- **TOTP timers/animations** → explicit pumps and final disposal.
- **Sync/network** → disabled in the fake settings.
- **Lazy list** → one account only.

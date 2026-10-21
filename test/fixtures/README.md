# Test fixtures

JSON payloads captured from the 2FAuth API (`GET /twofaccounts`) live here. Tests load
them with `File`/`jsonDecode` and feed them to model or service parsers, so the shapes stay
close to what the server actually returns.

Keep one scenario per file, for example:

- `twofaccounts_owned.json`
- `twofaccounts_borrowed.json`

Do not put secrets from a real account in a fixture. Use the published OTP test vectors or
obviously fake data.

## ADDED Requirements

### Requirement: Sync succeeds regardless of icon download status

The sync operation SHALL be marked as successful when account entries and group data are fetched from the server, regardless of whether individual icon downloads succeeded or failed. Icon download failures SHALL NOT cause the sync to be reported as a failure.

#### Scenario: All icons download successfully

- **WHEN** a sync operation fetches accounts and groups successfully AND all associated icons download without errors
- **THEN** the sync result SHALL indicate success with `iconStatus: 'all_ok'` and zero failed icons

#### Scenario: Some icons fail to download

- **WHEN** a sync operation fetches accounts and groups successfully BUT one or more icon downloads fail (network error, 404, timeout)
- **THEN** the sync result SHALL indicate success (`success: true`) AND SHALL report the number of failed icons AND the affected accounts SHALL have no `localIcon` set, causing the UI to display the letter-based placeholder

#### Scenario: All icons fail to download

- **WHEN** a sync operation fetches accounts and groups successfully BUT ALL icon downloads fail
- **THEN** the sync result SHALL indicate success (`success: true`) AND SHALL report that all icons failed AND all accounts SHALL display letter-based placeholders

#### Scenario: Network failure prevents fetching accounts

- **WHEN** a sync operation cannot fetch accounts or groups from the server (network error, server down, auth failure)
- **THEN** the sync result SHALL indicate failure (`success: false`) with `network_failed: true`, preserving the existing behavior

### Requirement: SVG icon rendering errors fall back to letter placeholder

The account tile UI SHALL display a letter-based circle avatar placeholder whenever an SVG icon cannot be loaded, read, sanitized, or parsed — without throwing unhandled exceptions or crashing the application.

#### Scenario: SVG file is missing from disk

- **WHEN** an account has a `localIcon` path pointing to an SVG file that does not exist on disk
- **THEN** the UI SHALL display the letter-based placeholder avatar instead of the SVG

#### Scenario: SVG file fails to read

- **WHEN** an account has a `localIcon` path pointing to an SVG file that exists but cannot be read (permission error, filesystem error)
- **THEN** the UI SHALL display the letter-based placeholder avatar AND SHALL NOT throw an unhandled exception

#### Scenario: SVG sanitization encounters unexpected content

- **WHEN** the SVG sanitization function (`_sanitizeSvg`) receives content that causes the regex or string operation to fail (e.g., null bytes, encoding issues)
- **THEN** the sanitization SHALL return the original unmodified content OR the UI SHALL fall back to the letter-based placeholder

#### Scenario: SVG content fails to parse in flutter_svg

- **WHEN** `SvgPicture.string()` receives SVG content that `flutter_svg` cannot parse (malformed XML, unsupported features)
- **THEN** the `errorBuilder` SHALL be invoked and SHALL return the letter-based placeholder avatar

#### Scenario: PNG/raster icon fails to load

- **WHEN** a non-SVG icon file exists but `FileImage` fails to decode it (corrupt file, unsupported format)
- **THEN** the UI SHALL display the letter-based placeholder avatar via the existing try-catch fallback

### Requirement: Sync result distinguishes data failures from icon issues

The sync operation result SHALL include information that allows the UI to distinguish between a critical data sync failure (accounts not fetched) and a non-critical icon sync issue (icons not downloaded).

#### Scenario: Sync succeeds with icon issues

- **WHEN** sync completes with account data fetched but some icons failed
- **THEN** the result SHALL contain `success: true` AND `failed > 0` AND a user-facing message that indicates icons could not be fully synced without implying data loss

#### Scenario: Sync fails due to network error

- **WHEN** sync cannot reach the server
- **THEN** the result SHALL contain `success: false` AND `network_failed: true` AND the user-facing message SHALL indicate a connection problem

# Spec Delta

## Purpose

Make account icons a bounded, self-repairing, best-effort detail: no icon payload, cached file or rendering failure may consume unbounded memory, take the process down, permanently poison the cache, or prevent an account's code from being displayed.

## ADDED Requirements

### Requirement: Icon downloads are deduplicated and written atomically

The system SHALL download an icon at most once per server and icon filename at a time, and SHALL persist it by writing to a uniquely named temporary file and atomically renaming it into place, so that a reader can never observe a partially written icon and no two writers can share a temporary file.

#### Scenario: Two accounts share the same icon

- **WHEN** two accounts of the same server reference the same icon filename and both need it downloaded
- **THEN** the icon is downloaded once, written once, and both accounts end up pointing at the same complete cached file

#### Scenario: Concurrent downloads never share a temporary file

- **WHEN** several icon downloads run concurrently
- **THEN** each download writes to its own temporary file and only complete files appear at the final path

#### Scenario: A reader never sees a partial file

- **WHEN** an icon is being downloaded while a tile reads the same icon path
- **THEN** the reader either finds no file or the complete previous/new file, never a truncated one

### Requirement: Icon payloads are size-bounded and shape-checked

The system SHALL reject, as a non-fatal icon failure, any downloaded icon whose length exceeds a configured maximum, and any payload that is not recognisably an image in one of the supported formats. A rejected icon SHALL NOT be stored in the cache and SHALL NOT be handed to an image or SVG decoder.

#### Scenario: Oversized icon is rejected

- **WHEN** the server returns an icon larger than the configured maximum
- **THEN** the icon is treated as unavailable, nothing is cached for it, and the account shows its letter placeholder

#### Scenario: Non-image response is rejected

- **WHEN** the server answers the icon request with a document that is not an image (for example an HTML error page served with a success status)
- **THEN** the payload is rejected, not cached, and the account shows its letter placeholder

#### Scenario: Rejection does not fail the sync

- **WHEN** an icon is rejected for size or shape
- **THEN** the account data is still stored and the sync is still reported as successful

### Requirement: Cached icons are validated before use

The system SHALL validate a cached icon (existence, non-zero length, size limit, recognised format) before returning it, and SHALL discard and re-download a cached icon that fails validation. A cached icon that cannot be rendered SHALL be discarded so that a later sync can refetch it, without retrying repeatedly within the same tile.

#### Scenario: Corrupt cached icon is refetched

- **WHEN** a cached icon file is empty, truncated or not a recognised image and the account is displayed
- **THEN** the file is discarded, the icon is fetched again on the next opportunity, and the tile shows the placeholder in the meantime

#### Scenario: A bad server response does not create a retry loop

- **WHEN** the server keeps returning an icon that fails validation
- **THEN** the tile does not evict-and-refetch in a loop and does not repeatedly download while visible

#### Scenario: Previously poisoned caches heal without reinstalling

- **WHEN** a device has a corrupt icon file left by an older app version and the app is updated
- **THEN** the corrupt file is detected and replaced without the user reinstalling the app

### Requirement: Raster icons are decoded at display size

The system SHALL decode a cached raster icon at a resolution appropriate to the avatar it renders in, so that the memory used is bounded by the display size rather than by the icon's intrinsic pixel dimensions.

#### Scenario: Large-but-accepted raster icon

- **WHEN** an account icon is a large raster image within the accepted size limit
- **THEN** it is decoded downscaled and the app's memory use stays bounded, with the icon displayed in the avatar

#### Scenario: Avatar rendering stays stable during code refresh

- **WHEN** the tile rebuilds because its code refreshed
- **THEN** the icon is not re-read from disk or re-parsed unnecessarily

### Requirement: An icon can never break the tile or the app

The system MUST NOT display an icon at the cost of the account's code: any failure in the icon path SHALL resolve to the letter placeholder, and the service name, account name, current code, next code and countdown SHALL be rendered independently of the icon's outcome.

#### Scenario: Hostile icon still shows the code

- **WHEN** an account's cached icon is malformed, oversized or otherwise unrenderable
- **THEN** the tile shows the placeholder avatar and still shows the account's current and next codes

#### Scenario: App stays alive with a hostile icon

- **WHEN** an account with an oversized or extremely complex icon is scrolled into view
- **THEN** the app keeps running and does not get killed by running out of memory

### Requirement: The user can clear the icon cache

The system SHALL provide a user-accessible action that deletes the cached icons for all servers, without requiring a reinstall and without affecting account data, and SHALL fall back to the letter placeholder until icons are fetched again.

#### Scenario: Clearing the cache from Settings

- **WHEN** the user triggers "clear icon cache" from Settings
- **THEN** the cached icon files are deleted and accounts show their letter placeholders

#### Scenario: Account data is untouched by clearing the cache

- **WHEN** the icon cache is cleared
- **THEN** account entries, secrets, groups and settings are unchanged, and the next sync restores the icons

#### Scenario: Clearing the cache cannot fail the app

- **WHEN** the cache directory is missing or a file cannot be deleted
- **THEN** the action completes without an unhandled error and reports the outcome to the user

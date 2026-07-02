## ADDED Requirements

### Requirement: Debug logging can be toggled by the user
The system SHALL provide a boolean setting `debug_logging_enabled` that controls whether diagnostic log messages are captured in memory. The setting SHALL default to `false` (disabled) and SHALL be persisted using the same storage mechanism as other app settings (encrypted Hive box with SharedPreferences fallback).

#### Scenario: User enables debug logging
- **WHEN** the user navigates to Settings and toggles "Debug Logging" to ON
- **THEN** the setting is immediately persisted to storage and subsequent calls to `LogService.log()` will capture entries

#### Scenario: User disables debug logging
- **WHEN** the user toggles "Debug Logging" to OFF
- **THEN** the setting is immediately persisted and new `LogService.log()` calls become no-ops; previously captured entries remain in memory until explicitly cleared or app restart

#### Scenario: App starts with debug logging disabled
- **WHEN** the app launches and the persisted `debug_logging_enabled` value is `false`
- **THEN** `LogService` operates in no-op mode and captures zero entries

#### Scenario: App starts with debug logging enabled
- **WHEN** the app launches and the persisted `debug_logging_enabled` value is `true`
- **THEN** `LogService` captures entries from `SyncService`, `ApiService`, and the global error handler from the moment of initialization

### Requirement: LogService captures structured log entries
The system SHALL provide an in-memory `LogService` singleton that captures log entries with timestamp, severity level (debug, info, warning, error), source name, and message text. The buffer SHALL be capped at 1000 entries (FIFO).

#### Scenario: Log entry is captured when logging is enabled
- **WHEN** `LogService.instance.info('Sync started', name: 'SyncService')` is called and `debug_logging_enabled` is `true`
- **THEN** a `LogEntry` with level=info, name=SyncService, and the message is appended to the buffer

#### Scenario: Log entry is discarded when logging is disabled
- **WHEN** `LogService.instance.info('message')` is called and `debug_logging_enabled` is `false`
- **THEN** no entry is added to the buffer

#### Scenario: Buffer overflow discards oldest entries
- **WHEN** the buffer already contains 1000 entries and a new entry is added
- **THEN** the oldest entry is removed and the new entry is appended (FIFO ring buffer)

### Requirement: Global error handler feeds into LogService
The system SHALL register a `PlatformDispatcher.instance.onError` handler during app initialization that captures unhandled Dart errors as `LogLevel.error` entries in `LogService`, respecting the `debug_logging_enabled` gate.

#### Scenario: Unhandled exception with logging enabled
- **WHEN** an unhandled Dart exception occurs and `debug_logging_enabled` is `true`
- **THEN** the error and stack trace are captured as a `LogLevel.error` entry with name='Dart'

#### Scenario: Unhandled exception with logging disabled
- **WHEN** an unhandled Dart exception occurs and `debug_logging_enabled` is `false`
- **THEN** no entry is captured; the default platform behavior is preserved (the handler returns `false`)

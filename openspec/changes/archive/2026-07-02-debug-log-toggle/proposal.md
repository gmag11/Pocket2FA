## Why

Pocket2FA currently has no structured diagnostic logging. When users encounter issues — sync failures, API errors, crashes — there is no way to collect or inspect what happened. The `debug` branch already contains a working `LogService` singleton, a log viewer screen, and enhanced logging throughout `SyncService` and `ApiService`, but it is always-on and has not been merged to `main`. We need to bring this diagnostic capability to production behind a user-controlled toggle so logging can be enabled only when needed, avoiding any performance or privacy impact during normal use.

## What Changes

- **New**: `LogService` singleton (in-memory ring buffer, 1000 entries max) with `LogLevel` (debug/info/warning/error) and `LogEntry` model — ported from `debug` branch
- **New**: `LogScreen` UI with log list, level filtering, clear, and export-to-file — ported from `debug` branch
- **New**: `debug_logging_enabled` boolean setting in `SettingsService`, persisted via the existing Hive/SharedPreferences storage, defaulting to `false` (disabled)
- **Modified**: `SettingsScreen` — add a "Debug Logging" toggle switch (under a new Diagnostics section), and a button to navigate to `LogScreen` (visible only when logging is enabled)
- **Modified**: `SyncService` — replace `developer.log` calls with `LogService` integration, gated behind the `debug_logging_enabled` setting
- **Modified**: `ApiService` — replace Dio `logPrint` callback with `LogService` integration, gated behind the setting
- **Modified**: `main.dart` — initialize `LogService`, register `PlatformDispatcher.instance.onError` handler, gate log capture on the setting
- **Modified**: l10n files (en, es, fr) — new strings for diagnostics section, debug logging toggle, log viewer screen

## Capabilities

### New Capabilities
- `debug-logging`: In-memory diagnostic log capture with a user-facing enable/disable toggle persisted in app settings
- `log-viewer`: UI screen to view captured logs with level filtering, clear, and export to a plain-text file

### Modified Capabilities
<!-- None — no existing capability specs exist in openspec/specs/ -->

## Impact

- **New files**: `lib/services/log_service.dart`, `lib/screens/log_screen.dart`
- **Modified files**: `lib/services/settings_service.dart`, `lib/screens/settings_screen.dart`, `lib/services/sync_service.dart`, `lib/services/api_service.dart`, `lib/main.dart`
- **Modified l10n**: `lib/l10n/app_en.arb`, `lib/l10n/app_es.arb`, `lib/l10n/app_fr.arb` (+ auto-generated localizations)
- **Dependencies**: No new packages required (uses `dart:collection`, `dart:io`, `path_provider` already in pubspec)
- **Breaking changes**: None

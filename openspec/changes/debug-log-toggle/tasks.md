## 1. Settings infrastructure

- [x] 1.1 Add `debug_logging_enabled` key, getter, and setter to `SettingsService` (default `false`)
- [x] 1.2 Add `debug_logging_enabled` to `_load()` so it reads from persisted storage
- [x] 1.3 Add `debug_logging_enabled` write-back in the setter (same pattern as other bool settings)

## 2. LogService core

- [x] 2.1 Create `lib/services/log_service.dart` with `LogLevel` enum and `LogEntry` model (timestamp, level, name, message, toString)
- [x] 2.2 Implement `LogService` singleton with `Queue<LogEntry>` ring buffer (max 1000), `entryCount` notifier
- [x] 2.3 Implement `log()`, `debug()`, `info()`, `warning()`, `error()` convenience methods — all gated on `SettingsService.instance.debugLoggingEnabled`
- [x] 2.4 Implement `clear()`, `exportAsText()`, and `exportToFile()` methods

## 3. App initialization

- [x] 3.1 In `main.dart`, after `SettingsService` initialization, register `PlatformDispatcher.instance.onError` that feeds into `LogService.instance.error()` with name 'Dart'
- [x] 3.2 In `main.dart`, log `LogService.instance.info('App starting', name: 'main')` after init

## 4. Service logging integration

- [x] 4.1 In `SyncService`, replace all `developer.log` calls with `LogService.instance` calls via a `_log()` helper (import `log_service.dart`)
- [x] 4.2 In `ApiService`, replace the Dio `logPrint` callback with `LogService.instance` calls

## 5. Localization

- [x] 5.1 Add new l10n keys to `app_en.arb`
- [x] 5.2 Add corresponding Spanish translations to `app_es.arb`
- [x] 5.3 Add corresponding French translations to `app_fr.arb`
- [x] 5.4 Run `flutter gen-l10n` to regenerate localization files

## 6. Settings UI — Diagnostics section

- [x] 6.1 In `settings_screen.dart`, add a "Diagnostics" section header below the existing Sync section
- [x] 6.2 Add a `SwitchListTile` for "Debug Logging" bound to `settingsService.debugLoggingEnabled`, with description subtitle
- [x] 6.3 Add a "View Diagnostic Log" button (TextButton or ListTile) that navigates to `LogScreen` — visible only when `debug_logging_enabled` is `true`

## 7. Log viewer screen

- [x] 7.1 Create `lib/screens/log_screen.dart` with `LogScreen` widget
- [x] 7.2 Implement level filter chips row (All / Debug / Info / Warning / Error) using `FilterChip` or `ChoiceChip`
- [x] 7.3 Implement scrollable log entry list using `ListView.builder` with `AnimatedBuilder` listening to `LogService.instance.entryCount`
- [x] 7.4 Style log entries with colored level badges and monospace message text
- [x] 7.5 Implement clear button with confirmation dialog
- [x] 7.6 Implement export button: call `exportToFile()`, then `Share.shareXFiles` to open share dialog
- [x] 7.7 Show empty state widget when buffer is empty

## 8. Verification

- [ ] 8.1 Manual test: toggle setting ON, trigger a sync, verify entries appear in LogScreen
- [ ] 8.2 Manual test: toggle setting OFF, trigger a sync, verify NO new entries appear
- [ ] 8.3 Manual test: export log file and verify content format
- [ ] 8.4 Manual test: filter chips show/hide entries correctly
- [ ] 8.5 Manual test: clear button removes all entries

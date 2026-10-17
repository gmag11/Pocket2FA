## Context

Pocket2FA uses `developer.log` from `dart:developer` for ad-hoc logging in `SyncService` and `ApiService`. This output is invisible to end users and useless for remote diagnostics. The `debug` branch already has a working `LogService` singleton with an in-memory ring buffer and a `LogScreen` UI, but it's always-on — not suitable for production.

The app already has a mature `SettingsService` backed by encrypted Hive storage with `ChangeNotifier` reactivity. Adding a new boolean setting follows the established pattern exactly.

## Goals / Non-Goals

**Goals:**
- Port `LogService` and `LogScreen` from `debug` branch to `main`
- Gate all log capture behind a `debug_logging_enabled` setting (default: `false`)
- Provide a Diagnostics section in `SettingsScreen` with the toggle and a log viewer link
- Replace existing `developer.log` calls in `SyncService` and `ApiService` with `LogService` integration
- Register a global `PlatformDispatcher.instance.onError` handler that feeds into `LogService` (only when enabled)

**Non-Goals:**
- File-based persistent logging (logs are in-memory only; export is manual)
- Remote log upload / telemetry
- Log level configuration beyond the fixed levels (debug, info, warning, error)
- Changing the logging behavior of any service other than `SyncService` and `ApiService`

## Decisions

### 1. LogService as singleton, not injected

**Choice**: `LogService` is a singleton accessed via `LogService.instance` (same as `SyncService`, `ApiService`).

**Rationale**: The app already uses the singleton pattern for cross-cutting services. Injecting via constructor would require threading through `ServerConnection`, `SyncService`, `ApiService`, `SettingsService`, and the widget tree — a refactor far beyond this change's scope. Singleton keeps the diff minimal and focused.

**Alternative considered**: Provider/DI — would require significant refactor of `SyncService` and `ApiService` which currently use static `instance` accessors.

### 2. Setting gate at LogService level, not at call sites

**Choice**: `LogService` checks `SettingsService.instance.debugLoggingEnabled` on every `log()` call. Call sites call unconditionally.

**Rationale**: Callers (`SyncService`, `ApiService`, `main.dart`) don't need to know whether logging is enabled. The `LogService.log()` method is a no-op when disabled. This keeps call sites clean and prevents drift if new log calls are added later without the guard.

**Alternative considered**: Guard at each call site — error-prone and verbose. Rejected because it duplicates the setting check across dozens of locations.

### 3. Setting key: `debug_logging_enabled` in existing SettingsService

**Choice**: Add `debug_logging_enabled` (bool, default `false`) to the existing `SettingsService` alongside `sync_on_home_open`, `biometric_protection_enabled`, etc.

**Rationale**: Follows the established pattern precisely — a `static const` key, a private field, a getter, a setter that persists and notifies. No new storage mechanism needed.

### 4. LogScreen accessible only from SettingsScreen

**Choice**: Add a "View Diagnostic Log" button in the Settings → Diagnostics section, visible only when `debug_logging_enabled` is `true`.

**Rationale**: The log viewer is a diagnostic tool, not a primary feature. It doesn't need its own navigation entry. Tying it to the setting ensures users don't stumble on an empty screen when logging is disabled.

### 5. Log level filtering in UI, not in storage

**Choice**: `LogScreen` shows all captured entries but provides level filter chips (All / Debug / Info / Warning / Error). Filtering is UI-only.

**Rationale**: The ring buffer already caps at 1000 entries, so memory is bounded. Filtering at display time means all levels are available for export without re-capturing.

## Risks / Trade-offs

- **[Low] Memory**: 1000 log entries with timestamps and short messages ≈ ~200KB in memory. Acceptable for a desktop app. Mitigated by the fixed ring buffer cap.
- **[Low] Sensitive data in logs**: SyncService and ApiService already mask secrets. LogService doesn't add new unmasked logging. Export-to-file saves to app temp directory — user must explicitly share the file.
- **[Medium] Setting check overhead**: `SettingsService.instance.debugLoggingEnabled` is a simple field read (no async, no disk I/O). Called on every `log()` invocation. In hot paths (API polling), this is negligible. If profiling shows otherwise, we can cache the value locally in LogService with a `settingsService.addListener` to invalidate.

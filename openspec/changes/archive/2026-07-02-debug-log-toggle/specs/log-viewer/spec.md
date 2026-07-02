## ADDED Requirements

### Requirement: User can view captured diagnostic logs
The system SHALL provide a log viewer screen (`LogScreen`) accessible from the Diagnostics section of Settings. The screen SHALL display captured log entries in reverse chronological order (newest first) with each entry showing timestamp, level badge, source name, and message.

#### Scenario: Log screen shows captured entries
- **WHEN** the user navigates to the log viewer and entries exist in the buffer
- **THEN** entries are displayed with colored level badges (debug=grey, info=blue, warning=orange, error=red), timestamp, source name, and message text

#### Scenario: Log screen shows empty state
- **WHEN** the user navigates to the log viewer and the buffer is empty
- **THEN** an empty-state message is displayed (e.g., "No log entries yet")

#### Scenario: Log screen updates in real time
- **WHEN** the user is viewing the log screen and a new log entry is captured
- **THEN** the new entry appears at the top of the list without requiring manual refresh

### Requirement: User can filter log entries by severity level
The system SHALL provide level filter chips on the log viewer screen allowing the user to filter displayed entries by level (All, Debug, Info, Warning, Error).

#### Scenario: User filters to show only errors
- **WHEN** the user taps the "Error" filter chip
- **THEN** only entries with `LogLevel.error` are displayed; other filter chips are deselected

#### Scenario: User clears filter
- **WHEN** the user taps the currently active filter chip (e.g., "Error") again
- **THEN** the filter is cleared and all entries are displayed (equivalent to "All")

### Requirement: User can clear all log entries
The system SHALL provide a clear button on the log viewer screen that removes all entries from the buffer.

#### Scenario: User clears all logs
- **WHEN** the user taps the clear button and confirms the action
- **THEN** all entries are removed from the buffer and the screen shows the empty state

### Requirement: User can export log entries to a file
The system SHALL provide an export button on the log viewer screen that writes all captured entries as a plain-text file to the app's temporary directory and opens a share dialog.

#### Scenario: User exports logs successfully
- **WHEN** the user taps the export button and entries exist in the buffer
- **THEN** a `.txt` file is created in the temp directory with header metadata (app name, timestamp, platform, Dart SDK version) followed by all log entries, and the system share dialog is opened

#### Scenario: User exports when buffer is empty
- **WHEN** the user taps the export button and the buffer is empty
- **THEN** a snackbar or toast informs the user there is nothing to export

## ADDED Requirements

### Requirement: Group filter persists across sync operations
The system SHALL preserve the user's selected group filter across all synchronization operations. The filter selection MUST NOT be reset to "All" when a sync completes.

#### Scenario: Manual sync preserves group filter
- **WHEN** user has selected a specific group filter (e.g., "Work") and triggers a manual sync via the sync button
- **THEN** the group filter remains set to "Work" after sync completes and the displayed accounts remain filtered by that group

#### Scenario: Pull-to-refresh preserves group filter
- **WHEN** user has selected a specific group filter and performs a pull-to-refresh gesture
- **THEN** the group filter remains unchanged after the refresh completes

#### Scenario: Auto-sync timer preserves group filter
- **WHEN** user has selected a specific group filter and the auto-sync timer fires
- **THEN** the group filter remains unchanged after the background sync completes

#### Scenario: App foreground resume preserves group filter
- **WHEN** user has selected a specific group filter, backgrounds the app, and returns to foreground (triggering a sync)
- **THEN** the group filter remains unchanged after the sync completes

#### Scenario: QR scan sync preserves group filter
- **WHEN** user has selected a specific group filter and scans a new QR code (triggering a sync)
- **THEN** the group filter remains unchanged after the sync completes

### Requirement: Graceful fallback when selected group no longer exists
The system SHALL fall back to "All" when the previously selected group no longer exists in the account data after a sync, but MUST NOT reset the filter otherwise.

#### Scenario: Selected group deleted during sync
- **WHEN** user has selected group "Work", all accounts in that group are deleted during a sync, and the user triggers another sync
- **THEN** the filter automatically falls back to "All" and all remaining accounts are displayed

#### Scenario: Selected group still exists after sync
- **WHEN** user has selected group "Work" and at least one account still belongs to "Work" after sync
- **THEN** the filter remains on "Work" and only Work accounts are displayed

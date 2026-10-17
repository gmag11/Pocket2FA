# Spec Delta

## Purpose

Provide an Android Quick Settings tile that opens Pocket2FA from the notification shade with a single tap, without turning the tile into a way to read one-time passwords on a locked screen and without bypassing the app's existing lock.

## ADDED Requirements

### Requirement: An Android Quick Settings tile is provided

The app SHALL declare an Android Quick Settings tile service (`android.service.quicksettings.TileService`) in its manifest, requiring no runtime permission, so that the tile can be added by the user from the system tile editor and is available on all Android versions the app supports. The tile SHALL only exist on Android; other supported platforms SHALL be unaffected.

#### Scenario: Tile is offered by the system

- **WHEN** the user opens the system Quick Settings tile editor on an Android device
- **THEN** the Pocket2FA tile is listed and can be added to the panel

#### Scenario: No new permission is requested

- **WHEN** the app is installed or updated with the tile included
- **THEN** no new runtime permission prompt is shown, and the tile declares only the platform-required `BIND_QUICK_SETTINGS_TILE` binding permission

#### Scenario: Non-Android platforms are unaffected

- **WHEN** the app runs on Linux or Windows
- **THEN** no tile-related code path is reachable and the app behaves exactly as before

### Requirement: Tapping the tile opens the app

Tapping the tile SHALL open Pocket2FA. If an instance of the app already exists, that instance SHALL be brought to the foreground instead of a second instance or task being created. The launch MUST succeed on every supported Android version, including those where the launcher API requires a `PendingIntent`.

#### Scenario: Tile opens the app when it is not running

- **WHEN** the tile is tapped while Pocket2FA is not running
- **THEN** the app starts at its normal start screen

#### Scenario: Tile resumes a running app

- **WHEN** the tile is tapped while Pocket2FA is already running in the background
- **THEN** the existing instance is brought to the foreground and no second instance is created

#### Scenario: Tile works on Android 14 and later

- **WHEN** the tile is tapped on a device running Android 14 or later with the app targeting API 34 or higher
- **THEN** the app opens (the tile does not fail silently or crash)

### Requirement: The tile never exposes secrets and never bypasses a lock

The tile surface SHALL NOT display one-time passwords or any other account data. When the device is secured and locked, tapping the tile MUST require the device to be unlocked before the app's content becomes visible. The app's own lock (when enabled) MUST still be enforced when the app is opened from the tile.

#### Scenario: Device is locked

- **WHEN** the tile is tapped while the device is locked with a secure lock screen
- **THEN** the system requires the device to be unlocked before the app is shown

#### Scenario: Device is already unlocked

- **WHEN** the tile is tapped while the device is unlocked
- **THEN** the app is shown immediately without an additional device-credential prompt

#### Scenario: App lock is still enforced

- **WHEN** the app's own lock is enabled and the app is opened from the tile from a cold start
- **THEN** the app's lock screen is presented before any one-time password is displayed

#### Scenario: Tile shows no account data

- **WHEN** the tile is visible in the Quick Settings panel, including on the lock screen
- **THEN** it shows only its own label and icon, with no code, account name or countdown

### Requirement: The tile is presented with a localized label and a system-tinted icon

The tile SHALL use a monochrome icon that the system can tint, and a short label available in each of the languages the app ships (English, Spanish and French), falling back to English when the device language is not one of them.

#### Scenario: Label follows the device language

- **WHEN** the tile is added on a device set to Spanish or French
- **THEN** its label is shown in that language

#### Scenario: Icon renders correctly when tinted

- **WHEN** the system renders or tints the tile
- **THEN** the icon renders as a single-color glyph with no background or clipped edges

#### Scenario: Unsupported device language

- **WHEN** the device language is not one the app translates
- **THEN** the tile label is shown in English

### Requirement: The app helps the user add the tile

The app SHALL offer an Android-only entry point that lets the user add the tile without knowing the system tile editor. On Android 13 and later this entry SHALL trigger the system "add tile" prompt; on earlier versions, where no such prompt exists, it SHALL explain how to add the tile manually.

#### Scenario: Adding the tile on Android 13 or later

- **WHEN** the user activates the add-tile entry on an Android 13+ device
- **THEN** the system prompt to add the Pocket2FA tile is shown

#### Scenario: Adding the tile on older Android versions

- **WHEN** the user activates the add-tile entry on a device running Android 12 or lower
- **THEN** the app shows instructions to add the tile from the Quick Settings editor instead of failing silently

#### Scenario: Entry point is Android-only

- **WHEN** the settings screen is opened on a non-Android platform
- **THEN** no tile-related entry is shown

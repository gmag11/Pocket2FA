## ADDED Requirements

### Requirement: Window geometry restoration on startup
On Windows and Linux, the application SHALL restore the desktop window's position, size, and maximized state from the previous session on startup, if a previous session's geometry was saved.

#### Scenario: Restoring a previously saved window
- **WHEN** the app is launched on Windows or Linux and a valid saved window position/size exists from a prior session
- **THEN** the window opens at the saved position and size (or maximized, if it was maximized when last closed)

#### Scenario: First launch with no saved geometry
- **WHEN** the app is launched for the first time (no saved geometry exists)
- **THEN** the window opens using the existing default size and position (1280×720, near the top-left of the primary display)

#### Scenario: Saved geometry is off-screen
- **WHEN** the app is launched and the saved position/size would place the window mostly or fully outside the bounds of all currently connected displays
- **THEN** the window's restored position/size is clamped to fit within the currently available virtual screen space instead of the raw saved value

### Requirement: Window geometry persistence during use
The application SHALL persist the current window position, size, and maximized state to local storage whenever the window is moved, resized, maximized/unmaximized, or closed.

#### Scenario: User resizes or moves the window
- **WHEN** the user resizes or moves the window and then leaves it idle for a short period (debounce)
- **THEN** the new position and size are saved to local storage, replacing the previously saved values

#### Scenario: User closes the app
- **WHEN** the user closes the application window
- **THEN** the current window position, size, and maximized state are saved before the process exits

### Requirement: Platform scope
Window geometry persistence SHALL apply only to desktop platforms (Windows and Linux) supported by this repository and SHALL NOT alter behavior on Android or iOS.

#### Scenario: Running on a mobile platform
- **WHEN** the app is launched on Android or iOS
- **THEN** no window geometry restoration or persistence logic is invoked, and existing mobile behavior is unchanged

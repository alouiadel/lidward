# Changelog

## [0.4.0] - 2026-11-08

### Added

- Custom pixel-eye menu-bar glyph derived from the app icon; the pupil fills while a session is active.
- Timed sessions from 15 minutes to 8 hours, with automatic stop and a live remaining-time countdown.
- **Start For** menu submenu for starting a one-off length, plus a default session-length setting in Preferences.
- Menu-bar-focused animated demo in the README.

### Changed

- Redesigned Preferences with a branded header, grouped settings cards, and clearer descriptions in both light and dark mode.
- Preferences is now settings-only; starting and stopping a session happens from the menu bar.
- Session controls now appear directly in the menu with icons and a live status line instead of being hidden in a submenu.
- The menu bar shows remaining time for timed sessions and elapsed time for indefinite sessions, even when the menu-bar timer is hidden.
- Alerts now use the Lidward app icon.

## [0.3.3] - 2026-11-07

### Fixed

- The status menu now uses the native AppKit menu positioning in normal spaces, so it attaches directly below the menu bar again. The direct pop-up path is kept only for full-screen spaces, where it avoids the accessory-app activation bug.

## [0.3.2] - 2026-11-07

### Fixed

- The menu bar menu now opens through a direct `NSMenu` pop-up instead of the system-managed status-item menu. This avoids the macOS accessory-app activation path that can make the menu bar disappear while another app is full screen.

## [0.3.1] - 2026-11-07

### Changed

- New retro beige-computer, pixel-eye app icon and README logo.
- Preferences now shows explicit inline feedback after **Check Now**: “You’re up to date,” “A newer version is available,” or the error.

## [0.3.0] - 2026-11-07

### Added

- Daily GitHub Releases update check with a menu-bar download flag.
- Manual "Check for Updates…" and a Preferences "Check Now" button.
- In-app **Uninstall Lidward…** that purges the app, preferences, login item, closed-display helper, and restores sleep.

### Changed

- Update checks can be disabled in Preferences.
- Full self-installing auto-update is deferred until the app has users.

## [0.2.0] - 2026-11-07

### Added

- Monotonic elapsed-time tracking for the menu-bar session timer.
- `--purge` uninstall option for preferences and login item.
- Changelog-driven GitHub release notes.

### Changed

- Bundle identifier changed to `app.lidward`.
- App copyright text no longer includes a personal name.
- Release artifacts are sanitized before publishing.

## [0.1.0] - 2026-11-06

### Added

- Menu-bar keep-awake sessions with native `IOPMAssertion` system and display sleep prevention.
- Display-sleep controls, screen-lock timing, and lock-on-lid-close.
- Integrated closed-display helper with a one-time admin setup.
- Elapsed session time in the menu bar.
- Preferences window, optional Dock icon, and Launch at Login.
- Sanitized GitHub Releases with `--install`, `--uninstall`, `--package`, and `--release` build flags.

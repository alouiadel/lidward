# Changelog

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

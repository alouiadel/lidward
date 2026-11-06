<p align="center">
  <img src="assets/logo.svg" alt="Lidward logo" width="168">
</p>

<h1 align="center">Lidward</h1>

<p align="center">
  <strong>Your Mac stays awake. Even with the lid shut.</strong><br>
  A focused, native macOS menu-bar keep-awake utility.
</p>

<p align="center">
  <img alt="Status" src="https://img.shields.io/badge/status-early%20development-F59E0B">
  <img alt="Platform" src="https://img.shields.io/badge/platform-macOS%2013%2B-0B1220">
  <img alt="Language" src="https://img.shields.io/badge/language-Swift%20%2B%20AppKit-F05138">
  <img alt="License" src="https://img.shields.io/badge/license-MIT-22C55E">
</p>

---

**Lidward** is a small macOS menu-bar app that keeps your Mac awake for as long as you need. It is deliberately focused: only the controls that matter, no triggers, no schedules, no subscriptions, and no App Store sandbox.

The name is **lid + ward** — a small guard for your lid.

## Why Lidward?

Most keep-awake apps carry years of features you never touch. Lidward keeps the parts that matter and makes the one difficult part — closed-display mode — work without a separate download or manual setup.

## Features

### Session

- Menu-bar icon to start and stop a session
- **Indefinite** sessions for now (more session types may come later)
- Holds native macOS power assertions while active
- **Elapsed session time** in the menu bar
- **Optional Dock icon** — hidden by default
- **Launch at login** (best when the app is in `/Applications`)
- Preferences window for menu-bar, Dock, and startup options

### Per-session controls

- Allow or prevent **display sleep**
- Allow display sleep **when the screen is locked**
- Allow or prevent **system sleep when the lid is closed** (Closed-Display Mode)
- **Lock the screen** after inactivity, or immediately after the display is closed
- Session controls live in the menu bar and persist between launches

### Closed-Display Mode, integrated

Closed-display mode usually needs a separate helper or a manually installed script. Lidward ships its own privileged helper:

- The first time you enable it, macOS asks for your administrator password **once**. Lidward installs a root-owned helper and a sudoers rule that allows only two commands: `pmset -a disablesleep 0` and `pmset -a disablesleep 1`.
- The helper is the executable that performs the toggle. The sudoers rule is the permission that lets that one helper run as root without a password each time. They are two pieces because the app itself must not run as root.
- After that, toggling closed-display mode does not ask for a password.
- The helper watches Lidward through a pipe. If Lidward quits or crashes, the pipe closes and the helper restores the previous sleep setting.
- It re-applies the setting if macOS resets it after a power-source change.
- No script to download, no sudoers file to edit by hand, no kernel extension, no SIP changes.
- **Remove Closed-Display Helper…** appears in the menu only when the helper is installed, and removes both pieces.

> [!WARNING]
> Keeping a MacBook awake with the lid closed can cause heat and battery drain. Use it on a hard, ventilated surface — never in a bag. Lidward restores normal sleep when it can, but macOS can still force sleep at critical battery.

## Roadmap

- [x] Name, logo, license, README
- [x] App icon
- [x] Swift package + menu-bar shell
- [x] Indefinite session with power assertions
- [x] Display sleep and lock-screen controls
- [x] Integrated closed-display helper
- [x] Session status/time in the menu bar
- [x] Hide in Dock preference
- [x] Preferences window
- [x] Launch at login

## Build

Requirements: macOS 13+ and a Swift 5.9+ toolchain (Xcode or the Command Line Tools).

```bash
./scripts/build-app.sh
```

The script builds the release binary, assembles `dist/Lidward.app`, ad-hoc signs it, and opens it. To build without launching:

```bash
./scripts/build-app.sh --no-open
```

The app icon is generated from `assets/logo.svg` with `scripts/make-icon.sh` and bundled as `AppIcon.icns`; the build script regenerates it if it is missing.

The app is ad-hoc signed for local use. The menu-bar shell, the indefinite session, the display/lock controls, the integrated closed-display helper, and the preferences/startup polish are in place. Next is release packaging.

## License

[MIT](LICENSE) © 2026 Adel Aloui

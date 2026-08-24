# ShortcutKit macOS App Design

**Date:** 2026-08-24  
**Target release:** v0.2.0  
**Status:** Approved for direct implementation

## Goal

Turn the existing GitHub-installable ShortcutKit project into a native macOS menu-bar application that explains every shortcut, shows live dependency and permission status, and lets users enable or disable shortcut groups with checkboxes. The app must remain distributable through GitHub Releases without the Mac App Store.

The first App release keeps Hammerspoon as the proven shortcut runtime. The App is the user-facing control plane; Hammerspoon remains an implementation detail after installation.

## Product Scope

### Included in v0.2.0

- Native SwiftUI menu-bar application with a settings window.
- A catalog row for every existing ShortcutKit module, including its key combination, purpose, scope, dependency, and current state.
- Per-module enable/disable checkbox and an all-modules master toggle.
- Live states: enabled, disabled, dependency unavailable, permission unavailable, conflict, and runtime error.
- Dependency and permission page for Hammerspoon, Accessibility, Screen Recording, Chrome, Codex, MailMaster, ChatGPT Classic, WhatsApp Edge PWA, and BetterTouchTool.
- One-click install or repair of the bundled ShortcutKit Spoon and loader.
- Automatic configuration backup, atomic config writes, Hammerspoon reload, status polling, and rollback on failed verification.
- Launch-at-login control through `SMAppService` where supported.
- Diagnostics view with sanitized status only; no window titles, clipboard contents, screenshots, usernames, or private paths.
- GitHub Release packages: unsigned `.dmg`, `.zip`, and SHA-256 checksum files.
- Existing shell installer and lifecycle commands remain supported as the recovery path.

### Explicitly deferred

- Editing or recording arbitrary key combinations.
- Replacing Hammerspoon with a new native event-tap engine.
- App Store submission.
- Automatic macOS TCC permission grants or bypasses.
- Automatic code signing or notarization without explicitly configured Apple Developer credentials.

## User Experience

ShortcutKit runs as an `LSUIElement` menu-bar application. Its menu-bar menu provides:

- Open Shortcut Settings
- Enable/Disable All
- Runtime summary
- Quit ShortcutKit

The settings window contains three sections.

### Shortcuts

Each row contains:

- module icon and localized title;
- one or more formatted key combinations;
- a one-line explanation;
- scope or required application;
- enable checkbox;
- live state badge and actionable failure explanation.

Rows are grouped into Global, Browser and Codex, Applications, and Optional Integration. Multi-key features such as the two Codex mention keys and four ChatGPT model keys remain one module row because they are controlled by one runtime module.

The master toggle writes every known module state. It never changes unknown keys preserved in the configuration file.

### Permissions and Dependencies

This view displays the installed and running state of Hammerspoon and application dependencies. Hammerspoon reports its own Accessibility and Screen Recording state through IPC. The App offers buttons to open the appropriate System Settings pages but never attempts to grant permission.

When Hammerspoon or the Spoon is missing, the primary action becomes Install or Repair. The install flow displays what will change, invokes the existing reversible installer from App resources, launches Hammerspoon, and waits for status readback.

### Diagnostics

Diagnostics shows App version, Spoon version, module state counts, the last reload outcome, and recovery availability. Copy Diagnostics copies only sanitized JSON. It excludes private filesystem paths, logs, active window names, clipboard contents, OCR results, application documents, and tokens.

## Architecture

### Build structure

The macOS application is implemented as a dependency-free Swift Package under `app/`:

```text
app/
  Package.swift
  Sources/ShortcutKitApp/
    ShortcutKitApp.swift
    AppModel.swift
    Models/
    Services/
    Views/
  Resources/shortcut-catalog.json
  Tests/ShortcutKitAppTests/
```

`swift build -c release` produces the executable. `scripts/package-app.sh` constructs a standard `ShortcutKit.app` bundle, writes `Info.plist`, copies icons and resources, and embeds the exact Spoon and lifecycle scripts from the repository. `scripts/package-dmg.sh` creates the unsigned DMG and ZIP. This avoids an external project generator or third-party runtime dependency.

### Components

1. **ShortcutCatalog**
   - Reads bundled `shortcut-catalog.json`.
   - Defines stable module IDs, localized labels, key display strings, scope, and dependency metadata.
   - Validates that catalog IDs exactly match the runtime module manifest during tests.

2. **ConfigStore**
   - Reads and writes `~/Library/Application Support/ShortcutKit/config.json`.
   - Uses same-directory temporary files followed by atomic replacement.
   - Preserves unknown fields for forward compatibility.
   - Creates a recoverable previous-config snapshot before each mutation.

3. **HammerspoonBridge**
   - Locates the Hammerspoon CLI and application without assuming a private home path.
   - Runs bounded `Process` commands with explicit arguments and timeouts.
   - Reads a machine-safe JSON runtime report.
   - Treats the expected message-port invalidation during `hs.reload()` as transitional, then polls the fresh status endpoint.

4. **InstallationService**
   - Invokes bundled lifecycle scripts rather than duplicating installer logic in Swift.
   - Supports dry-run, apply, verify, update, uninstall, and restore operations.
   - Streams only sanitized progress events to the UI.

5. **PermissionService**
   - Reads Hammerspoon-reported Accessibility and Screen Recording states.
   - Opens official System Settings panes on user action.
   - Never requests or mutates another process's TCC database.

6. **AppModel**
   - Owns catalog, config, runtime report, busy/error state, and rollback state.
   - Coordinates toggle transactions and refreshes.
   - Publishes state to SwiftUI on the main actor.

7. **SwiftUI views**
   - `MenuBarContentView`, `ShortcutListView`, `ShortcutRowView`, `DependenciesView`, `DiagnosticsView`, and `InstallRepairView`.
   - Uses native macOS controls and accessibility labels.

## Runtime and Configuration Flow

The App-managed configuration is JSON:

```json
{
  "schemaVersion": 1,
  "modules": {
    "window_screenshot": true,
    "local_ocr": true,
    "chatgpt_classic": false
  }
}
```

The Hammerspoon loader reads this file with `hs.json.read`, passes the `modules` map to `spoon.ShortcutKit:start`, and exposes a JSON-safe `shortcutKitAppStatus()` function. Existing `shortcutKitStatus()` remains for compatibility.

Toggle transaction:

1. User changes a checkbox.
2. AppModel captures the current config and runtime state.
3. ConfigStore writes the new config atomically.
4. HammerspoonBridge requests reload.
5. The bridge polls until the IPC endpoint returns the new module state.
6. On success, the UI commits the new state.
7. On timeout, missing status, or module error, ConfigStore restores the previous config, reloads again, and shows a specific error.

No toggle is reported successful until live Hammerspoon readback agrees with the requested state.

## Installation and Upgrade

The App bundle contains:

- `ShortcutKit.spoon`;
- the universal local OCR binary;
- installer, verifier, backup, restore, and Hammerspoon release metadata;
- shortcut catalog.

On first launch:

1. Detect Hammerspoon and the Spoon.
2. Show an install preview.
3. On user confirmation, run the bundled installer against the current user's Hammerspoon directory.
4. Write the App-aware loader and default JSON config.
5. Launch or reload Hammerspoon.
6. Verify live runtime status.

The App does not require administrator privileges. If Homebrew exists, the existing installer may use its Hammerspoon cask. Otherwise it uses the pinned official Hammerspoon ZIP and checksum. It never installs Homebrew itself.

Updates replace the Spoon only after a backup and preserve user module choices. The CLI lifecycle remains compatible with App-managed installations. Uninstall removes only ShortcutKit; Hammerspoon remains unless the user separately removes it.

## Distribution Outside the App Store

GitHub Releases is the canonical distribution channel. v0.2.0 publishes an unsigned DMG and ZIP, so Gatekeeper may require the user to use Open or approve the application in Privacy and Security. README documentation explains this boundary without suggesting security bypasses.

The packaging pipeline supports future Developer ID signing and Apple notarization when repository secrets and a paid Apple Developer identity are explicitly configured. Signing is not required for the initial open-source release.

## Error Handling

- Missing Hammerspoon: show Install, do not render module state as enabled.
- Missing dependency: disable only the affected module and retain the user's requested preference.
- Hotkey conflict: show the failing module and conflicting key; other modules remain active.
- Reload message-port invalidation: poll status rather than treating the reload command's exit code as final.
- Config parse failure: keep the last known good runtime, quarantine the invalid file through a recoverable rename, and present Restore.
- Installer failure: show the sanitized step and retain the pre-install backup.
- App crash: Hammerspoon continues running with the last valid configuration.

## Security and Privacy

- No network calls are required after installation except user-initiated update checks or downloads.
- OCR remains fully local through Apple Vision.
- App diagnostics are allow-listed and sanitized.
- Process execution uses fixed executable paths or validated bundle paths and argument arrays, never interpolated shell commands.
- Installer targets are validated before mutation.
- Mouse callbacks remain pass-through to preserve clicking, dragging, and three-finger drag.
- WhatsApp behavior remains restricted to the exact configured PWA bundle ID.

## Testing and Acceptance

### Automated tests

- Swift unit tests for catalog decoding, stable IDs, config merging, atomic writes, status decoding, sanitized diagnostics, and rollback decisions.
- Lua tests verify App JSON configuration mapping and the JSON status endpoint.
- Shell tests cover App packaging, embedded resource completeness, DMG/ZIP construction, checksums, and lifecycle compatibility.
- Public audit scans the App bundle staging tree and release archives for private paths, logs, backups, secrets, and unapproved binaries.
- CI builds the App and universal OCR helper on macOS, runs Swift/Lua/shell tests, packages release artifacts, and uploads them without publishing.

### Real-Mac acceptance

- Install the packaged App, not a development executable.
- Verify menu-bar and settings UI launch.
- Toggle at least one global module and one app-specific module off and on, with live status readback.
- Repeat three consecutive Command+R screenshots.
- Verify local OCR and dependency states.
- Confirm ordinary click, drag, and three-finger drag remain native.
- Exercise update, uninstall, restore, and final reinstall.
- Confirm the final runtime has no module errors.

### Release gate

- Clean `main` and public audit pass.
- GitHub Actions green on the release commit.
- Tag `v0.2.0` resolves to the tested commit.
- Release DMG, ZIP, and checksums match GitHub asset digests.
- Repository and release remain public under `ch1286122349-star/shortcut-kit`.

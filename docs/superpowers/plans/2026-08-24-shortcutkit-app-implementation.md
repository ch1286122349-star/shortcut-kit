# ShortcutKit macOS App Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build and publish ShortcutKit v0.2.0 as a native macOS menu-bar application that controls the existing Hammerspoon shortcut runtime through a checkbox UI.

**Architecture:** A dependency-free Swift Package produces a SwiftUI `LSUIElement` App. The App reads a bundled shortcut catalog, atomically manages a JSON config, invokes the existing reversible shell lifecycle, reloads Hammerspoon, and accepts a toggle only after live JSON status readback. Existing Lua modules remain the execution engine and shell commands remain the recovery path.

**Tech Stack:** Swift 6, SwiftUI, Foundation, ServiceManagement, XCTest, Lua/Hammerspoon, Bash, GitHub Actions, `hdiutil`, GitHub Releases.

**Spec:** `docs/superpowers/specs/2026-08-24-shortcutkit-app-design.md`

## Global Constraints

- Support macOS 13 and later; Hammerspoon 1.1.1 remains pinned by the existing installer.
- Add no third-party Swift, UI, build, package, or runtime dependencies.
- Keep Hammerspoon as the shortcut engine for v0.2.0.
- Preserve existing CLI install, update, uninstall, and restore behavior.
- Use `~/Library/Application Support/ShortcutKit/config.json` for App-managed preferences.
- Never grant or mutate TCC permissions; only read status and open System Settings.
- Preserve native mouse click, drag, and three-finger drag pass-through.
- Keep WhatsApp interception restricted to the exact configured PWA bundle ID.
- Publish unsigned DMG and ZIP artifacts through GitHub Releases; App Store submission and signing are deferred.
- Public repository and Release target remain `ch1286122349-star/shortcut-kit`.
- All external release writes occur only after local gates and GitHub Actions pass.

---

### Task 1: Swift Package, Shortcut Catalog, and Stable Models

**Files:**
- Create: `app/Package.swift`
- Create: `app/Sources/ShortcutKitCore/ShortcutDefinition.swift`
- Create: `app/Sources/ShortcutKitCore/ShortcutCatalog.swift`
- Create: `app/Sources/ShortcutKitApp/Resources/shortcut-catalog.json`
- Create: `app/Tests/ShortcutKitCoreTests/ShortcutCatalogTests.swift`
- Modify: `ShortcutKit.spoon/modules/init.lua`

**Interfaces:**
- Produces: `ShortcutDefinition: Codable, Identifiable, Equatable, Sendable`.
- Produces: `ShortcutCatalog.load(data:) throws -> [ShortcutDefinition]`.
- Produces: a stable `shortcut-catalog.json` whose IDs match every Lua module ID exactly.

- [ ] **Step 1: Write the failing catalog test**

```swift
import XCTest
@testable import ShortcutKitCore

final class ShortcutCatalogTests: XCTestCase {
    func testCatalogDecodesEveryRuntimeModuleExactlyOnce() throws {
        let data = try XCTUnwrap(Self.fixtureData(named: "shortcut-catalog"))
        let definitions = try ShortcutCatalog.load(data: data)
        XCTAssertEqual(Set(definitions.map(\.id)).count, definitions.count)
        XCTAssertEqual(Set(definitions.map(\.id)), [
            "window_screenshot", "command_space", "right_option",
            "left_mouse_modifier", "local_ocr", "chrome_recent_tabs",
            "chrome_mention", "codex_toggle", "mailmaster_toggle",
            "chatgpt_classic", "whatsapp_command_w", "btt_bridge"
        ])
    }
}
```

- [ ] **Step 2: Run the focused test and verify the red state**

Run: `cd app && swift test --filter ShortcutCatalogTests`

Expected: FAIL because the Swift package and catalog types do not exist.

- [ ] **Step 3: Implement the package and catalog types**

```swift
public struct ShortcutDefinition: Codable, Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let keys: [String]
    public let summary: String
    public let scope: String
    public let group: String
    public let dependency: String?
}

public enum ShortcutCatalog {
    public static func load(data: Data) throws -> [ShortcutDefinition] {
        let values = try JSONDecoder().decode([ShortcutDefinition].self, from: data)
        guard Set(values.map(\.id)).count == values.count else {
            throw CatalogError.duplicateID
        }
        return values
    }
}
```

Create 12 localized catalog entries using the exact shortcuts and descriptions already documented in `README.md`.

- [ ] **Step 4: Add a shell assertion that the catalog and Lua manifest IDs match**

Extend `tests/shell/public_audit_test.sh` with a `swift run ShortcutKitCatalogCheck` or equivalent test executable that fails on missing or extra IDs.

- [ ] **Step 5: Run tests and commit**

Run: `cd app && swift test && cd .. && ./scripts/run-lua-tests.sh && git diff --check`

Commit:

```bash
git add app ShortcutKit.spoon/modules/init.lua tests
git commit -m "feat: add ShortcutKit app catalog models"
```

### Task 2: Atomic App Configuration and Sanitized Diagnostics

**Files:**
- Create: `app/Sources/ShortcutKitCore/AppConfiguration.swift`
- Create: `app/Sources/ShortcutKitCore/ConfigStore.swift`
- Create: `app/Sources/ShortcutKitCore/DiagnosticsSanitizer.swift`
- Create: `app/Tests/ShortcutKitCoreTests/ConfigStoreTests.swift`
- Create: `app/Tests/ShortcutKitCoreTests/DiagnosticsSanitizerTests.swift`

**Interfaces:**
- Produces: `AppConfiguration(schemaVersion: Int, modules: [String: Bool])`.
- Produces: `ConfigStore.load()`, `ConfigStore.save(_:)`, `ConfigStore.restorePrevious()`.
- Produces: `DiagnosticsSanitizer.sanitize(_:) -> [String: String]`.

- [ ] **Step 1: Write failing atomic-write and unknown-key preservation tests**

```swift
func testSaveCreatesRecoverablePreviousConfiguration() throws {
    let store = ConfigStore(directory: temporaryDirectory)
    try store.save(.init(schemaVersion: 1, modules: ["local_ocr": true]))
    try store.save(.init(schemaVersion: 1, modules: ["local_ocr": false]))
    try store.restorePrevious()
    XCTAssertEqual(try store.load().modules["local_ocr"], true)
}

func testUpdatingKnownModulePreservesUnknownModule() throws {
    let original = AppConfiguration(schemaVersion: 1, modules: ["future_module": true])
    XCTAssertEqual(original.setting("future_module"), true)
}
```

- [ ] **Step 2: Verify the tests fail because ConfigStore is missing**

Run: `cd app && swift test --filter ConfigStoreTests`

- [ ] **Step 3: Implement same-directory temporary writes and rollback**

Use `FileManager.replaceItemAt` when the destination exists and `moveItem` on first write. Store `config.previous.json` before replacement. Refuse schema versions other than `1`, malformed module values, and directory targets.

- [ ] **Step 4: Write and implement diagnostics allow-list tests**

```swift
func testSanitizerDropsPathsAndPrivateContent() {
    let input = ["version": "0.2.0", "path": "/Users/local/private", "clipboard": "secret"]
    XCTAssertEqual(DiagnosticsSanitizer.sanitize(input), ["version": "0.2.0"])
}
```

Allow only `appVersion`, `spoonVersion`, `runtimeOK`, `enabledCount`, `disabledCount`, `skippedCount`, `errorCount`, and `lastReloadOutcome`.

- [ ] **Step 5: Run all Swift tests and commit**

```bash
cd app && swift test
cd ..
git add app
git commit -m "feat: add atomic app configuration storage"
```

### Task 3: Hammerspoon JSON Status and App-Aware Loader

**Files:**
- Modify: `ShortcutKit.spoon/init.lua`
- Modify: `ShortcutKit.spoon/lib/module_runner.lua`
- Create: `ShortcutKit.spoon/lib/app_config.lua`
- Modify: `scripts/patch-init.sh`
- Modify: `scripts/verify-install.sh`
- Create: `tests/lua/app_config_spec.lua`
- Modify: `tests/shell/lifecycle_test.sh`

**Interfaces:**
- Produces: `AppConfig.read(path, hsContext) -> table, error?`.
- Produces: `ShortcutKit:startFromAppConfig(path)`.
- Produces: global `shortcutKitAppStatus()` returning a JSON-safe table.
- Loader uses the App config path while preserving `shortcutKitStatus()`.

- [ ] **Step 1: Write failing Lua tests for missing, valid, and malformed App config**

```lua
local config, err = AppConfig.decode('{"schemaVersion":1,"modules":{"local_ocr":false}}')
helper.assertEqual(config.modules.local_ocr, false, "module setting maps to runtime config")

local invalid, invalidErr = AppConfig.decode('{"schemaVersion":2,"modules":{}}')
helper.assertEqual(invalid, nil, "unknown schema fails closed")
helper.assertEqual(invalidErr, "unsupported schemaVersion", "schema error is explicit")
```

- [ ] **Step 2: Run the focused Lua test and verify failure**

Run: `./scripts/run-lua-tests.sh app_config`

- [ ] **Step 3: Implement App config decoding and JSON-safe status**

The status table must include `ok`, `version`, and a `modules` map whose values contain only `state` and `reason`. Do not include local paths or application content.

- [ ] **Step 4: Update marked loaders idempotently**

`patch-init.sh add` must produce exactly one loader that:

```lua
require("hs.ipc")
hs.loadSpoon("ShortcutKit")
spoon.ShortcutKit:startFromAppConfig()
shortcutKitStatus = function() return spoon.ShortcutKit:status() end
shortcutKitAppStatus = function() return spoon.ShortcutKit:appStatus() end
```

It must remove both the v0.1.0 loader and repeated App-aware loaders without touching unrelated `require("hs.ipc")` calls.

- [ ] **Step 5: Extend repeated-install lifecycle tests and commit**

Run: `./scripts/run-lua-tests.sh && ./scripts/run-shell-tests.sh && git diff --check`

Commit:

```bash
git add ShortcutKit.spoon scripts tests
git commit -m "feat: add app-managed Hammerspoon configuration"
```

### Task 4: Process Runner and Hammerspoon Bridge

**Files:**
- Create: `app/Sources/ShortcutKitCore/ProcessRunning.swift`
- Create: `app/Sources/ShortcutKitCore/ProcessRunner.swift`
- Create: `app/Sources/ShortcutKitCore/RuntimeReport.swift`
- Create: `app/Sources/ShortcutKitCore/HammerspoonBridge.swift`
- Create: `app/Tests/ShortcutKitCoreTests/HammerspoonBridgeTests.swift`

**Interfaces:**
- Produces: `ProcessRunning.run(executable:arguments:timeout:) async throws -> ProcessResult`.
- Produces: `RuntimeReport: Codable, Equatable, Sendable`.
- Produces: `HammerspoonBridge.status() async throws -> RuntimeReport`.
- Produces: `HammerspoonBridge.reloadAndWait(expected:timeout:) async throws -> RuntimeReport`.

- [ ] **Step 1: Write failing bridge tests with a fake ProcessRunning implementation**

```swift
func testReloadIgnoresExpectedPortInvalidationAndWaitsForStatus() async throws {
    let runner = FakeRunner(results: [
        .failure(exitCode: 69, stderr: "message port was invalidated"),
        .success(stdout: "missing"),
        .success(stdout: validRuntimeJSON)
    ])
    let report = try await HammerspoonBridge(runner: runner).reloadAndWait(expected: ["local_ocr": false])
    XCTAssertEqual(report.modules["local_ocr"]?.state, "skipped")
}
```

- [ ] **Step 2: Run the focused test and verify failure**

Run: `cd app && swift test --filter HammerspoonBridgeTests`

- [ ] **Step 3: Implement bounded Process execution**

Use `Process.executableURL`, argument arrays, `Pipe`, a cancellation task, and `process.terminate()` after the explicit timeout. Do not invoke `/bin/sh -c`.

- [ ] **Step 4: Implement status polling and requested-state validation**

Run Hammerspoon CLI with:

```text
-c return hs.json.encode(shortcutKitAppStatus and shortcutKitAppStatus() or {ok=false,error="missing"})
```

Poll every 250 milliseconds for up to 5 seconds. A reload succeeds only when the report is `ok` and every requested module matches enabled/disabled semantics.

- [ ] **Step 5: Run Swift tests and commit**

```bash
cd app && swift test
cd ..
git add app
git commit -m "feat: add Hammerspoon runtime bridge"
```

### Task 5: Transactional AppModel and Installation Service

**Files:**
- Create: `app/Sources/ShortcutKitCore/InstallationService.swift`
- Create: `app/Sources/ShortcutKitCore/AppController.swift`
- Create: `app/Tests/ShortcutKitCoreTests/AppControllerTests.swift`
- Create: `app/Tests/ShortcutKitCoreTests/InstallationServiceTests.swift`

**Interfaces:**
- Produces: `InstallationService.preview()`, `install()`, `repair()`, `uninstall()`, `restore()`.
- Produces: `@MainActor AppController` with `refresh()`, `setModule(id:enabled:)`, and `setAll(enabled:)`.

- [ ] **Step 1: Write the failing rollback transaction test**

```swift
func testFailedReloadRestoresPreviousConfigAndRuntime() async throws {
    let bridge = FakeBridge(reloadResults: [.failure(.timeout), .success(originalReport)])
    let controller = AppController(configStore: store, bridge: bridge, catalog: catalog)
    await controller.setModule(id: "local_ocr", enabled: false)
    XCTAssertEqual(try store.load().modules["local_ocr"], true)
    XCTAssertEqual(controller.error?.code, "reload_rolled_back")
}
```

- [ ] **Step 2: Run focused tests and verify failure**

Run: `cd app && swift test --filter AppControllerTests`

- [ ] **Step 3: Implement AppController state and rollback flow**

Disable controls while a transaction is running. Store the requested preference even when a dependency is missing, but treat a skipped dependency as a valid runtime outcome. Treat module errors and missing status as rollback failures.

- [ ] **Step 4: Implement InstallationService around fixed bundled executables**

Resolve resources through `Bundle.module` or the App resource directory. Pass `--root`, `--apply`, and `--skip-hammerspoon` as explicit argument elements. Validate that resource URLs remain inside the App bundle before execution.

- [ ] **Step 5: Run tests and commit**

```bash
cd app && swift test
cd ..
git add app
git commit -m "feat: add transactional shortcut controls"
```

### Task 6: SwiftUI Menu-Bar and Settings Interface

**Files:**
- Create: `app/Sources/ShortcutKitApp/ShortcutKitApp.swift`
- Create: `app/Sources/ShortcutKitApp/AppViewModel.swift`
- Create: `app/Sources/ShortcutKitApp/Views/MenuBarContentView.swift`
- Create: `app/Sources/ShortcutKitApp/Views/ShortcutListView.swift`
- Create: `app/Sources/ShortcutKitApp/Views/ShortcutRowView.swift`
- Create: `app/Sources/ShortcutKitApp/Views/DependenciesView.swift`
- Create: `app/Sources/ShortcutKitApp/Views/DiagnosticsView.swift`
- Create: `app/Sources/ShortcutKitApp/Views/InstallRepairView.swift`
- Create: `app/Sources/ShortcutKitApp/Services/LaunchAtLoginService.swift`
- Create: `app/Tests/ShortcutKitAppTests/AppViewModelTests.swift`

**Interfaces:**
- Produces: native `MenuBarExtra` and Settings scene.
- Produces: view states derived only from AppController and ShortcutCatalog.
- Produces: `LaunchAtLoginService.isEnabled` and `setEnabled(_:)` using `SMAppService.mainApp`.

- [ ] **Step 1: Write failing view-model tests**

```swift
func testRowsShowRequestedPreferenceAndLiveFailureSeparately() async {
    let model = AppViewModel(controller: controller)
    await model.refresh()
    let row = try! XCTUnwrap(model.rows.first { $0.id == "codex_toggle" })
    XCTAssertTrue(row.requestedEnabled)
    XCTAssertEqual(row.badge, .dependencyUnavailable)
}
```

- [ ] **Step 2: Run tests and verify failure**

Run: `cd app && swift test --filter AppViewModelTests`

- [ ] **Step 3: Implement the menu and Settings scenes**

Use `MenuBarExtra("ShortcutKit", systemImage: "keyboard")` and a `WindowGroup` or Settings scene. Group rows by catalog group, use native Toggle controls, and expose accessibility labels containing title, key combination, requested state, and live state.

- [ ] **Step 4: Implement dependencies and diagnostics views**

Show specific actions: Install/Repair, Open Accessibility Settings, Open Screen Recording Settings, Refresh, Copy Sanitized Diagnostics, and Restore Previous Configuration. Do not display raw stdout or stderr.

- [ ] **Step 5: Build and run self-test mode**

Add `--self-test` handling that loads the catalog and config in a temporary directory, validates 12 rows, prints `ShortcutKitApp self-test: PASS`, and exits without opening UI.

Run: `cd app && swift run ShortcutKitApp --self-test`

- [ ] **Step 6: Commit**

```bash
git add app
git commit -m "feat: add ShortcutKit menu bar settings UI"
```

### Task 7: App Icon, App Bundle, DMG, ZIP, and Checksums

**Files:**
- Create: `app/Resources/AppIcon.iconset/`
- Create: `app/Resources/Info.plist`
- Create: `scripts/package-app.sh`
- Create: `scripts/package-dmg.sh`
- Create: `tests/shell/app_package_test.sh`
- Modify: `.gitignore`

**Interfaces:**
- `scripts/package-app.sh v0.2.0` produces `build/ShortcutKit.app`.
- `scripts/package-dmg.sh v0.2.0` produces DMG, ZIP, and `.sha256` files in `dist/`.

- [ ] **Step 1: Generate the original App icon through Imagegen**

Generate a clean macOS utility icon featuring a keyboard-key motif and subtle shortcut spark, no text, transparent-safe edges, and strong readability at 16 px. Save the approved source image, then use `sips` and `iconutil` only for mechanical resizing and `.icns` packaging.

- [ ] **Step 2: Write the failing package test**

```bash
./scripts/package-app.sh v0.2.0
test -x build/ShortcutKit.app/Contents/MacOS/ShortcutKitApp
test -f build/ShortcutKit.app/Contents/Resources/ShortcutKit.spoon/init.lua
test -x build/ShortcutKit.app/Contents/Resources/scripts/install.sh
/usr/libexec/PlistBuddy -c 'Print :LSUIElement' build/ShortcutKit.app/Contents/Info.plist | rg -q true
```

- [ ] **Step 3: Run the package test and verify failure**

Run: `bash tests/shell/app_package_test.sh`

- [ ] **Step 4: Implement deterministic App bundle packaging**

Compile with `swift build -c release --package-path app`. Copy the executable, Info.plist, icon, catalog, Spoon, and an allow-listed set of lifecycle scripts. Set bundle ID `com.shortcutkit.app`, minimum system `13.0`, version `0.2.0`, and `LSUIElement=true`.

- [ ] **Step 5: Implement DMG and ZIP packaging**

Use `hdiutil create -fs HFS+ -srcfolder build/ShortcutKit.app`. Use `ditto -c -k --sequesterRsrc --keepParent` for ZIP. Produce independent SHA-256 files and verify each immediately.

- [ ] **Step 6: Run package, audit staged bundle, and commit**

```bash
bash tests/shell/app_package_test.sh
./scripts/audit-public-files.sh build/ShortcutKit.app
./scripts/package-dmg.sh v0.2.0
cd dist && shasum -a 256 -c ShortcutKit-v0.2.0.dmg.sha256 && shasum -a 256 -c ShortcutKit-v0.2.0.zip.sha256
```

Commit:

```bash
git add app scripts tests .gitignore
git commit -m "feat: package ShortcutKit macOS app"
```

### Task 8: Documentation, CI, and Public Security Gate

**Files:**
- Modify: `README.md`
- Modify: `README.en.md`
- Modify: `SECURITY.md`
- Modify: `.github/workflows/ci.yml`
- Modify: `scripts/audit-public-files.sh`
- Create: `tests/manual/SHORTCUTKIT-APP-CHECKLIST.md`

**Interfaces:**
- CI builds and uploads v0.2.0 App candidate artifacts without publishing.
- README presents DMG installation first and CLI recovery second.

- [ ] **Step 1: Add a failing audit fixture for leaked App diagnostics**

Extend `public_audit_test.sh` with an App diagnostics fixture containing a private home path and assert the redacted rule name is returned without printing the path.

- [ ] **Step 2: Update public audit for App staging and archives**

Allow only the App executable and universal OCR Mach-O binaries at their exact bundle-relative paths. Reject embedded provisioning profiles, logs, backups, raw diagnostics, and unexpected executables.

- [ ] **Step 3: Update README and security documentation**

Document GitHub DMG installation, Gatekeeper warning, Hammerspoon as the background engine, every checkbox row, permission boundaries, update/recovery paths, and the exact statement that v0.2.0 is unsigned and not notarized.

- [ ] **Step 4: Extend CI**

Run `swift test`, App self-test, shell/Lua gates, universal OCR build, App package test, staged App audit, DMG/ZIP packaging, and artifact upload on `macos-latest`.

- [ ] **Step 5: Run the complete local gate and commit**

```bash
cd app && swift test && swift run ShortcutKitApp --self-test
cd ..
./scripts/run-lua-tests.sh
./scripts/run-shell-tests.sh
./scripts/audit-public-files.sh .
./scripts/package-dmg.sh v0.2.0
git diff --check
```

Commit:

```bash
git add README.md README.en.md SECURITY.md .github scripts tests/manual
git commit -m "docs: add ShortcutKit app installation workflow"
```

### Task 9: Real-Mac App Installation and Toggle Acceptance

**Files:**
- Modify: `tests/manual/SHORTCUTKIT-APP-CHECKLIST.md`
- Modify outside repo: user App installation and Hammerspoon configuration through the tested installer

**Interfaces:**
- Produces: installed `ShortcutKit.app`, live status readback, and sanitized acceptance results.

- [ ] **Step 1: Record the current v0.1.0 baseline**

Read `shortcutKitAppStatus()` or existing `shortcutKitStatus()`, App/Spoon files, module counts, and current backup availability without mutating config.

- [ ] **Step 2: Install the packaged App from `build/ShortcutKit.app`**

Move a copy to the current user's Applications folder through a recoverable staging operation. Launch it and verify menu-bar presence and Settings window through the real application process.

- [ ] **Step 3: Toggle one global and one app-specific module**

Disable and re-enable `window_screenshot` and `codex_toggle`. After every transition, read back config JSON and live Hammerspoon module states. A UI click or successful write without live readback does not pass.

- [ ] **Step 4: Run physical shortcut acceptance**

Repeat three Command+R captures, OCR, Chrome switching, MailMaster toggle, ChatGPT window toggle, WhatsApp exact-scope Command+W, right Option behavior, left-mouse C/V/D, ordinary click/drag, and three-finger drag. Record human-only items honestly.

- [ ] **Step 5: Exercise App repair and CLI recovery**

Run App repair, CLI update, uninstall, restore, and final App reinstall. Verify one loader, config preservation, backup recovery, and 12-module final status.

- [ ] **Step 6: Commit the sanitized acceptance result**

```bash
git add tests/manual/SHORTCUTKIT-APP-CHECKLIST.md
git commit -m "test: record ShortcutKit app acceptance"
```

### Task 10: Push, CI Readback, v0.2.0 Tag, and GitHub Release

**Files:**
- External: `ch1286122349-star/shortcut-kit` main, tag, GitHub Release, and assets

**Interfaces:**
- Produces: public v0.2.0 source, green CI URL, immutable tag, DMG, ZIP, and checksum asset URLs.

- [ ] **Step 1: Run final verification-before-completion gate**

Run the complete Swift, Lua, shell, public audit, App package, DMG/ZIP checksum, git status, and live Hammerspoon status commands on the exact commit to be pushed.

- [ ] **Step 2: Push main with routed Git credentials**

Verify `origin` owner is exactly `ch1286122349-star`, then push without switching the global GitHub CLI account.

- [ ] **Step 3: Wait for GitHub Actions and fix only evidence-backed failures**

Read the run for the pushed SHA. Do not tag while any required job is queued, running, or failed.

- [ ] **Step 4: Create and push annotated `v0.2.0` tag**

Confirm the tag does not already exist locally or remotely. Tag the green commit and push the exact tag.

- [ ] **Step 5: Publish GitHub Release assets**

Upload `ShortcutKit-v0.2.0.dmg`, `ShortcutKit-v0.2.0.zip`, and their checksum files using the confirmed `ch1286122349-star` token only.

- [ ] **Step 6: Final external and local readback**

Verify repository visibility, default branch, CI conclusion, tag dereference, Release draft/prerelease flags, each GitHub asset digest against local SHA-256, clean local main, and live runtime state.

# ShortcutKit Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build, verify, and publicly release an idempotent GitHub-installable Hammerspoon Spoon that migrates every currently active Hammerspoon shortcut on this Mac.

**Architecture:** A small `ShortcutKit.spoon` runtime loads isolated, dependency-aware modules through a shared registry and context adapter. Shell lifecycle scripts install or reuse Hammerspoon, back up and patch user configuration atomically, migrate the audited source machine only when fingerprints match, and restore on failure.

**Tech Stack:** Lua 5.4/Hammerspoon APIs, POSIX shell plus Bash 3.2-compatible scripts, Swift/AppKit/Vision for local OCR, GitHub Actions, Homebrew Cask, GitHub CLI.

**Spec:** `docs/superpowers/specs/2026-08-24-shortcut-kit-design.md`

## Global Constraints

- Support macOS 13 and newer.
- Publish under the MIT License in a public repository named `shortcut-kit`.
- Do not require App Store distribution, Apple Developer signing, notarization, telemetry, or cloud accounts.
- Never overwrite an unknown `~/.hammerspoon/init.lua`; add and remove only a marked loader block.
- Back up every modified file before writing and restore automatically after failed validation.
- Enable generic modules by default; enable app-specific modules only when their dependencies are detected.
- Do not log clipboard text, OCR output, window titles, Chrome URLs, chat content, or private file paths.
- Keep mouse down/up events pass-through so normal click, drag, and three-finger drag continue to work.
- Treat GitHub repository creation, push, tag, and release as separate verified states.
- Use the exact GitHub owner selected at the external-write gate; do not infer it from the active `gh` account.

## File Map

- `ShortcutKit.spoon/init.lua`: public Spoon entrypoint and module lifecycle.
- `ShortcutKit.spoon/config.lua`: defaults, merge rules, and schema validation.
- `ShortcutKit.spoon/lib/module_runner.lua`: dependency detection, failure isolation, and status aggregation.
- `ShortcutKit.spoon/lib/hotkey_registry.lua`: declared shortcut ownership and conflict decisions.
- `ShortcutKit.spoon/lib/app_detection.lua`: bundle-ID and application-path discovery.
- `ShortcutKit.spoon/lib/logger.lua`: privacy-safe structured local logging.
- `ShortcutKit.spoon/lib/safe_task.lua`: testable wrapper around `hs.task`.
- `ShortcutKit.spoon/modules/*.lua`: one behavior family per module.
- `ShortcutKit.spoon/bin/local-ocr.swift`: portable OCR source.
- `scripts/lib/common.sh`: strict shell helpers, temp paths, atomic writes, and reports.
- `scripts/preflight.sh`: environment, dependency, and conflict report.
- `scripts/install-hammerspoon.sh`: reuse, Homebrew Cask, or pinned official ZIP installation.
- `scripts/backup-config.sh`: immutable timestamped backup creation.
- `scripts/patch-init.sh`: marked loader-block insertion/removal.
- `scripts/migrate-source-machine.sh`: fingerprint-gated monolith-to-Spoon migration.
- `scripts/verify-install.sh`: static and live readback checks.
- `install.sh`, `update.sh`, `uninstall.sh`, `restore.sh`: lifecycle orchestration.
- `安装.command`, `更新.command`, `卸载.command`, `恢复.command`: Finder launchers.
- `tests/lua/*_spec.lua`: pure Lua and mocked-Hammerspoon tests.
- `tests/shell/*_test.sh`: lifecycle fixture tests.
- `tests/manual/REAL-MAC-CHECKLIST.md`: physical-event acceptance checklist.
- `scripts/audit-public-files.sh`: secrets, private path, log, and artifact gate.
- `.github/workflows/ci.yml`: syntax, test, shell, audit, and packaging checks.
- `README.md`, `README.en.md`, `SECURITY.md`, `CONTRIBUTING.md`, `LICENSE`: public delivery.

---

### Task 1: Portable Runtime, Configuration, and Test Harness

**Files:**
- Create: `ShortcutKit.spoon/init.lua`
- Create: `ShortcutKit.spoon/config.lua`
- Create: `ShortcutKit.spoon/lib/module_runner.lua`
- Create: `ShortcutKit.spoon/lib/hotkey_registry.lua`
- Create: `ShortcutKit.spoon/lib/app_detection.lua`
- Create: `ShortcutKit.spoon/lib/logger.lua`
- Create: `ShortcutKit.spoon/lib/safe_task.lua`
- Create: `tests/lua/test_helper.lua`
- Create: `tests/lua/runtime_spec.lua`
- Create: `scripts/run-lua-tests.sh`

**Interfaces:**
- Produces: `ShortcutKit:start(userConfig)`, `ShortcutKit:stop()`, `ShortcutKit:status()`.
- Produces: `Runner.new(options):start(modules, config, context)` returning `{modules = {...}, ok = boolean}`.
- Produces: `Registry.new(existing):claim(moduleId, actionId, modifiers, key)` returning `true` or `false, conflict`.
- Produces: `Config.load(defaults, user)` returning a deep-copied validated table.

- [ ] **Step 1: Write failing runtime and conflict tests**

```lua
local helper = require("test_helper")
local Runner = helper.requireProject("ShortcutKit.spoon.lib.module_runner")
local Registry = helper.requireProject("ShortcutKit.spoon.lib.hotkey_registry")

local started = {}
local result = Runner.new({ logger = helper.fakeLogger() }):start({
  { id = "good", detect = function() return true end,
    start = function() started.good = true end },
  { id = "missing", detect = function() return false, "app missing" end,
    start = function() error("must not run") end },
}, { modules = { good = true, missing = true } }, {})

assert(started.good == true)
assert(result.modules.missing.state == "skipped")

local registry = Registry.new({ ["cmd+r"] = "existing" })
local ok, conflict = registry:claim("window_screenshot", "capture", { "cmd" }, "r")
assert(ok == false and conflict.owner == "existing")
```

- [ ] **Step 2: Run the test and verify failure**

Run: `/opt/homebrew/bin/hs -c 'dofile("tests/lua/runtime_spec.lua")'`

Expected: failure because `module_runner` and `hotkey_registry` do not exist.

- [ ] **Step 3: Implement the minimal runtime and configuration boundaries**

```lua
function Runner:start(modules, config, context)
  local report = { modules = {}, ok = true }
  for _, module in ipairs(modules) do
    local enabled = config.modules[module.id] ~= false
    local detected, reason
    if enabled then
      detected, reason = module:detect(context)
    else
      detected, reason = false, "disabled"
    end
    if not detected then
      report.modules[module.id] = { state = "skipped", reason = reason }
    else
      local ok, err = xpcall(function() module:start(context, config) end, debug.traceback)
      report.modules[module.id] = { state = ok and "enabled" or "error", reason = err }
      report.ok = report.ok and ok
    end
  end
  return report
end
```

Implement deep-copy config merging, canonical key serialization (`cmd+shift+r` ordering), collision records, bundle detection, redacted logging, and a task adapter with injected `newTask` for tests.

- [ ] **Step 4: Run runtime tests and verify pass**

Run: `./scripts/run-lua-tests.sh`

Expected: `runtime_spec: PASS` and exit code `0`.

- [ ] **Step 5: Commit the runtime**

```bash
git add ShortcutKit.spoon tests/lua scripts/run-lua-tests.sh
git commit -m "feat: add modular ShortcutKit runtime"
```

### Task 2: Window Screenshot and Generic Keyboard/Mouse Modules

**Files:**
- Create: `ShortcutKit.spoon/modules/window_screenshot.lua`
- Create: `ShortcutKit.spoon/modules/command_space.lua`
- Create: `ShortcutKit.spoon/modules/right_option.lua`
- Create: `ShortcutKit.spoon/modules/left_mouse_modifier.lua`
- Create: `tests/lua/generic_modules_spec.lua`

**Interfaces:**
- Consumes: `context.hs`, `context.registry`, `context.logger`.
- Produces: modules implementing `id`, `detect`, `start`, `stop`, and `status`.
- `window_screenshot.findWindow(windows, point)` returns the first visible non-minimized containing window.

- [ ] **Step 1: Write failing generic-module tests**

```lua
local screenshot = helper.requireProject("ShortcutKit.spoon.modules.window_screenshot")
local windows = {
  helper.fakeWindow(11, { x = 0, y = 0, w = 100, h = 100 }, true),
  helper.fakeWindow(22, { x = 10, y = 10, w = 50, h = 50 }, true),
}
assert(screenshot.findWindow(windows, { x = 20, y = 20 }):id() == 11)

local mouse = helper.loadModule("left_mouse_modifier")
mouse:onMouseDown(1_000_000_000)
assert(mouse:onKeyDown("c", {}, false) == "cmd+c")
assert(mouse:onMouseUp() == false, "mouse up must pass through")
```

- [ ] **Step 2: Run the test and verify failure**

Run: `/opt/homebrew/bin/hs -c 'dofile("tests/lua/generic_modules_spec.lua")'`

Expected: missing module failure.

- [ ] **Step 3: Implement exact current-machine behavior**

```lua
local function captureWindow(window, task)
  return task:start("/usr/sbin/screencapture", { "-c", "-l", tostring(window:id()) })
end
```

Bind `Command+R` on key release, guard concurrent captures, and report direct task exit status. Implement `Command+Space -> Command+O`, 0.35-second right Option hold followed by three spaces, and the 0.05-second left-mouse C/V/D behavior. Generated C/V/D events must not recurse, autorepeat must be suppressed, and mouse callbacks must always return `false`.

- [ ] **Step 4: Run module tests and static checks**

Run: `./scripts/run-lua-tests.sh && git diff --check`

Expected: all tests pass and no whitespace errors.

- [ ] **Step 5: Commit generic modules**

```bash
git add ShortcutKit.spoon/modules tests/lua/generic_modules_spec.lua
git commit -m "feat: add screenshot and input shortcut modules"
```

### Task 3: Local Vision OCR Module and Cross-Architecture Packaging

**Files:**
- Create: `ShortcutKit.spoon/modules/local_ocr.lua`
- Create: `ShortcutKit.spoon/bin/local-ocr.swift`
- Create: `scripts/build-ocr.sh`
- Create: `tests/lua/local_ocr_spec.lua`
- Create: `tests/fixtures/ocr/hello-es-zh.png`

**Interfaces:**
- Consumes: `safe_task.start(path, args, callback)`.
- Produces: `local_ocr:start(context, config)`, `local_ocr:recognize(imagePath, callback)`.
- Produces: `build/local-ocr-<arch>` and `build/checksums.txt`.

- [ ] **Step 1: Copy the audited OCR source and write failing lifecycle tests**

```lua
local ocr = helper.loadModule("local_ocr", { binaryExists = true })
ocr:trigger()
assert(ocr:status().running == true)
ocr:testCompleteScreenshot(0, "/tmp/test.png")
ocr:testCompleteRecognition(0, "Hola 你好\n")
assert(ocr:status().running == false)
assert(helper.pasteboardValue() == "Hola 你好")
assert(helper.wasRemoved("/tmp/test.png"))
```

- [ ] **Step 2: Verify the test fails**

Run: `/opt/homebrew/bin/hs -c 'dofile("tests/lua/local_ocr_spec.lua")'`

Expected: missing OCR module failure.

- [ ] **Step 3: Implement OCR task state and build script**

Use `/usr/sbin/screencapture -i -x <temp.png>`, invoke the bundled Vision binary, trim output, write only successful non-empty text to the pasteboard, and remove the temporary file on every exit path.

```bash
xcrun swiftc -O -target arm64-apple-macos13.0 \
  ShortcutKit.spoon/bin/local-ocr.swift -o build/local-ocr-arm64
xcrun swiftc -O -target x86_64-apple-macos13.0 \
  ShortcutKit.spoon/bin/local-ocr.swift -o build/local-ocr-x86_64
lipo -create build/local-ocr-arm64 build/local-ocr-x86_64 \
  -output build/local-ocr-universal
```

The script detects unsupported targets and keeps separate architecture binaries when `lipo` cannot produce a universal binary.

- [ ] **Step 4: Run unit and binary self-tests**

Run: `./scripts/build-ocr.sh && ./build/local-ocr-$(uname -m) tests/fixtures/ocr/hello-es-zh.png`

Expected: stdout contains `Hola` and Chinese text; exit code `0`.

- [ ] **Step 5: Commit OCR support**

```bash
git add ShortcutKit.spoon/modules/local_ocr.lua ShortcutKit.spoon/bin scripts/build-ocr.sh tests
git commit -m "feat: add local Vision OCR shortcut"
```

### Task 4: Chrome Recent Tabs and Codex Mention Modules

**Files:**
- Create: `ShortcutKit.spoon/modules/chrome_recent_tabs.lua`
- Create: `ShortcutKit.spoon/modules/chrome_history.lua`
- Create: `ShortcutKit.spoon/modules/chrome_mention.lua`
- Create: `tests/lua/chrome_history_spec.lua`
- Create: `tests/lua/chrome_runtime_spec.lua`
- Create: `tests/manual/chrome_live.lua`

**Interfaces:**
- Produces: `History.new():record(windowId, tabId)`, `:remove`, and `:candidates`.
- Produces: `RecentTabs.new(options):toggle()` and `:setChromeActive(active)`.
- Produces: `chrome_mention` actions `withDown` and `withoutDown`.

- [ ] **Step 1: Port the three existing Recent Tabs tests as failing tests**

```lua
history:record(10, 101)
history:record(10, 102)
assertSequence(history:candidates(10, 102), { 101 })
assert(runtime:toggle() == false, "must not guess an unseen previous tab")
```

Add timing assertions that `@chrome` is typed before the delayed Tab and that only the `withDown` action sends Down.

- [ ] **Step 2: Run the focused tests and verify failure**

Run: `./scripts/run-lua-tests.sh chrome`

Expected: missing new modules.

- [ ] **Step 3: Port the stable implementation behind module boundaries**

Keep Chrome AppleScript limited to the current front window and tab IDs. Enable the `Command+3` event tap only while Chrome is frontmost. Record history after relevant mouse-up and Chrome tab-changing key events. Bind the two mention sequences to `Command+Shift+2/3`.

- [ ] **Step 4: Run pure tests and live Chrome boundary test**

Run: `./scripts/run-lua-tests.sh chrome && /opt/homebrew/bin/hs -c 'dofile("tests/manual/chrome_live.lua")'`

Expected: pure tests pass; live test reads the current Chrome window/tab and can reselect it.

- [ ] **Step 5: Commit Chrome modules**

```bash
git add ShortcutKit.spoon/modules/chrome_* tests/lua/chrome_* tests/manual/chrome_live.lua
git commit -m "feat: add Chrome and Codex mention shortcuts"
```

### Task 5: App-Aware Codex, MailMaster, ChatGPT Classic, and WhatsApp Modules

**Files:**
- Create: `ShortcutKit.spoon/modules/codex_toggle.lua`
- Create: `ShortcutKit.spoon/modules/mailmaster.lua`
- Create: `ShortcutKit.spoon/modules/chatgpt_classic.lua`
- Create: `ShortcutKit.spoon/modules/whatsapp_keep_window.lua`
- Create: `ShortcutKit.spoon/modules/btt_bridge.lua`
- Create: `tests/lua/app_modules_spec.lua`

**Interfaces:**
- Consumes: bundle candidates from `config.apps` and `app_detection.find(candidates)`.
- Produces: app module `detect/start/stop/status` interfaces.
- Produces: `chatgpt_classic.switchModel(mode)` returning `true, slug` or `false, reason`.

- [ ] **Step 1: Write failing dependency and behavior tests**

```lua
local codex = helper.loadModule("codex_toggle", { apps = { codex = false } })
local detected, reason = codex:detect(helper.context())
assert(detected == false and reason == "Codex is not installed")

local whatsapp = helper.loadModule("whatsapp_keep_window", {
  frontmostBundle = "com.example.whatsapp-pwa"
})
assert(whatsapp:onCommandW() == true)
assert(helper.frontmostWasHidden() == true)
```

- [ ] **Step 2: Verify focused tests fail**

Run: `./scripts/run-lua-tests.sh app_modules`

Expected: missing modules.

- [ ] **Step 3: Implement dependency-aware app modules**

Port only currently registered behavior. Do not carry the dormant broad `Command+W` focus-repair function into the public runtime. Parameterize bundle IDs and app paths. ChatGPT Classic model switching must validate the decoded preference object and configured slug before killing the app; failed validation disables only model switching.

```lua
if not conversation or type(conversation) ~= "table" then
  return false, "lastSelectedConversation is unavailable"
end
```

The BTT bridge must return `detect=false` unless BetterTouchTool and the named variable API are both readable.

- [ ] **Step 4: Run module tests and live dependency readback**

Run: `./scripts/run-lua-tests.sh app_modules && /opt/homebrew/bin/hs -c 'return shortcutKitDependencyReport()'`

Expected: installed apps report their matched bundle IDs; absent apps report skipped without errors.

- [ ] **Step 5: Commit app-aware modules**

```bash
git add ShortcutKit.spoon/modules tests/lua/app_modules_spec.lua
git commit -m "feat: add dependency-aware app shortcuts"
```

### Task 6: Installer, Backup, Patch, Update, Uninstall, and Restore

**Files:**
- Create: `scripts/lib/common.sh`
- Create: `scripts/preflight.sh`
- Create: `scripts/install-hammerspoon.sh`
- Create: `scripts/hammerspoon-release.env`
- Create: `scripts/backup-config.sh`
- Create: `scripts/patch-init.sh`
- Create: `scripts/verify-install.sh`
- Create: `install.sh`
- Create: `update.sh`
- Create: `uninstall.sh`
- Create: `restore.sh`
- Create: `安装.command`
- Create: `更新.command`
- Create: `卸载.command`
- Create: `恢复.command`
- Create: `tests/shell/install_test.sh`
- Create: `tests/shell/lifecycle_test.sh`
- Create: `tests/fixtures/hammerspoon/empty/`
- Create: `tests/fixtures/hammerspoon/existing/`
- Create: `tests/fixtures/hammerspoon/conflict/`

**Interfaces:**
- `install.sh --root "$fixture_root" --dry-run|--apply`, where `fixture_root` is an explicit temporary test directory.
- `patch-init.sh add|remove <init.lua>`.
- `backup-config.sh create <root>` prints the backup directory.
- `verify-install.sh --root <root> --offline` returns `0` only after static validation.

- [ ] **Step 1: Write failing shell lifecycle tests**

```bash
test_root="$(mktemp -d)"
cp -R tests/fixtures/hammerspoon/existing/. "$test_root/"
./install.sh --root "$test_root" --apply --skip-hammerspoon
test "$(grep -c 'shortcut-kit:begin' "$test_root/init.lua")" -eq 1
./install.sh --root "$test_root" --apply --skip-hammerspoon
test "$(grep -c 'shortcut-kit:begin' "$test_root/init.lua")" -eq 1
./uninstall.sh --root "$test_root" --apply
test "$(grep -c 'shortcut-kit:begin' "$test_root/init.lua")" -eq 0
```

- [ ] **Step 2: Run lifecycle tests and verify failure**

Run: `bash tests/shell/install_test.sh && bash tests/shell/lifecycle_test.sh`

Expected: missing installer failure.

- [ ] **Step 3: Implement atomic lifecycle scripts**

Use `mktemp -d`, trap cleanup, explicit validated paths, `cp -p`, and same-directory temporary files followed by `mv`. The marked block insertion uses `awk`; it refuses multiple existing begin/end markers. `--root` is required for fixtures and defaults to `$HOME/.hammerspoon` only for real installs.

Hammerspoon installation order is existing app, Homebrew Cask, then the pinned official ZIP. `scripts/hammerspoon-release.env` contains version `1.1.1`, URL `https://github.com/Hammerspoon/hammerspoon/releases/download/1.1.1/Hammerspoon-1.1.1.zip`, and SHA-256 `11bb1c90faf5427f37c7bd4fe7eab9774ae43e1d5cb020c5b3088dac32849efa`. The installer never installs Homebrew itself and never attempts to grant TCC permissions.

- [ ] **Step 4: Run all fixture tests**

Run: `bash tests/shell/install_test.sh && bash tests/shell/lifecycle_test.sh && git diff --check`

Expected: empty, existing, repeated, conflict, uninstall, and restore cases pass.

- [ ] **Step 5: Commit lifecycle scripts**

```bash
git add scripts install.sh update.sh uninstall.sh restore.sh *.command tests/shell tests/fixtures
git commit -m "feat: add safe one-command installer lifecycle"
```

### Task 7: Fingerprint-Gated Migration of This Mac

**Files:**
- Create: `scripts/migrate-source-machine.sh`
- Create: `scripts/source-fingerprints.txt`
- Create: `tests/shell/migration_test.sh`
- Create: `tests/fixtures/source-machine/`

**Interfaces:**
- `migrate-source-machine.sh --source <dir> --apply`.
- Fingerprint format: `<sha256>  <relative-path>`.
- Produces a minimal loader `init.lua` and an immutable rollback directory.

- [ ] **Step 1: Write failing exact-match and mismatch tests**

```bash
./scripts/migrate-source-machine.sh \
  --source tests/fixtures/source-machine/matching --apply
grep -q 'hs.loadSpoon("ShortcutKit")' tests/fixtures/source-machine/matching/init.lua

if ./scripts/migrate-source-machine.sh \
  --source tests/fixtures/source-machine/mismatch --apply; then
  echo "mismatch must fail closed" >&2
  exit 1
fi
```

- [ ] **Step 2: Run migration test and verify failure**

Run: `bash tests/shell/migration_test.sh`

Expected: missing migrator failure.

- [ ] **Step 3: Implement migration using audited fingerprints**

```text
0056a5f7c5c8d69f3e49a0c69bded38a4ab07d09c782476b892ebd0cf2107aaa  init.lua
9619149f406370ad513fcebd3092c3f55bbf16c45ad46967530d79949ef6a679  recent_tabs.lua
7ffcd3c0681a02ee069eda2d0fbeef645de40fe0f512bb7e59755e57b403ddf8  recent_tabs_history.lua
c076658e95cdbf774eaa9d56a6cb43b2526523af5f1465c687f9ebceae1cc471  bin/local-ocr.swift
```

Verify all four files before mutation. Copy the complete source tree to the rollback directory, install the Spoon, write the minimal loader atomically, reload, and invoke `shortcutKitStatus()`. Restore the rollback automatically when the readback is absent or reports a core-module error.

- [ ] **Step 4: Run matching, mismatch, and rollback tests**

Run: `bash tests/shell/migration_test.sh`

Expected: exact fixture migrates; one-byte mismatch and forced verification failure leave the source unchanged.

- [ ] **Step 5: Commit migration support**

```bash
git add scripts/migrate-source-machine.sh scripts/source-fingerprints.txt tests
git commit -m "feat: add fingerprint-gated source migration"
```

### Task 8: Public Documentation, Security Audit, CI, and Package Build

**Files:**
- Create: `README.md`
- Create: `README.en.md`
- Create: `SECURITY.md`
- Create: `CONTRIBUTING.md`
- Create: `LICENSE`
- Create: `config.example.lua`
- Create: `.gitignore`
- Create: `scripts/audit-public-files.sh`
- Create: `scripts/package-release.sh`
- Create: `scripts/run-shell-tests.sh`
- Create: `.github/workflows/ci.yml`
- Create: `tests/manual/REAL-MAC-CHECKLIST.md`
- Create: `tests/shell/public_audit_test.sh`

**Interfaces:**
- `audit-public-files.sh [tree]` fails on secrets, private home paths, logs, backups, or unapproved binaries.
- `package-release.sh <version>` creates `dist/shortcut-kit-<version>.zip` and checksum.

- [ ] **Step 1: Write the failing public audit test**

```bash
fixture="$(mktemp -d)"
printf 'path=/Users/%s/private\n' 'local-user' > "$fixture/leak.txt"
if ./scripts/audit-public-files.sh "$fixture"; then
  echo "private path leak must fail" >&2
  exit 1
fi
```

- [ ] **Step 2: Run audit and verify the intentional fixture fails**

Run: `bash tests/shell/public_audit_test.sh`

Expected: fixture is rejected with a redacted rule name.

- [ ] **Step 3: Write public docs, audit, CI, and packaging**

README must contain a 30-second install block, complete shortcut table, dependency auto-detection behavior, permission boundary, conflict policy, update/uninstall/restore commands, and troubleshooting. CI installs Lua and ShellCheck, runs Lua/shell tests, audits public files, builds OCR where supported, and packages without publishing.

```yaml
- run: brew install lua shellcheck
- run: ./scripts/run-lua-tests.sh
- run: bash tests/shell/install_test.sh && bash tests/shell/lifecycle_test.sh
- run: ./scripts/audit-public-files.sh .
- run: ./scripts/package-release.sh v0.1.0
```

- [ ] **Step 4: Run the complete local gate**

Run: `./scripts/run-lua-tests.sh && ./scripts/run-shell-tests.sh && ./scripts/audit-public-files.sh . && ./scripts/package-release.sh v0.1.0`

Expected: all gates pass; ZIP and SHA-256 exist in `dist/`.

- [ ] **Step 5: Commit public delivery files**

```bash
git add README.md README.en.md SECURITY.md CONTRIBUTING.md LICENSE config.example.lua scripts .github tests/manual
git commit -m "docs: add public installation and release workflow"
```

### Task 9: Real-Mac Migration and Physical Shortcut Acceptance

**Files:**
- Modify: `tests/manual/REAL-MAC-CHECKLIST.md`
- Create outside repo: `~/.hammerspoon/shortcut-kit/backups/$(date +%Y%m%d-%H%M%S)/`
- Modify outside repo: `~/.hammerspoon/init.lua`
- Install outside repo: `~/.hammerspoon/Spoons/ShortcutKit.spoon/`

**Interfaces:**
- Consumes: the full local test gate and fingerprint-gated migrator.
- Produces: live `shortcutKitStatus()` and a completed manual acceptance record with no private content.

- [ ] **Step 1: Record baseline runtime states**

Run:

```bash
/opt/homebrew/bin/hs -c 'return commandRWindowScreenshotStatus(), localOCRStatus(), leftMouseCommandStatus(), commandWRecovery.status()'
shasum -a 256 ~/.hammerspoon/init.lua ~/.hammerspoon/recent_tabs.lua \
  ~/.hammerspoon/recent_tabs_history.lua ~/.hammerspoon/bin/local-ocr.swift
```

Expected: all current taps are enabled and hashes match Task 7.

- [ ] **Step 2: Run dry-run migration and inspect the plan**

Run: `./scripts/migrate-source-machine.sh --source "$HOME/.hammerspoon" --dry-run`

Expected: exact fingerprint match, explicit backup target, no mutation.

- [ ] **Step 3: Apply migration and perform live readback**

Run: `./scripts/migrate-source-machine.sh --source "$HOME/.hammerspoon" --apply`

Expected: minimal loader installed, Spoon present, Hammerspoon reloaded, all available modules enabled, no core error.

- [ ] **Step 4: Execute the real shortcut checklist**

Verify three consecutive `Command+R` screenshots increase pasteboard image count; run OCR against the multilingual fixture; toggle Codex, Chrome tabs, MailMaster, ChatGPT Classic and WhatsApp; test right Option and left-mouse C/V/D; verify ordinary click, drag and three-finger drag remain native. Record actual results and any skipped app dependencies.

- [ ] **Step 5: Exercise update, uninstall, and restore on the live config**

Run the update lifecycle, uninstall ShortcutKit, verify the original configuration is restored, then reinstall the verified build. Confirm final status and backup recoverability.

- [ ] **Step 6: Commit the sanitized acceptance result**

```bash
git add tests/manual/REAL-MAC-CHECKLIST.md
git commit -m "test: record real Mac shortcut acceptance"
```

### Task 10: GitHub Repository, Push, CI Readback, Tag, and Release

**Files:**
- Modify: local Git remote configuration.
- Create externally: public GitHub repository `${SHORTCUT_KIT_GITHUB_OWNER}/shortcut-kit`, where the variable is set only after owner confirmation at the external-write gate.
- Create externally: tag and GitHub Release `v0.1.0`.

**Interfaces:**
- Consumes: clean `main`, full local gate, sanitized Git history, confirmed GitHub owner.
- Produces: public clone URL, successful CI run URL, immutable tag, release ZIP, and checksum.

- [ ] **Step 1: Verify repository and account boundary**

Run:

```bash
git status --short --branch
git log --oneline --decorate -10
./scripts/audit-public-files.sh .
```

Expected: clean `main`, no public audit findings. At this action boundary, select one explicitly confirmed logged-in GitHub owner; do not use plain `gh` based on the active account.

- [ ] **Step 2: Create the public repository with the routed CLI**

Run the owner-specific wrapper with repository name `shortcut-kit`, visibility `public`, source `.`, remote `origin`, and push enabled.

Expected: remote owner exactly matches the confirmed account and `origin` points to that repository.

- [ ] **Step 3: Read back remote branch and CI**

Run:

```bash
git remote -v
git ls-remote --heads origin main
"$SHORTCUT_KIT_GH" run list --repo "$SHORTCUT_KIT_GITHUB_OWNER/shortcut-kit" --limit 5
```

Expected: remote `main` SHA equals local HEAD; latest CI completes successfully.

- [ ] **Step 4: Create and push the verified tag**

```bash
git tag -a v0.1.0 -m "ShortcutKit v0.1.0"
git push origin v0.1.0
```

Expected: remote tag SHA resolves to the verified release commit.

- [ ] **Step 5: Create the GitHub Release and attach artifacts**

Run the routed GitHub CLI to create release `v0.1.0` with `dist/shortcut-kit-v0.1.0.zip` and its checksum.

Expected: release readback reports `isDraft=false`, `isPrerelease=false`, both assets present, and public download URLs.

- [ ] **Step 6: Verify a fresh clone installation fixture**

Clone the public repository into a temporary directory, run the offline fixture install suite from the clone, and compare package checksum with the release asset. Do not modify the live configuration during this check.

- [ ] **Step 7: Report final delivery boundaries**

Report separately: local implementation, automated tests, real-Mac migration, real shortcut acceptance, GitHub push, CI, tag, release assets, and the remaining boundary that a genuinely separate second Mac has not yet been tested unless one was available.

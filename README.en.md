# ShortcutKit

ShortcutKit is an open-source macOS menu-bar shortcut manager distributed through GitHub. It lists every shortcut, supports per-module toggles, records replacement key combinations, checks conflicts, and restores defaults. Hammerspoon remains the background runtime.

## Install the App

1. Download `ShortcutKit-v0.2.0.dmg` from the [v0.2.0 GitHub Release](https://github.com/ch1286122349-star/shortcut-kit/releases/tag/v0.2.0).
2. Open the DMG and drag `ShortcutKit.app` into Applications.
3. On first launch, use Finder's **Open** command or allow the App in Privacy & Security if Gatekeeper shows an unidentified-developer warning.
4. Open **Permissions & Dependencies** and choose **Install or Repair**. The bundled installer also installs Hammerspoon when it is missing.
5. Grant Accessibility and Screen Recording to Hammerspoon when macOS asks.

v0.2.0 is unsigned and not notarized. It does not use the Mac App Store. Download it only from this repository and verify the provided SHA-256 files.

### Source and recovery install

```bash
git clone https://github.com/ch1286122349-star/shortcut-kit.git
cd shortcut-kit
./install.sh --dry-run
./install.sh --apply
```

You can also double-click `安装.command`. If Hammerspoon is missing, the installer uses Homebrew Cask when available, otherwise it downloads the pinned official ZIP and verifies its SHA-256. It never installs Homebrew or grants macOS permissions automatically.

Each app-specific module auto-detects its dependency and is skipped independently when unavailable.

## Customizable shortcuts

The combinations below are defaults, not fixed requirements. Click an ordinary shortcut in the App and press a replacement combination—for example, window capture can change from `⌘ R` to `⌃ ⇧ 5`. ShortcutKit checks its own enabled actions, active Hammerspoon claims, and macOS system assignments that Hammerspoon can report. Per-action and global reset controls remove only known overrides. User choices survive updates.

Long right Option and left-mouse gestures can be enabled or disabled in v0.2.0, while their internal timing and output rules remain read-only.

## Default shortcuts

| Shortcut | Action |
|---|---|
| `⌘ R` | Capture the window under the pointer to the clipboard |
| `⌘ S` | Select a region and run local Apple Vision OCR |
| `⌘ Space` | Send native `⌘ O` |
| Hold right `Option` for 0.35 s | Type three spaces unless used as a modifier |
| Hold left mouse + `C` / `V` / `D` | Copy, paste, or delete while mouse events pass through |
| Chrome `⌘ 3` | Return to the previous tab in the current window |
| `⌘ ⇧ 2` / `⌘ ⇧ 3` | Insert and accept the `@chrome` mention in Codex |
| `⌘ 2` | Toggle Codex and restore the previous window |
| `⌘ 5` / keypad `5` | Toggle MailMaster and repair main-window focus |
| `⌘ \`` / `⌘ §` | Toggle the ChatGPT Classic main window |
| `⌃ ⌥ 1–4` | Select ChatGPT Classic Auto, Instant, Thinking, or Pro |
| WhatsApp PWA `⌘ W` | Hide and preserve only the exact Edge WhatsApp PWA window |

## Lifecycle

```bash
./update.sh --apply --skip-hammerspoon
./uninstall.sh --apply
./restore.sh --apply
```

Installation backs up the existing config and adds one marked loader block. Confirmed shortcut conflicts fail closed. Uninstall removes ShortcutKit only; restore recovers the latest backup. The App stores user choices in `~/Library/Application Support/ShortcutKit/config.json`; advanced bundle-ID overrides remain documented in [`config.example.lua`](config.example.lua).

For security reports, see [SECURITY.md](SECURITY.md). Contributions are described in [CONTRIBUTING.md](CONTRIBUTING.md).

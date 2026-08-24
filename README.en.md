# ShortcutKit

ShortcutKit packages a tested set of macOS shortcuts as an auditable, reversible Hammerspoon configuration.

## Install in 30 seconds

```bash
git clone https://github.com/YOUR_GITHUB_USER/shortcut-kit.git
cd shortcut-kit
./install.sh --dry-run
./install.sh --apply
```

You can also double-click `安装.command`. If Hammerspoon is missing, the installer uses Homebrew Cask when available, otherwise it downloads the pinned official ZIP and verifies its SHA-256. It never installs Homebrew or grants macOS permissions automatically.

Grant Accessibility and Screen Recording to Hammerspoon when macOS prompts you. Each app-specific module auto-detects its dependency and is skipped independently when unavailable.

## Included shortcuts

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

Installation backs up the existing config and adds one marked loader block. Shortcut conflicts fail closed. Uninstall removes ShortcutKit only; restore recovers the latest backup. See [`config.example.lua`](config.example.lua) for module, hotkey, and bundle-ID overrides.

For security reports, see [SECURITY.md](SECURITY.md). Contributions are described in [CONTRIBUTING.md](CONTRIBUTING.md).

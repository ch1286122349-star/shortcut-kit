# ShortcutKit v0.1.0 Real-Mac Acceptance

This record contains outcomes only. Do not add usernames, home paths, window titles, clipboard text, screenshots, or application content.

## Baseline and migration

- [x] Existing runtime status captured before migration
- [x] Four audited source fingerprints matched
- [x] Dry-run completed without filesystem changes
- [x] Immutable rollback directory created
- [x] Minimal loader and `ShortcutKit.spoon` installed
- [x] `shortcutKitStatus()` returned no core-module error (12 enabled, 0 skipped, 0 errors)

## Physical shortcut checks

| Scenario | Result | Notes |
|---|---|---|
| Three consecutive `Command+R` window captures | Pass | Real system keystrokes increased clipboard count on all three attempts |
| `Command+S` multilingual local OCR | Partial | Installed universal helper recognized non-empty window text; interactive region selection remains human-only |
| `Command+Space` to native `Command+O` | Pending | |
| Right Option long hold and modifier pass-through | Pending | |
| Left-mouse `C` / `V` / `D` | Pending | |
| Ordinary click and drag pass-through | Pending | |
| macOS three-finger drag pass-through | Pending | |
| Chrome recent-tab toggle | Pass | Live Chrome window/tab readback and switch succeeded |
| Codex `@chrome` mentions on both hotkeys | Partial | Timing and identical behavior covered by tests; physical typing intentionally left for human check |
| Codex app toggle and previous-window restore | Partial | Toggle module hid Codex correctly; automated desktop focus could not validate the physical key path |
| MailMaster toggle and focus repair | Pass | Real system shortcut focused MailMaster, then hid it on the second press |
| ChatGPT Classic window and model shortcuts | Partial | Real window toggle hid the app; model preference writes were intentionally not exercised |
| WhatsApp Edge PWA `Command+W` | Pass | Real system shortcut hid the exact PWA; other-app behavior is covered by scope tests |
| Optional BTT bridge | Partial | Dependency and variable API enabled; physical drag release remains human-only |

## Lifecycle

- [x] Update preserves one loader and creates a backup
- [x] Uninstall removes only ShortcutKit
- [x] Restore recovers the pre-uninstall state
- [x] Verified build reinstalled as the final state
- [x] Final live status captured (12 enabled, 0 skipped, 0 errors)

Final verdict: **Automated and non-destructive real-Mac checks pass. Human-only input, drag, and model-write checks remain pending.**

# ShortcutKit v0.1.0 Real-Mac Acceptance

This record contains outcomes only. Do not add usernames, home paths, window titles, clipboard text, screenshots, or application content.

## Baseline and migration

- [ ] Existing runtime status captured before migration
- [ ] Four audited source fingerprints matched
- [ ] Dry-run completed without filesystem changes
- [ ] Immutable rollback directory created
- [ ] Minimal loader and `ShortcutKit.spoon` installed
- [ ] `shortcutKitStatus()` returned no core-module error

## Physical shortcut checks

| Scenario | Result | Notes |
|---|---|---|
| Three consecutive `Command+R` window captures | Pending | Confirm a new clipboard image each time |
| `Command+S` multilingual local OCR | Pending | Confirm text; no upload |
| `Command+Space` to native `Command+O` | Pending | |
| Right Option long hold and modifier pass-through | Pending | |
| Left-mouse `C` / `V` / `D` | Pending | |
| Ordinary click and drag pass-through | Pending | |
| macOS three-finger drag pass-through | Pending | |
| Chrome recent-tab toggle | Pending | |
| Codex `@chrome` mentions on both hotkeys | Pending | Wait before Tab |
| Codex app toggle and previous-window restore | Pending | |
| MailMaster toggle and focus repair | Pending | |
| ChatGPT Classic window and model shortcuts | Pending | Never test model write with invalid preferences |
| WhatsApp Edge PWA `Command+W` | Pending | Other apps must remain native |
| Optional BTT bridge | Pending | Skip only when dependency is absent |

## Lifecycle

- [ ] Update preserves one loader and creates a backup
- [ ] Uninstall removes only ShortcutKit
- [ ] Restore recovers the pre-uninstall state
- [ ] Verified build reinstalled as the final state
- [ ] Final live status captured

Final verdict: **Pending**

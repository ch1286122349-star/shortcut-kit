# Security Policy

ShortcutKit handles global keyboard and mouse events, screenshots, and local clipboard content, so changes deserve careful review.

Supported security fixes target the latest tagged release. To report a vulnerability, use GitHub's private security advisory feature after the repository is published. Do not include screenshots, clipboard contents, account identifiers, tokens, or private configuration in a public issue.

The installer does not grant TCC permissions, install Homebrew, upload OCR images, or silently replace an unbacked configuration. App diagnostics use an allow-list and exclude usernames, private paths, window titles, clipboard contents, screenshots, OCR text, and tokens.

v0.2.0 is distributed as an unsigned, unnotarized DMG and ZIP outside the Mac App Store. Release archives include independent SHA-256 checksum files. The App validates bundled installer paths before execution, uses argument arrays rather than interpolated shell commands, and rolls back a shortcut configuration when live Hammerspoon readback does not match the requested state.

# Contributing

1. Fork the repository and create a focused branch.
2. Add a failing test before changing behavior.
3. Run `./scripts/run-lua-tests.sh`, `./scripts/run-shell-tests.sh`, and `./scripts/audit-public-files.sh .`.
4. Keep mouse events pass-through and app-specific behavior scoped to exact bundle IDs.
5. Never commit logs, backups, personal paths, screenshots, clipboard data, credentials, or private app state.

Explain the macOS version, app dependency, shortcut conflict risk, and real-device checks in the pull request.

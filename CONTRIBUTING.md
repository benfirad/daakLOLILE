# Contributing to daakLOLILE

Thank you for helping improve safe, privacy-preserving relay operations.

## Good contributions

- hardware sensor compatibility fixes;
- translations and accessibility improvements;
- clearer non-exit relay guidance;
- local smart-plug integrations that do not require cloud credentials;
- Windows service reliability improvements;
- macOS menu bar usability fixes;
- tests that prevent accidental remote write access.

## Development rules

1. Never include real recovery phrases, API tokens, auth cookies, private keys, operator email addresses, Tailscale IPs, or relay fingerprints in commits, screenshots, issues, or test fixtures.
2. Keep remote dashboard access read-only.
3. Preserve `ExitRelay 0` and `ExitPolicy reject *:*` guidance.
4. Pin downloaded executable dependencies and verify checksums.
5. Clearly distinguish measured values from estimates.
6. Test PowerShell changes with Windows PowerShell 5.1 as well as newer PowerShell when possible.

## Pull requests

Describe the user-visible behavior, security impact, rollback path, and verification performed. Keep changes focused and include screenshots only with synthetic data.

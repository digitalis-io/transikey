# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]
### Added
- Flutter desktop application scaffold (macOS, Windows, Linux) with Clean Architecture layout
- `VaultApiClient` abstraction and Dio implementation: header injection, retry, redacted logging, TLS options, typed errors
- Token, userpass and AppRole sign-in; session renewal, expiry, inactivity lock, biometric unlock, revoke on sign-out
- Connection settings, connection test and live health, seal and version status
- Dynamic database credentials, lease countdown with renew and revoke
- SSH one-time passwords, public key signing with certificate download, attempt tokens
- Response wrapping, unwrapping and cubbyhole storage
- Navigation shell with collapsible sidebar, dark and light themes, keyboard shortcuts, privacy blur
- Clipboard auto-clear, masked secret fields
- Dev stack (`dev/docker-compose.yml`): OpenBao dev mode, PostgreSQL and an init container
- Makefile for code generation, tests, builds and the dev stack
- Unit, BDD (Gherkin) and live integration tests
- Apache-2.0 license
- One-time share links (`transikey://unwrap?...`) and a CLI one-liner for wrapped secrets; unwrap works without a session and confirms before contacting another server
- Transikey logo as application icon (macOS, Windows), sidebar and lock screen mark; `tool/make_icons.py` regenerates icons
- CI job for formatting, analysis and tests; tag-triggered release workflow that packages macOS, Windows and Linux builds with SHA-256 checksums
- Initial project scaffold bootstrapped from automation/bootstrap

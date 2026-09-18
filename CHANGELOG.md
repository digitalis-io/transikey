# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]
### Added
- Flutter desktop application scaffold (macOS, Windows, Linux) with Clean Architecture layout
- `VaultApiClient` abstraction and Dio implementation: header injection, retry, redacted logging, TLS options, typed errors
- Token, userpass and AppRole sign-in; session renewal, expiry, inactivity lock, biometric unlock
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
- LDAP sign-in and browser based OIDC sign-in (loopback callback on port 8250, state and nonce checked); configurable LDAP and OIDC mount paths
- OpenLDAP with a test user in the dev stack
- SSH server in the dev stack that accepts OpenBao signed certificates and one-time passwords (`vault-ssh-helper`)
- Connect section on the Database screen: copy-ready `psql` or `mysql` command and connection URI, with remembered host, port and database
- Connect section on the SSH screen: copy-ready `ssh`, `sshpass` and `CertificateFile` commands, with remembered user, host, port and key path
- CI job for formatting, analysis and tests; tag-triggered release workflow that packages macOS, Windows and Linux builds with SHA-256 checksums
- Initial project scaffold bootstrapped from automation/bootstrap

### Changed
- Sign-out revokes only tokens the app created at login; a token you pasted in stays valid
- Redirects are never followed and clients for another server never carry the session token
- Action buttons keep their label when no role is selected and show a hint instead

### Fixed
- Credentials of the previous role stayed on screen after picking another role (Database and SSH)
- A key released while a dialog or the browser had focus stayed "pressed" and blocked typing; keyboard state resyncs on window focus
- Results of a request could appear under another tab after switching tabs
- Locking the session no longer loses the current screen

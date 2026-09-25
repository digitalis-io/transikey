# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]
### Added
- Kubernetes secrets engine: service account tokens per role and namespace (optional TTL and cluster-wide binding), mounts discovered from the server, namespace pre-filled from the role when policy allows
- Kubernetes Connect section: API server URL and CA path remembered per mount; copy the kubeconfig or save it as a `0600` file with a ready `KUBECONFIG=… kubectl` command. The token never goes into a command line
- k3s in the dev stack with Kubernetes roles `developer` (namespace `transikey-test`) and `viewer` (ClusterRole), plus `make dev-k3s-ca`
- Several database mounts at once: mounts are discovered from the server (`sys/internal/ui/mounts`), roles are grouped by mount, and the Database mount setting becomes a comma separated fallback
- Engine, host, port and database are detected from the role's connection when policy allows; otherwise they are chosen once and remembered per mount
- Cassandra (`cqlsh`) in the Connect section; the password is never part of the command
- Second database mount (`reporting`) and optional detection policy in the dev stack
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
- Server profiles: remember several servers with their namespace, TLS settings, mounts, Connect targets, last sign-in method and username; dropdown on the sign-in form, colour tag in the status bar, management under Settings; switching signs out first
- Import from the CLI environment on the sign-in form: `BAO_*` / `VAULT_*` address, namespace, CA, skip-verify and token, or the `~/.vault-token` file
- CI job for formatting, analysis and tests; tag-triggered release workflow that packages macOS, Windows and Linux builds with SHA-256 checksums
- Initial project scaffold bootstrapped from automation/bootstrap

### Changed
- Sign-out revokes only tokens the app created at login; a token you pasted in stays valid
- Redirects are never followed and clients for another server never carry the session token
- Action buttons keep their label when no role is selected and show a hint instead

### Fixed
- Credentials of the previous role stayed on screen after picking another role (Database and SSH)
- Debug builds: one out-of-sync key event (a key Flutter still believed pressed) blocked all typing until restart; the stale event is now dropped and the next key press recovers. The window-focus keyboard resync is gone: it could only add pressed keys, never clear them
- Database and SSH role lists were requested without a token while the session was locked or signed out; the resulting "Permission denied" stayed on screen until a manual refresh. Roles now load only for an active session and reload on sign-in and unlock
- Results of a request could appear under another tab after switching tabs
- Locking the session no longer loses the current screen
- Secret Sharing offered Wrap and Cubbyhole while signed out and failed with "permission denied"; those actions are now disabled with a sign-in hint, and the screen opens on Unwrap, which needs no session

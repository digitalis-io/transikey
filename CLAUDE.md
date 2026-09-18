# transikey - CLAUDE.md

## Project Overview

Transikey: Flutter desktop client (macOS, Windows, Linux) for OpenBao and HashiCorp Vault. Sign in, request dynamic database and SSH credentials, share secrets once. Repo: `github.com/digitalis-io/transikey` (Digitalis.io brand and commit identity).

Scaffolded with `--type other`: no stack-specific bootstrap plugin exists for Flutter.

## Current Status
- **Last Updated**: 2026-09-18
- **Current Phase**: Development
- **Health**: Green

## Global standards — see ~/.claude/DIGITALIS.md

Shared engineering standards live in `~/.claude/DIGITALIS.md` (installed from the `claude-skills` marketplace) and are **not** repeated here: terse communication, KnowledgeRelay/RAG sourcing for AxonOps/Digitalis/customer questions, secrets management, signed + DCO commits with brand-based identity, branding, README requirements, `CHANGELOG.md`, and the NEVER-DO list. This file covers only what is specific to `--type other` repos.

## Active Tasks
- PR #1 (`feat/flutter-scaffold` → `main`) open; keep its description in sync with new commits.
- First release tag not cut yet: `release.yml` is unproven until then.
- Commit `f7c433e` lacks `Signed-off-by` and a Conventional Commit subject; amend before merge if DCO is enforced.

## Recent Progress
- 2026-09-18: SSH target in dev stack, role-switch clearing, DB and SSH Connect sections, button label fix, docs review applied
- 2026-09-17: PR #1 opened; CI fixed (global gitignore hid `data/` dirs and `runner.exe.manifest`; fake PEM tripped detect-private-key)
- 2026-09-17: Keyboard resync on window focus (stuck key after dialog/browser steals focus); sign-out no longer revokes a user-supplied token
- Initial scaffold from `transikey`
- 2026-09-17: LDAP and OIDC login; OpenLDAP in dev stack
- 2026-09-17: Share links (`transikey://unwrap`), app icon from logo, CI + tag release workflow
- 2026-09-17: Flutter desktop client scaffold (auth, database, SSH, sharing, leases, settings), dev stack, Makefile, tests

## Blockers & Issues
- **GPG signing needs the user's terminal**: pinentry (curses) times out from Claude's shell once the agent cache expires. Ask the user to run `! echo test | gpg --clearsign -u sergio.rua@digitalis.io > /dev/null`, then commit.
- **Global `~/.gitignore` ignores `data/` and `*.manifest`**: after adding directories run `git status --short --ignored`; the repo `.gitignore` re-includes `lib/**/data/` and the Windows manifest.
- No screen capture or UI scripting permission in Claude's shell: UI is verified through widget-level BDD tests only, never visually.
- `hooks/validate-commit.sh --help` blocks on stdin: do not call it without input.
- Not verified: Windows and Linux builds, OIDC against a real IdP, `transikey://` on Windows/Linux, keyboard fix (not reproduced).
- `ssh/get-attempt-token` does not exist in OpenBao (`404 unsupported path`); client keeps the call per spec.

## Architecture & Key Decisions
- **Stack**: Flutter 3.32+ / Dart 3.8 desktop app (macOS, Windows, Linux). Riverpod 3 (Notifier/AsyncNotifier), go_router, Dio, Freezed. Layout: `lib/app`, `lib/core`, `lib/features/<name>/{domain,data,presentation}`
- **Generated code** (`*.g.dart`, `*.freezed.dart`) is git-ignored: run `make gen` after clone and after model or `.feature` changes
- **Secrets in models**: every model holding secret material overrides `toString()` with a redacted form; logging goes through `AppLogger` + `Redaction` only
- **Token location**: `TokenHolder` (memory) and OS keystore; never in provider state or models that reach the UI
- **Retries**: only requests that never reached the server (connect errors); credential endpoints are not idempotent
- **Tests**: `make check` (offline: unit + BDD via `bdd_widget_test`), `make dev-up && make test-integration` (live OpenBao + PostgreSQL)
- **macOS**: App Sandbox off and login keychain, so unsigned builds can use secure storage; revisit for signed releases
- **Logout**: revokes only tokens the app minted (userpass, LDAP, OIDC, AppRole); a pasted token is never revoked
- **Ad-hoc clients** (connection test, share link to another server) get their own empty `TokenHolder`; redirects are never followed
- **Share links**: `transikey://unwrap?addr=&ns=&token=`; prefill only, confirmation for a foreign server; `/sharing` route is public
- **OIDC**: loopback listener on `127.0.0.1:8250`, state + nonce checked (`features/auth/data/oidc_login_flow.dart`)
- **Connect sections**: host/port/db/user/key path are user settings (Vault does not return them); passwords go through env vars (`PGPASSWORD`, `MYSQL_PWD`, `SSHPASS`), never argv; all values pass `shellQuote`
- **Result providers** (`sshCredentialsProvider`, `secretSharingProvider`) are shared across tabs: a generation counter drops stale results; selecting another role clears them
- **Icons**: `python3 tool/make_icons.py` (pillow + numpy) regenerates macOS/Windows icons and `assets/branding/transikey_mark.png` from `assets/branding/TransiKey_Logo.jpeg`
- **Pre-commit**: standard hygiene hooks (trailing whitespace, EOF, YAML/JSON validation), `yamllint` (relaxed), `gitleaks` (secret scanning)

## Project Settings

| Item | Value |
|------|-------|
| Flutter / Dart | 3.32.8 / 3.8.1 (pinned in CI as `FLUTTER_VERSION`) |
| App id | `io.digitalis.transikey`, macOS deployment target 13.0 |
| Branch / PR | `feat/flutter-scaffold` → `main`, PR #1 |
| Commit identity | `Sergio Rua <sergio.rua@digitalis.io>`, GPG signed + `-s`; no AI trailers in commits, `Assisted-by: Claude Code` in the PR body |
| Setup | `make gen` (pub get + build_runner) |
| Offline checks | `make check` (analyze + unit + BDD) |
| Live tests | `make dev-up && make test-integration` (`BAO_ADDR=http://127.0.0.1:8200`, `BAO_TOKEN=root`) |
| Run / build | `make run`, `make build` |
| Release | push tag `vX.Y.Z[-suffix]` → `release.yml` packages macOS zip, Windows zip, Linux tar.gz + `SHA256SUMS.txt` |

Dev stack (`dev/docker-compose.yml`, all bound to `127.0.0.1`, subnet `172.30.0.0/24`):

| Service | Access | Credentials (dev-only defaults) |
|---------|--------|---------------------------------|
| OpenBao dev mode | `:8200` | token `root` |
| userpass | mount `userpass` | `demo` / `transikey-dev` |
| LDAP (OpenLDAP) | mount `ldap` | `ldapdemo` / `transikey-dev` |
| AppRole | mount `approle` | `make dev-approle` |
| PostgreSQL | `:5432`, db `app` | roles `readonly` (10m), `short-lived` (1m) |
| sshd | `:2222`, user `ubuntu`, container IP `172.30.0.10` | roles `sign` (CA cert), `otp` (request OTP for `172.30.0.10`) |

Policy `transikey` (in `dev/init.sh`) is the reference for least-privilege access the app needs.

Test layout: `test/core`, `test/features` (unit), `test/bdd/*.feature` + `test/bdd/step/` (BDD, generated `*_test.dart` committed), `test/integration` (tag `integration`).

## Required Claude Code plugins

Agents and slash commands live in the AxonOps shared marketplace at
`bitbucket.org/digitalisio/claude-skills`. Install once per developer using Claude Code's native plugin marketplace:

```text
/plugin marketplace add git@bitbucket.org:digitalisio/claude-skills.git
/plugin install engineering-agents@axonops-claude-skills
```

### Keeping skills current

Plugins evolve. Pull the latest catalog and update everything in one go:

```text
/plugin marketplace update axonops-claude-skills
/plugin update
```

Optional opt-in: a SessionStart hook can warn when this marketplace is behind. Paste into your personal `~/.claude/settings.json`:

```json
{
  "hooks": {
    "SessionStart": [{
      "matcher": "startup",
      "hooks": [{
        "type": "command",
        "command": "test -d ~/.claude/plugins/marketplaces/axonops-claude-skills && git -C ~/.claude/plugins/marketplaces/axonops-claude-skills fetch --quiet 2>/dev/null && [ \"$(git -C ~/.claude/plugins/marketplaces/axonops-claude-skills rev-list HEAD..origin/main --count 2>/dev/null || echo 0)\" -gt 0 ] && echo 'axonops-claude-skills: updates available — run /plugin marketplace update axonops-claude-skills && /plugin update'"
      }]
    }]
  }
}
```

The legacy `git clone … install.sh --plugin <name>` flow is still supported for non-Claude-Code consumers but is deprecated — it cannot track versions or report updates.

Plugins used:
- `engineering-agents` — `secrets-auditor`, `docs-quality-reviewer`, `code-reviewer`, `security-reviewer`, `shell-script-reviewer`, `tech-decision-maker`, `issue-writer` (generic), `bdd-guidelines` skill (generic BDD rules — see below)

No stack-specific plugin exists for `--type other`. If the content is mostly shell scripts, also rely on `shell-script-reviewer`. When a test suite is introduced (in any language), it must follow `engineering-agents:bdd-guidelines` and the matching stack-specific BDD skill from one of the bootstrap plugins.

## Workflow — Agent Gates

These agents are mandatory gates, not optional tools.

### Before any commit:
- **secrets-auditor** — verify no plaintext credentials, API keys, or tokens
- **docs-quality-reviewer** — if README or user-facing docs changed
- **shell-script-reviewer** — if any `.sh` file changed
- **`agent-skills:security-and-hardening`** — if anything touching credentials, TLS, or external input changed

### Before opening a PR:
- **`agent-skills:code-review-and-quality`** — five-axis review
- **docs-quality-reviewer** — README quality and branding compliance
- Pre-commit hooks pass

### Before creating any issue:
- **issue-writer** (generic, from `engineering-agents`) — full requirements, acceptance criteria, testing notes

## Standards

Branded `README.md`, `CHANGELOG.md` (Keep a Changelog), `LICENSE` (Apache-2.0 unless stated otherwise), and secrets handling all follow `~/.claude/DIGITALIS.md`. Additionally for `--type other` repos: no binaries unless absolutely necessary — prefer release artefacts on GitHub/Bitbucket releases.

#!/bin/bash
# Fetches the OpenBao SSH CA public key, then runs sshd in the foreground.
# Required environment: BAO_ADDR (for example http://openbao:8200).

set -euo pipefail

log() { printf '[sshd] %s\n' "$*"; }
die() { printf '[sshd] ERROR: %s\n' "$*" >&2; exit 1; }

[ -n "${BAO_ADDR:-}" ] || die "BAO_ADDR is not set"

log "waiting for the SSH CA at ${BAO_ADDR}/v1/ssh/public_key"
tries=0
until curl -fsS "${BAO_ADDR}/v1/ssh/public_key" -o /etc/ssh/trusted-user-ca-keys.pem; do
  tries=$((tries + 1))
  [ "$tries" -lt 60 ] || die "SSH CA not available after 60s"
  sleep 1
done
chmod 0644 /etc/ssh/trusted-user-ca-keys.pem
# Refuse anything that is not a public key (error page, empty body).
ssh-keygen -l -f /etc/ssh/trusted-user-ca-keys.pem >/dev/null 2>&1 \
  || die "the SSH CA response is not an SSH public key"
log "trusted CA: $(ssh-keygen -l -f /etc/ssh/trusted-user-ca-keys.pem)"

ssh-keygen -A >/dev/null
/usr/sbin/sshd -t
log "sshd ready: ssh -p 2222 ubuntu@127.0.0.1"
exec /usr/sbin/sshd -D -e

#!/bin/sh
# Configures the OpenBao dev server for Transikey testing:
#   - userpass user and AppRole role bound to the "transikey" policy
#   - database secrets engine connected to the compose PostgreSQL
#   - SSH secrets engine with an OTP role and a CA signing role
#
# Idempotent: safe to run again against the same server.
# Required environment: BAO_ADDR, BAO_TOKEN, DEV_POSTGRES_PASSWORD,
# DEV_USER, DEV_USER_PASSWORD.

set -eu

log() { printf '[init] %s\n' "$*"; }
die() { printf '[init] ERROR: %s\n' "$*" >&2; exit 1; }

for var in BAO_ADDR BAO_TOKEN DEV_POSTGRES_PASSWORD DEV_USER DEV_USER_PASSWORD; do
  eval "[ -n \"\${$var:-}\" ]" || die "$var is not set"
done
command -v bao >/dev/null 2>&1 || die "bao CLI not found"

# enable <auth|secrets> <type>: enables a mount unless it already exists.
enable() {
  kind=$1
  type=$2
  if bao "$kind" list -format=json | grep -q "\"$type/\""; then
    log "$kind $type already enabled"
  else
    bao "$kind" enable "$type" >/dev/null
    log "$kind $type enabled"
  fi
}

log "waiting for OpenBao at $BAO_ADDR"
tries=0
until bao status >/dev/null 2>&1; do
  tries=$((tries + 1))
  [ "$tries" -lt 60 ] || die "OpenBao not reachable after 60s"
  sleep 1
done

log "writing policy transikey"
bao policy write transikey - >/dev/null <<'POLICY'
# Dynamic database credentials
path "database/roles"    { capabilities = ["list"] }
path "database/creds/*"  { capabilities = ["read"] }

# SSH one-time passwords and certificate signing
path "ssh/roles"         { capabilities = ["list"] }
path "ssh/creds/*"       { capabilities = ["update"] }
path "ssh/sign/*"        { capabilities = ["update"] }

# Lease management
path "sys/leases/renew"  { capabilities = ["update"] }
path "sys/leases/revoke" { capabilities = ["update"] }

# Response wrapping (unwrap and cubbyhole come with the default policy)
path "sys/wrapping/wrap" { capabilities = ["update"] }
POLICY

enable auth userpass
bao write auth/userpass/users/"$DEV_USER" \
  password="$DEV_USER_PASSWORD" \
  token_policies=transikey \
  token_ttl=30m \
  token_max_ttl=4h >/dev/null
log "userpass user $DEV_USER ready"

enable auth approle
bao write auth/approle/role/transikey \
  token_policies=transikey \
  token_ttl=30m \
  token_max_ttl=4h >/dev/null
log "approle role transikey ready"

enable secrets database
bao write database/config/postgres \
  plugin_name=postgresql-database-plugin \
  allowed_roles="readonly,short-lived" \
  connection_url="postgresql://{{username}}:{{password}}@postgres:5432/app?sslmode=disable" \
  username=postgres \
  password="$DEV_POSTGRES_PASSWORD" >/dev/null

creation="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}'; GRANT SELECT ON ALL TABLES IN SCHEMA public TO \"{{name}}\";"
bao write database/roles/readonly \
  db_name=postgres \
  creation_statements="$creation" \
  default_ttl=10m \
  max_ttl=1h >/dev/null
# One-minute leases make the countdown and status colours easy to test.
bao write database/roles/short-lived \
  db_name=postgres \
  creation_statements="$creation" \
  default_ttl=1m \
  max_ttl=5m >/dev/null
log "database roles readonly, short-lived ready"

enable secrets ssh
bao write ssh/roles/otp \
  key_type=otp \
  default_user=ubuntu \
  cidr_list=0.0.0.0/0 >/dev/null
if ! bao read ssh/config/ca >/dev/null 2>&1; then
  bao write ssh/config/ca generate_signing_key=true >/dev/null
fi
bao write ssh/roles/sign \
  key_type=ca \
  allow_user_certificates=true \
  allowed_users="*" \
  default_user=ubuntu \
  ttl=30m >/dev/null
log "ssh roles otp, sign ready"

cat <<SUMMARY

[init] done. Sign in to Transikey with:
  address   http://127.0.0.1:8200 (or your DEV_BAO_PORT)
  token     the DEV_BAO_ROOT_TOKEN value (default: root)
  userpass  user "$DEV_USER", password from DEV_USER_PASSWORD
  approle   make dev-approle
SUMMARY

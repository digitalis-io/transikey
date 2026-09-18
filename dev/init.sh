#!/bin/sh
# Configures the OpenBao dev server for Transikey testing:
#   - userpass user, AppRole role and LDAP auth bound to the "transikey" policy
#   - database secrets engine connected to the compose PostgreSQL, mounted
#     twice (database, reporting)
#   - SSH secrets engine with an OTP role and a CA signing role
#
# Idempotent: safe to run again against the same server.
# Required environment: BAO_ADDR, BAO_TOKEN, DEV_POSTGRES_PASSWORD,
# DEV_USER, DEV_USER_PASSWORD, DEV_LDAP_ADMIN_PASSWORD.

set -eu

log() { printf '[init] %s\n' "$*"; }
die() { printf '[init] ERROR: %s\n' "$*" >&2; exit 1; }

for var in BAO_ADDR BAO_TOKEN DEV_POSTGRES_PASSWORD DEV_USER DEV_USER_PASSWORD \
  DEV_LDAP_ADMIN_PASSWORD; do
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

# Optional: lets the app detect the engine, host, port and database name
# behind a role, so the user does not have to type them. The server never
# returns the connection password on these paths.
path "database/roles/*"  { capabilities = ["read"] }
path "database/config/*" { capabilities = ["read"] }

# A second database mount, without the optional paths: the app asks for the
# engine and address here.
path "reporting/roles"   { capabilities = ["list"] }
path "reporting/creds/*" { capabilities = ["read"] }

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

enable auth ldap
bao write auth/ldap/config \
  url=ldap://openldap \
  binddn="cn=admin,dc=transikey,dc=test" \
  bindpass="$DEV_LDAP_ADMIN_PASSWORD" \
  userdn="ou=people,dc=transikey,dc=test" \
  userattr=uid \
  token_policies=transikey \
  token_ttl=30m \
  token_max_ttl=4h >/dev/null
log "ldap auth ready"

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

# Second mount of the same engine type: the app lists roles of every
# database mount it can see. enable() only handles a mount whose path equals
# its type, so the check is inline here.
if bao secrets list -format=json | grep -q "\"reporting/\""; then
  log "secrets reporting already enabled"
else
  bao secrets enable -path=reporting database >/dev/null
  log "secrets reporting enabled"
fi
bao write reporting/config/postgres \
  plugin_name=postgresql-database-plugin \
  allowed_roles="analyst" \
  connection_url="postgresql://{{username}}:{{password}}@postgres:5432/app?sslmode=disable" \
  username=postgres \
  password="$DEV_POSTGRES_PASSWORD" >/dev/null
bao write reporting/roles/analyst \
  db_name=postgres \
  creation_statements="$creation" \
  default_ttl=10m \
  max_ttl=1h >/dev/null
log "reporting role analyst ready"

enable secrets ssh
bao write ssh/roles/otp \
  key_type=otp \
  default_user=ubuntu \
  cidr_list=0.0.0.0/0 >/dev/null
if ! bao read ssh/config/ca >/dev/null 2>&1; then
  bao write ssh/config/ca generate_signing_key=true >/dev/null
fi
# JSON body: default_extensions is a map, which key=value syntax cannot express.
bao write ssh/roles/sign - >/dev/null <<'JSON'
{
  "key_type": "ca",
  "allow_user_certificates": true,
  "allowed_users": "*",
  "default_user": "ubuntu",
  "default_extensions": {"permit-pty": ""},
  "ttl": "30m"
}
JSON
log "ssh roles otp, sign ready"

cat <<SUMMARY

[init] done. Sign in to Transikey with:
  address   http://127.0.0.1:8200 (or your DEV_BAO_PORT)
  token     the DEV_BAO_ROOT_TOKEN value (default: root)
  userpass  user "$DEV_USER", password from DEV_USER_PASSWORD
  ldap      user from DEV_LDAP_USER (default: ldapdemo), password from DEV_LDAP_USER_PASSWORD

[init] SSH target: ssh -p 2222 ubuntu@127.0.0.1 (container IP 172.30.0.10, use it for OTPs)
  approle   make dev-approle
SUMMARY

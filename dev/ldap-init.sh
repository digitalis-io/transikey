#!/bin/bash
# Creates the people OU and one test user in the dev OpenLDAP server.
# Idempotent: entries that already exist are left alone.
# Required environment: LDAP_ADMIN_PASSWORD, DEV_LDAP_USER,
# DEV_LDAP_USER_PASSWORD.

set -euo pipefail

log() { printf '[ldap-init] %s\n' "$*"; }
die() { printf '[ldap-init] ERROR: %s\n' "$*" >&2; exit 1; }

for var in LDAP_ADMIN_PASSWORD DEV_LDAP_USER DEV_LDAP_USER_PASSWORD; do
  [ -n "${!var:-}" ] || die "$var is not set"
done

readonly BASE_DN="dc=transikey,dc=test"
readonly ADMIN_DN="cn=admin,${BASE_DN}"

# Secrets go through files (-y) and stdin, never through argv.
admin_pw_file=$(mktemp)
trap 'rm -f "$admin_pw_file"' EXIT
printf '%s' "$LDAP_ADMIN_PASSWORD" > "$admin_pw_file"

# add_entry: ldapadd from stdin; exit code 68 means "already exists".
add_entry() {
  local rc=0
  ldapadd -x -H ldap://openldap -D "$ADMIN_DN" -y "$admin_pw_file" >/dev/null 2>&1 || rc=$?
  [ "$rc" -eq 0 ] || [ "$rc" -eq 68 ] || die "ldapadd failed with code $rc"
  # An existing entry keeps its old password: run `make dev-reset` to change it.
  [ "$rc" -ne 68 ] || log "entry already exists, left unchanged"
}

add_entry <<LDIF
dn: ou=people,${BASE_DN}
objectClass: organizationalUnit
ou: people
LDIF

add_entry <<LDIF
dn: uid=${DEV_LDAP_USER},ou=people,${BASE_DN}
objectClass: inetOrgPerson
cn: ${DEV_LDAP_USER}
sn: Demo
uid: ${DEV_LDAP_USER}
userPassword: ${DEV_LDAP_USER_PASSWORD}
LDIF

log "user ${DEV_LDAP_USER} ready"

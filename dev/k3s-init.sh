#!/bin/sh
# Prepares the dev k3s cluster for the OpenBao Kubernetes secrets engine:
#   - namespaces transikey-test and transikey-sandbox, where the engine
#     creates service accounts
#   - service account openbao/kube-system with the rights the engine needs
#   - a long-lived token for that service account
# Writes the token and the cluster CA to $OUT_DIR for dev/init.sh.
#
# Idempotent: safe to run again against the same cluster.
# Required environment: KUBECONFIG, K3S_SERVER, OUT_DIR, DEV_K8S_NAMESPACE.

set -eu

log() { printf '[k3s-init] %s\n' "$*"; }
die() { printf '[k3s-init] ERROR: %s\n' "$*" >&2; exit 1; }

for var in KUBECONFIG K3S_SERVER OUT_DIR DEV_K8S_NAMESPACE; do
  eval "[ -n \"\${$var:-}\" ]" || die "$var is not set"
done

# k3s writes a kubeconfig for 127.0.0.1: point it at the compose service.
kc() { kubectl --server "$K3S_SERVER" "$@"; }

log "waiting for the API server at $K3S_SERVER"
tries=0
until [ -s "$KUBECONFIG" ] && kc get --raw /readyz >/dev/null 2>&1; do
  tries=$((tries + 1))
  [ "$tries" -lt 120 ] || die "k3s not ready after 120s"
  sleep 1
done

kc apply -f - >/dev/null <<YAML
apiVersion: v1
kind: Namespace
metadata:
  name: $DEV_K8S_NAMESPACE
---
apiVersion: v1
kind: Namespace
metadata:
  name: transikey-sandbox
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: openbao
  namespace: kube-system
---
# What the Kubernetes secrets engine needs to create service accounts,
# tokens, roles and bindings. Escalate and bind let it grant the rules of
# a generated role without holding them itself.
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: openbao-secrets-engine
rules:
  - apiGroups: [""]
    resources: ["namespaces"]
    verbs: ["get"]
  - apiGroups: [""]
    resources: ["serviceaccounts", "serviceaccounts/token"]
    verbs: ["create", "update", "delete"]
  - apiGroups: ["rbac.authorization.k8s.io"]
    resources: ["rolebindings", "clusterrolebindings"]
    verbs: ["create", "update", "delete"]
  - apiGroups: ["rbac.authorization.k8s.io"]
    resources: ["roles", "clusterroles"]
    verbs: ["bind", "escalate", "create", "update", "delete"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: openbao-secrets-engine
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: openbao-secrets-engine
subjects:
  - kind: ServiceAccount
    name: openbao
    namespace: kube-system
---
apiVersion: v1
kind: Secret
metadata:
  name: openbao-token
  namespace: kube-system
  annotations:
    kubernetes.io/service-account.name: openbao
type: kubernetes.io/service-account-token
YAML
log "namespaces $DEV_K8S_NAMESPACE, transikey-sandbox and service account openbao ready"

# The token controller fills the secret asynchronously.
tries=0
until token=$(kc -n kube-system get secret openbao-token \
  -o jsonpath='{.data.token}') && [ -n "$token" ]; do
  tries=$((tries + 1))
  [ "$tries" -lt 30 ] || die "service account token not issued after 30s"
  sleep 1
done

umask 077
printf '%s' "$token" | base64 -d > "$OUT_DIR/openbao.jwt"
kc -n kube-system get secret openbao-token -o jsonpath='{.data.ca\.crt}' \
  | base64 -d > "$OUT_DIR/ca.crt"
chmod 644 "$OUT_DIR/ca.crt"
# dev/init.sh runs as the openbao user of the OpenBao image.
chown "${BAO_UID:-100}" "$OUT_DIR/openbao.jwt"
log "token and CA written to $OUT_DIR"

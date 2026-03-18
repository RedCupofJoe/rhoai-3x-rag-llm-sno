#!/usr/bin/env bash
# Preflight: detect cert-manager conflicts before Argo / pattern-install reconciles operators.
#
# On licensed RHOCP, community cert-manager should not be installed; if found we WARN by default.
# Set CERTMANAGER_FAIL_ON_COMMUNITY=1 to fail the install instead.
# Always blocks:
#   - More than one openshift-cert-manager-operator subscription.
#
# Optional (set CERTMANAGER_AVOID_SUBSCRIPTION_RECONCILE=1):
#   - If Red Hat cert-manager is already Succeeded and values-prod.yaml still declares
#     clusterGroup.subscriptions.certmanager, exit with guidance (avoids re-reconcile churn).
#
# CERTMANAGER_PREFLIGHT_SKIP=1           — skip all checks
# CERTMANAGER_ALLOW_SUBSCRIPTION_RECONCILE=1 — bypass optional reconcile check

set -euo pipefail

err() { echo "Error: $*" >&2; }
info() { echo "Info: $*"; }

if [[ "${CERTMANAGER_PREFLIGHT_SKIP:-}" == "1" ]]; then
  info "CERTMANAGER_PREFLIGHT_SKIP=1 — skipping cert-manager preflight."
  exit 0
fi

if ! command -v oc &>/dev/null; then
  err "oc is required for cert-manager preflight."
  exit 1
fi

if ! oc whoami &>/dev/null; then
  err "Not logged in (oc login). Cannot check cert-manager state."
  exit 1
fi

PATTERN_DIR="${PATTERN_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"
VALUES_PROD="${CERTMANAGER_VALUES_FILE:-$PATTERN_DIR/values-prod.yaml}"

# --- Community cert-manager (unexpected on licensed RHOCP) ---
while IFS= read -r pkg src; do
  [[ -z "$pkg" || "$pkg" == "<none>" ]] && continue
  if [[ "$pkg" == "cert-manager" && "$src" == "community-operators" ]]; then
    if [[ "${CERTMANAGER_FAIL_ON_COMMUNITY:-}" == "1" ]]; then
      err "Community cert-manager Operator is present. Remove it before using RH cert-manager."
      err "See: docs/CERT-MANAGER-PREFLIGHT.md"
      exit 1
    fi
    info "Warning: community cert-manager subscription found (not expected on licensed RHOCP). Remove before production. CERTMANAGER_FAIL_ON_COMMUNITY=1 to fail install."
  fi
  if [[ "$pkg" == "cert-manager" && "$src" == *community* ]]; then
    if [[ "${CERTMANAGER_FAIL_ON_COMMUNITY:-}" == "1" ]]; then
      err "Community cert-manager source: $src — uninstall before this pattern."
      exit 1
    fi
    info "Warning: cert-manager from a community catalog ($src)."
  fi
done < <(oc get subscription -A -o go-template='{{range .items}}{{.spec.name}}{{" "}}{{.spec.source}}{{"\n"}}{{end}}' 2>/dev/null || true)

# --- Count Red Hat cert-manager operator subscriptions ---
rh_count=0
while IFS= read -r pkg; do
  [[ "$pkg" == "openshift-cert-manager-operator" ]] && rh_count=$((rh_count + 1)) || true
done < <(oc get subscription -A -o go-template='{{range .items}}{{.spec.name}}{{"\n"}}{{end}}' 2>/dev/null || true)

if (( rh_count > 1 )); then
  err "Multiple openshift-cert-manager-operator subscriptions ($rh_count). Only one is supported per cluster."
  oc get subscription -A -o custom-columns='NS:.metadata.namespace,NAME:.metadata.name,PKG:.spec.name' 2>/dev/null | grep -F openshift-cert-manager-operator || true
  exit 1
fi

# --- Optional: already-installed RH operator + Git still declares subscription ---
if [[ "${CERTMANAGER_AVOID_SUBSCRIPTION_RECONCILE:-}" == "1" && -f "$VALUES_PROD" ]]; then
  if [[ "${CERTMANAGER_ALLOW_SUBSCRIPTION_RECONCILE:-}" == "1" ]]; then
    info "CERTMANAGER_ALLOW_SUBSCRIPTION_RECONCILE=1 — bypassing duplicate-subscription guard."
    echo "cert-manager cluster check passed."
    exit 0
  fi
  csv_ok=false
  if oc get namespace cert-manager-operator &>/dev/null; then
    while IFS= read -r phase; do
      [[ "$phase" == "Succeeded" ]] && csv_ok=true && break
    done < <(oc get csv -n cert-manager-operator -o go-template='{{range .items}}{{.status.phase}}{{"\n"}}{{end}}' 2>/dev/null || true)
  fi
  if $csv_ok && grep -qE '^[[:space:]]*certmanager:' "$VALUES_PROD"; then
    err "Red Hat cert-manager Operator is already Succeeded, but values-prod.yaml still declares clusterGroup.subscriptions.certmanager."
    err "Re-applying that Subscription via Argo often causes webhook/TLS/auth instability."
    err ""
    err "Choose one:"
    err "  1) CERTMANAGER_ALLOW_SUBSCRIPTION_RECONCILE=1  (one-time if you accept reconcile)"
    err "  2) Add Argo CD ignoreDifferences for Subscription/openshift-cert-manager-operator (see docs)"
    err "  3) Remove certmanager: from values ONLY if syncPolicy.prune would not delete the Subscription"
    err ""
    err "See docs/CERT-MANAGER-PREFLIGHT.md"
    exit 1
  fi
fi

info "cert-manager preflight passed."
echo "cert-manager cluster check passed."
exit 0

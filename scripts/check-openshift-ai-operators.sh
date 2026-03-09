#!/usr/bin/env bash
# Check that OpenShift AI 3.0 operators are present and healthy on the cluster.
# Requires: oc (OpenShift CLI), cluster access (KUBECONFIG or oc login).
# Exit 0 if checks pass, non-zero with message if not.

set -euo pipefail

RHOAI_SUBSCRIPTION_NAME="rhods-operator"
RHOAI_NAMESPACE="redhat-ods-operator"
REQUIRED_MAJOR_VERSION="3"

err() { echo "Error: $*" >&2; }
info() { echo "Info: $*"; }

if ! command -v oc &>/dev/null; then
  err "oc (OpenShift CLI) is required but not installed or not in PATH."
  exit 1
fi

if ! oc whoami &>/dev/null; then
  err "Not logged into an OpenShift cluster. Run 'oc login' or set KUBECONFIG."
  exit 1
fi

# Check that the OpenShift AI (RHODS) operator subscription exists
if ! oc get subscription -n "$RHOAI_NAMESPACE" "$RHOAI_SUBSCRIPTION_NAME" &>/dev/null; then
  err "OpenShift AI 3.0 operator subscription not found: subscription/$RHOAI_SUBSCRIPTION_NAME in namespace $RHOAI_NAMESPACE."
  err "Install the operator first (e.g. via this pattern's operator-deploy or manually with channel fast-3.x)."
  exit 1
fi

info "Found subscription $RHOAI_SUBSCRIPTION_NAME in $RHOAI_NAMESPACE."

# Get installed CSV from subscription status
INSTALLED_CSV=$(oc get subscription -n "$RHOAI_NAMESPACE" "$RHOAI_SUBSCRIPTION_NAME" -o jsonpath='{.status.installedCSV}' 2>/dev/null || true)
if [[ -z "${INSTALLED_CSV:-}" ]]; then
  err "Subscription $RHOAI_SUBSCRIPTION_NAME has no installed CSV yet (operator may still be installing)."
  exit 1
fi

info "Installed CSV: $INSTALLED_CSV."

# Verify CSV exists and is Succeeded
if ! oc get csv -n "$RHOAI_NAMESPACE" "$INSTALLED_CSV" &>/dev/null; then
  err "ClusterServiceVersion $INSTALLED_CSV not found in $RHOAI_NAMESPACE."
  exit 1
fi

PHASE=$(oc get csv -n "$RHOAI_NAMESPACE" "$INSTALLED_CSV" -o jsonpath='{.status.phase}' 2>/dev/null || true)
if [[ "${PHASE:-}" != "Succeeded" ]]; then
  err "OpenShift AI operator CSV is not ready: phase is '${PHASE:-unknown}' (expected Succeeded)."
  exit 1
fi

# Optionally ensure we're on a 3.x version (CSV names typically look like rhods-operator.v3.x.y)
if [[ "$INSTALLED_CSV" =~ \.v([0-9]+)\.[0-9]+ ]]; then
  MAJOR="${BASH_REMATCH[1]}"
  if [[ "$MAJOR" != "$REQUIRED_MAJOR_VERSION" ]]; then
    err "OpenShift AI operator version is $MAJOR.x; this pattern requires OpenShift AI $REQUIRED_MAJOR_VERSION.x (subscription channel fast-3.x or stable-3.x)."
    exit 1
  fi
  info "OpenShift AI $REQUIRED_MAJOR_VERSION.x operator is present and Succeeded."
else
  info "OpenShift AI operator CSV is present and Succeeded (version not parsed from name)."
fi

echo "OpenShift AI 3.0 operators check passed."

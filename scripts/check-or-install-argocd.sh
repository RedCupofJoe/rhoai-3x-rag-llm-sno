#!/usr/bin/env bash
# Check that Argo CD (OpenShift GitOps Operator) is present; if not, install it before proceeding.
# Requires: oc (OpenShift CLI), cluster access with cluster-admin.
# Exit 0 when Argo CD is ready, non-zero with message on failure.

set -euo pipefail

GITOPS_SUBSCRIPTION_NAME="openshift-gitops-operator"
GITOPS_NAMESPACE_SUB="openshift-operators"
ARGOCD_NAMESPACE="openshift-gitops"
ARGOCD_WAIT_TIMEOUT="${ARGOCD_WAIT_TIMEOUT:-300}"  # seconds to wait for Argo CD after installing operator

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

# Check if Argo CD (GitOps) is already present and usable
argocd_ready() {
  if ! oc get namespace "$ARGOCD_NAMESPACE" &>/dev/null; then
    return 1
  fi
  # OpenShift GitOps creates deployments for server, repo-server, application-controller, etc.
  # Consider ready when at least one deployment has available replicas (or any pod is Running)
  if oc get deployment -n "$ARGOCD_NAMESPACE" --request-timeout=5s -o jsonpath='{.items[*].status.availableReplicas}' 2>/dev/null | grep -qE '^[1-9]'; then
    return 0
  fi
  if oc get pods -n "$ARGOCD_NAMESPACE" --field-selector=status.phase=Running --request-timeout=5s -o name 2>/dev/null | head -1 | grep -q .; then
    return 0
  fi
  return 1
}

if argocd_ready; then
  info "Argo CD (OpenShift GitOps) is already present in namespace $ARGOCD_NAMESPACE."
  echo "Argo CD check passed."
  exit 0
fi

# Check if the GitOps operator subscription exists but is still installing
if oc get subscription -n "$GITOPS_NAMESPACE_SUB" "$GITOPS_SUBSCRIPTION_NAME" &>/dev/null; then
  info "OpenShift GitOps Operator subscription found; waiting for Argo CD to become ready..."
  for (( i = 0; i < ARGOCD_WAIT_TIMEOUT; i += 10 )); do
    sleep 10
    if argocd_ready; then
      info "Argo CD is ready."
      echo "Argo CD check passed."
      exit 0
    fi
    info "Waiting for Argo CD... ($(( i + 10 ))s elapsed)"
  done
  err "Argo CD did not become ready within ${ARGOCD_WAIT_TIMEOUT}s. Check: oc get pods -n $ARGOCD_NAMESPACE"
  exit 1
fi

# Install the OpenShift GitOps Operator (Argo CD)
info "Argo CD (OpenShift GitOps) not found. Installing OpenShift GitOps Operator..."
if ! oc apply -f - <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: $GITOPS_SUBSCRIPTION_NAME
  namespace: $GITOPS_NAMESPACE_SUB
spec:
  channel: latest
  installPlanApproval: Automatic
  name: $GITOPS_SUBSCRIPTION_NAME
  source: redhat-operators
  sourceNamespace: openshift-marketplace
EOF
then
  err "Failed to create Subscription for OpenShift GitOps Operator. Ensure you have cluster-admin and redhat-operators catalog is available."
  exit 1
fi

info "Waiting for Argo CD to become ready (timeout ${ARGOCD_WAIT_TIMEOUT}s)..."
for (( i = 0; i < ARGOCD_WAIT_TIMEOUT; i += 10 )); do
  sleep 10
  if argocd_ready; then
    info "Argo CD is ready."
    echo "Argo CD check passed."
    exit 0
  fi
  info "Waiting for Argo CD... ($(( i + 10 ))s elapsed)"
done

err "Argo CD did not become ready within ${ARGOCD_WAIT_TIMEOUT}s. Check: oc get pods -n $ARGOCD_NAMESPACE; oc get csv -n $GITOPS_NAMESPACE_SUB"
exit 1

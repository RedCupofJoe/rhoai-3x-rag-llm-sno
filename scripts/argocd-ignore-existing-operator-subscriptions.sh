#!/usr/bin/env bash
# Patch the hub Argo CD Application(s) so GitOps does not overwrite existing operator
# Subscriptions (.spec / .status). Licensed RHOCP clusters often install operators outside
# this pattern; Argo would otherwise fight cluster-admin choices.
#
# Greenfield: Subscriptions missing from the cluster are still created from Git on sync.
#
# Env:
#   ARGOCD_APPLICATION_NAMESPACE   default: openshift-gitops
#   ARGOCD_APPLICATION_NAME        default: prod (clusterGroup.name)
#   ARGOCD_APPLICATION_NAMES       space-separated apps to patch

set -euo pipefail

err() { echo "Error: $*" >&2; }
info() { echo "Info: $*"; }

if ! command -v oc &>/dev/null || ! oc whoami &>/dev/null; then
  err "oc login required."
  exit 1
fi
if ! command -v jq &>/dev/null; then
  err "jq is required."
  exit 1
fi

NS="${ARGOCD_APPLICATION_NAMESPACE:-openshift-gitops}"
WAIT_SEC="${ARGOCD_APPLICATION_WAIT_SECONDS:-120}"

resolve_apps() {
  if [[ -n "${ARGOCD_APPLICATION_NAMES:-}" ]]; then
    read -r -a APPS <<< "${ARGOCD_APPLICATION_NAMES}"
    return 0
  fi
  local elapsed=0
  local name="${ARGOCD_APPLICATION_NAME:-}"
  if [[ -n "$name" ]]; then
    while (( elapsed < WAIT_SEC )); do
      oc get "application.argoproj.io/$name" -n "$NS" &>/dev/null && APPS=("$name") && return 0
      sleep 5
      elapsed=$((elapsed + 5))
    done
    err "Application $NS/$name not found after ${WAIT_SEC}s."
    return 1
  fi
  while (( elapsed < WAIT_SEC )); do
    for cand in prod hub rag-llm-sno-prod rag-llm-sno; do
      if oc get "application.argoproj.io/$cand" -n "$NS" &>/dev/null; then
        APPS=("$cand")
        info "Detected hub Application: $NS/$cand"
        return 0
      fi
    done
    sleep 5
    elapsed=$((elapsed + 5))
  done
  err "No hub Application in $NS after ${WAIT_SEC}s (tried prod, hub, rag-llm-sno-prod)."
  err "Run: make argocd-ignore-operator-subscriptions after the Application exists, or set ARGOCD_APPLICATION_NAME."
  return 1
}

APPS=()
resolve_apps || exit 1

patch_one() {
  local app="$1"
  if ! oc get "application.argoproj.io/$app" -n "$NS" &>/dev/null; then
    err "Application $NS/$app not found. List: oc get applications.argoproj.io -n $NS"
    err "Set ARGOCD_APPLICATION_NAME to your hub Application (often matches clusterGroup.name)."
    return 1
  fi

  local patch
  patch=$(oc get "application.argoproj.io/$app" -n "$NS" -o json | jq -c '
    if ((.spec.ignoreDifferences // []) | map(select(.group=="operators.coreos.com" and .kind=="Subscription")) | length) > 0 then
      empty
    else
      {spec:{ignoreDifferences: ((.spec.ignoreDifferences // []) + [{"group":"operators.coreos.com","kind":"Subscription","jqPathExpressions":[".spec",".status"]}])}}
    end
  ')

  if [[ -z "${patch:-}" ]]; then
    info "$NS/$app: Subscription ignoreDifferences already present."
    return 0
  fi

  oc patch "application.argoproj.io/$app" -n "$NS" --type merge -p "$patch"
  info "$NS/$app: added ignoreDifferences for operators.coreos.com/Subscription (spec+status)."
}

failed=0
for app in "${APPS[@]}"; do
  patch_one "$app" || failed=1
done
(( failed )) && exit 1
echo "Done. Argo CD will not overwrite existing operator Subscriptions when their spec/status differs from Git."
exit 0

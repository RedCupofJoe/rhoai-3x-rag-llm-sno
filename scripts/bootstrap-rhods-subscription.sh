#!/usr/bin/env bash
# Emergency: create OpenShift AI Subscription if GitOps has not created it (e.g. stuck sync).
# Idempotent. Commit/push values-prod.yaml fixes; this unblocks the cluster immediately.

set -euo pipefail
NS=redhat-ods-operator

oc get ns "$NS" &>/dev/null || oc create ns "$NS"

# Do NOT create OperatorGroup here — GitOps (values-prod) already creates one. A second OG causes
# OLM failures. If no OG exists yet, wait for Argo sync or create exactly one manually.
if ! oc get operatorgroup -n "$NS" -o name 2>/dev/null | grep -q .; then
  echo "No OperatorGroup in $NS — apply GitOps first or: oc apply -f docs/examples/redhat-ods-operatorgroup.yaml (one OG only)" >&2
  exit 1
fi

oc apply -f - <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: rhods-operator
  namespace: $NS
spec:
  channel: fast-3.x
  installPlanApproval: Automatic
  name: rhods-operator
  source: redhat-operators
  sourceNamespace: openshift-marketplace
EOF

echo "Subscription $NS/rhods-operator applied. Watch: oc get csv -n $NS -w"

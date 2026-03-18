# Cert-manager preflight (avoid duplicate / conflicting operators)

On **licensed Red Hat OpenShift**, the community cert-manager Operator should not be present. The preflight **warns** if it is found; use `CERTMANAGER_FAIL_ON_COMMUNITY=1` to fail the install.

Installing **cert-manager Operator for Red Hat OpenShift** when **community cert-manager** (or a second RH subscription) is already present causes competing webhooks, TLS, and **authentication errors**. This repo runs a **preflight check** before `make install`.

To stop Argo from overwriting **any** pre-installed operator Subscription, see **[ARGO-OPERATORS-NO-OVERWRITE.md](ARGO-OPERATORS-NO-OVERWRITE.md)**.

## What runs automatically

`make install` runs **`scripts/check-cert-manager-cluster.sh`** after the Argo CD check and before `pattern-install`.

| Condition | Result |
|-----------|--------|
| Subscription **cert-manager** from **community-operators** | **Fail** — uninstall community operator first |
| More than one **openshift-cert-manager-operator** subscription | **Fail** — leave only one |
| Otherwise | **Pass** |

## If cert-manager is already installed (Red Hat)

If the operator is **already healthy** and Git still contains `clusterGroup.subscriptions.certmanager`, repeated Argo sync can still destabilize webhooks. Enable a **stricter** check:

```bash
export CERTMANAGER_AVOID_SUBSCRIPTION_RECONCILE=1
./pattern.sh make install
```

If the script stops with “already Succeeded” + values still declare `certmanager:`:

1. **`CERTMANAGER_ALLOW_SUBSCRIPTION_RECONCILE=1`** — proceed for this run (use sparingly).
2. **Argo CD** — add `ignoreDifferences` on the Subscription so GitOps does not fight the live operator (example below).
3. **Remove** the `certmanager:` block from `values-prod.yaml` only if your Application **does not prune** Subscriptions you care about (otherwise the operator could be removed).

### Example: `ignoreDifferences` on the pattern Application

```yaml
spec:
  ignoreDifferences:
    - group: operators.coreos.com
      kind: Subscription
      name: openshift-cert-manager-operator
      namespace: cert-manager-operator
      jqPathExpressions:
        - .spec
        - .status
```

Tune to match your hub Application name/namespace. See [Argo CD ignoreDifferences](https://argo-cd.readthedocs.io/en/stable/user-guide/diffing/#application-level-configuration).

## Skip or bypass checks

| Variable | Effect |
|----------|--------|
| `CERTMANAGER_PREFLIGHT_SKIP=1` | Skip the entire cert-manager preflight |
| `CERTMANAGER_VALUES_FILE=/path/to/values.yaml` | File checked for `certmanager:` when using strict reconcile mode |
| `CERTMANAGER_ALLOW_SUBSCRIPTION_RECONCILE=1` | Bypass strict “already installed + values declare subscription” |

## Uninstall community cert-manager (outline)

1. In **OperatorHub** / **Installed Operators**, uninstall **cert-manager** from the **community** catalog, **or**:
2. `oc delete subscription -n <ns> <subscription-name>` and related CSV/OperatorGroup as appropriate for that install.

Do **not** run community cert-manager and **cert-manager Operator for Red Hat OpenShift** on the same cluster.

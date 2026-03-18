# Argo CD: do not overwrite existing operator Subscriptions

On **licensed Red Hat OpenShift**, operators are normally installed from **Red Hat catalogs** (no community cert-manager). This pattern still declares the same Subscriptions in Git. If those operators were **already installed** (installer, another team, or earlier sync), Argo CD can try to **reconcile** Subscription `.spec` / `.status` and destabilize the cluster.

## Automatic fix (recommended)

After each `make install`, the Makefile runs:

```bash
./scripts/argocd-ignore-existing-operator-subscriptions.sh
```

That patches the **hub** Argo CD `Application` in `openshift-gitops` (auto-detects `prod`, `hub`, `rag-llm-sno-prod`, or `rag-llm-sno`; waits up to **120s** after `pattern-install`) with:

```yaml
ignoreDifferences:
  - group: operators.coreos.com
    kind: Subscription
    jqPathExpressions:
      - .spec
      - .status
```

Effects:

- **Existing** Subscriptions on the cluster are **not** overwritten when they differ from Git (channel, approval, etc.).
- **Missing** Subscriptions are still **created** from Git on sync (first-time install).

### If the script cannot find your Application

```bash
oc get applications.argoproj.io -n openshift-gitops
export ARGOCD_APPLICATION_NAME=<your-hub-app-name>
./scripts/argocd-ignore-existing-operator-subscriptions.sh
```

Multiple apps:

```bash
export ARGOCD_APPLICATION_NAMES="prod other-app"
./scripts/argocd-ignore-existing-operator-subscriptions.sh
```

## Before the first sync (operators already on the cluster)

If operators exist **before** the hub Application syncs for the first time:

1. **Suspend** auto-sync on the hub Application (OpenShift GitOps UI or CLI), **or** create the Application with sync off.
2. Run `./scripts/argocd-ignore-existing-operator-subscriptions.sh`.
3. Re-enable sync.

Otherwise the first sync may still apply Subscription manifests once; ignoring drift mainly stops **ongoing** fights after that.

## Makefile targets

| Target | Purpose |
|--------|---------|
| `make argocd-ignore-operator-subscriptions` | Patch hub Application(s) only |
| `make install` | … then runs the script at the end (and a no-op attempt at the start if the Application already exists) |

## Cert-manager on RHOCP

Community **cert-manager** is not expected. The cert-manager preflight **warns** if it appears; set `CERTMANAGER_FAIL_ON_COMMUNITY=1` to fail the install instead.

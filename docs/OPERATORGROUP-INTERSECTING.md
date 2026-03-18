# Error: `intersecting operatorgroups provide the same apis`

OLM raises **`InterOperatorGroupOwnerConflict`** when **two OperatorGroups** target **overlapping namespaces** and operators in those groups **expose the same API** (same CRDs), or when **more than one OperatorGroup** exists in a namespace that only allows one.

## Can this repo cause it?

**Yes, in these situations:**

### 1. Duplicate OperatorGroup in `redhat-ods-operator`

This pattern (GitOps) creates an **OperatorGroup** in `redhat-ods-operator` when `values-prod.yaml` has:

```yaml
redhat-ods-operator:
  operatorGroup: true
  targetNamespaces: []
```

If you also ran **`scripts/bootstrap-rhods-subscription.sh`**, it creates **another** OperatorGroup when none existed—then GitOps may add a **second** one, or the opposite order leaves **two** OGs in the same namespace.

**Fix:**

```bash
oc get operatorgroup -n redhat-ods-operator
# Keep a single OperatorGroup; delete the extra:
oc delete operatorgroup <duplicate-name> -n redhat-ods-operator
```

Then refresh the failing Subscription / CSV.

### 2. OpenShift Serverless + OpenShift AI (global OperatorGroups)

The pattern installs **both**:

- **OpenShift Serverless** (`openshift-serverless` namespace, OperatorGroup with all namespaces)
- **OpenShift AI** (`redhat-ods-operator`, OperatorGroup with all namespaces)

On some versions, **both** ship or claim **overlapping APIs** (e.g. Knative-related), which triggers **intersecting operatorgroups**.

**Fix options:**

- **A)** Install **OpenShift Serverless** and **Service Mesh** **manually first** (OperatorHub, following Red Hat docs). Then **remove** the `serverless` and `servicemesh` entries from **`values-prod.yaml`** `subscriptions` (and avoid a second OperatorGroup in `openshift-serverless` from GitOps). Let the pattern manage only **rhoai** and the rest.
- **B)** Open a **Red Hat support case** with your OCP + RHOAI + Serverless versions—there may be a documented install order or scoped OperatorGroup.

### 3. Operator already installed elsewhere

If **OpenShift AI** or **Serverless** was installed earlier with another OperatorGroup configuration, GitOps may add **conflicting** resources.

**Fix:** Align with a **single** install path (console-only vs GitOps-only) or use Argo **`ignoreDifferences`** on Subscriptions/OperatorGroups after the cluster matches your desired state.

## Quick checks

```bash
oc get operatorgroup -A
oc get subscription -A | egrep 'rhods|serverless|servicemesh'
oc describe csv -n redhat-ods-operator
```

See also: Red Hat KB (search **InterOperatorGroupOwnerConflict**).

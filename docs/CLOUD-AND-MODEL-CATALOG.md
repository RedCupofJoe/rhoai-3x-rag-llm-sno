# Cloud GPU nodes + OpenShift AI model catalog

Use cluster group **`prod-cloud`** when:

1. **GPU nodes come from a cloud MachineSet** (AWS, Azure, GCP, etc.) and you do **not** need [Node Feature Discovery (NFD)](https://docs.openshift.com/container-platform/latest/nodes/scheduling/nodes-scheduling-node-feature-discovery.html) for this workload. The certified **NVIDIA GPU Operator** still runs and labels GPU nodes via its own discovery.
2. You want **models pulled/served via the OpenShift AI model catalog** (dashboard → deploy from catalog, single-model serving / KServe) instead of this repo’s GitOps **vLLM + Hugging Face** InferenceServices.

## Enable `prod-cloud`

In **`values-global.yaml`**:

```yaml
main:
  clusterGroupName: prod-cloud
```

Commit and let Argo sync. The hub Application must reference **`values-prod-cloud.yaml`** for that cluster group (same mechanism as `prod` → `values-prod.yaml` in Validated Patterns).

## What `prod-cloud` omits vs `prod`

| Item | `prod` | `prod-cloud` |
|------|--------|--------------|
| Namespace `openshift-nfd` | Yes | No |
| NFD subscription / app | Yes | No |
| GitOps vLLM InferenceServices (Granite, Gemma, GPT-OSS) | Yes | No |
| GPU Operator, LVMS, OpenShift AI, DSC, LlamaStack, UIs | Yes | Yes |

## Deploy models from the model catalog

1. In the **OpenShift AI dashboard**, open your project (**`rag-llm-sno`** if unchanged).
2. Use **Models** / **model catalog** (product UI may say “Deploy model” or “Model catalog”) and deploy with **single-model serving** as documented for your OpenShift AI version.
3. Note each deployment’s **InferenceService name** (model deployment name). The in-cluster predictor Service is typically:

   `http://<deployment-name>-predictor.rag-llm-sno.svc.cluster.local:80`

4. Edit overrides and replace placeholders:

   | File | Set |
   |------|-----|
   | `overrides/llamastack-cloud-catalog-values.yaml` | `inference.url`, `inference.model` (id the serving endpoint expects) |
   | `overrides/rag-llm-frontend-cloud-catalog-values.yaml` | `LLM_URLS` JSON array — all catalog predictors you want in the admin UI, plus LlamaStack |
   | `overrides/openwebui-cloud-catalog-values.yaml` | `OPENAI_API_BASE_URLS` — same endpoints, semicolon-separated |

5. Commit and sync so LlamaStack and the UIs pick up the URLs.

**Tip:** To list predictor services:

```bash
oc get svc -n rag-llm-sno | grep predictor
```

## Sync waves (`prod-cloud`)

| Wave | Application |
|------|-------------|
| 15 | LVMS |
| 20 | nvidia-config |
| 30 | DSC |
| 50 | LlamaStack |
| 55 | RAG LLM Demo UI |
| 56 | Open WebUI |

## References

- [Deploying a model from the model catalog](https://docs.redhat.com/en/documentation/red_hat_openshift_ai_cloud_service/1/html/working_with_the_model_catalog/deploying-a-model-from-the-model-catalog_working-model-catalog) (cloud service; UI flow is analogous on self-managed where catalog is available)
- [Deploy large models — single-model serving (KServe)](https://docs.redhat.com/en/documentation/red_hat_openshift_ai_self-managed/latest/html/deploying_models/) — storage (S3, OCI, etc.) as used by catalog deployments

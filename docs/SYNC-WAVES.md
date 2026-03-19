# Argo CD sync waves (deployment order)

This pattern uses **`argocd.argoproj.io/sync-wave`** so OpenShift GitOps applies resources in a predictable order: operators first, platform config, Data Science Cluster, model serving (staggered), LlamaStack, then UIs.

## Operator subscriptions (`values-prod.yaml`)

**No per-subscription sync-waves** — all operator Subscriptions are applied in the **same** Argo sync phase so `rhods-operator` is not blocked if another operator (e.g. cert-manager) stays Progressing for a long time.

| Subscription | Purpose |
|----------------|---------|
| OpenShift AI (`rhods-operator`) | DSC and serving APIs |
| cert-manager Operator for Red Hat OpenShift | KServe / certs |
| NFD, NVIDIA GPU (certified), LVMS | Hardware / GPU / storage |

(Service Mesh + Serverless: install via Operator Hub **before** the pattern — not GitOps-managed here.)

## Argo Applications (`values-prod.yaml`)

| Wave | Application |
|------|-------------|
| 10 | `nfd` — NodeFeatureDiscovery CR |
| 15 | `lvms` — LVMCluster |
| 20 | `nvidia-config` — ClusterPolicy |
| 30 | `dsc` — DataScienceCluster |
| 40 | Granite inference |
| 42 | Gemma 2 inference |
| 44 | GPT-OSS 20B inference |
| 46 | GPT-OSS 120B inference (last among vLLM apps to reduce simultaneous large pulls) |
| 50 | LlamaStack (+ Milvus Lite) |
| 55 | RAG LLM Demo UI |
| 56 | Open WebUI |

The RAG LLM Demo UI chart does not annotate its Deployment; ordering vs Open WebUI is handled by **Application** waves (55 then 56). Open WebUI’s main workload uses an in-chart `annotations` sync-wave so Redis/Open WebUI sub-resources order after the primary deployment where the chart applies it.

## Within each vLLM Helm chart

| Wave | Resource |
|------|----------|
| 2 | `AcceleratorProfile` (Granite only, when enabled) |
| 5 | `ServingRuntime` |
| 10 | `InferenceService` |

Serving runtimes are applied before inference services that reference them.

## LlamaStack chart

| Wave | Resource |
|------|----------|
| -2 | `Secret` (`llama-stack-inference-model-secret`) |
| 5 | `LlamaStackDistribution` |

## References

- [Validated Patterns — sequencing subscriptions & applications](https://validatedpatterns.io/blog/2024-11-07-clustergroup-sequencing)
- [Argo CD sync waves](https://argo-cd.readthedocs.io/en/stable/user-guide/sync-waves/)

## Cluster group `prod-cloud` (`values-prod-cloud.yaml`)

No NFD; no GitOps vLLM applications. Models are expected from the **OpenShift AI model catalog** (see **[CLOUD-AND-MODEL-CATALOG.md](CLOUD-AND-MODEL-CATALOG.md)**).

| Wave | Application |
|------|-------------|
| 15 | `lvms` |
| 20 | `nvidia-config` |
| 30 | `dsc` |
| 50 | `llamastack` |
| 55 | RAG LLM Demo UI |
| 56 | Open WebUI |

If an operator stays **Progressing**, later waves wait. For stricter gates (e.g. wait for a `StorageClass`), consider a `sequenceJob` or `extraObjects` wait Job on the subscription as described in the Validated Patterns blog.

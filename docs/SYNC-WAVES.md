# Argo CD sync waves (deployment order)

This pattern uses **`argocd.argoproj.io/sync-wave`** so OpenShift GitOps applies resources in a predictable order: operators first, platform config, Data Science Cluster, model serving (staggered), LlamaStack, then UIs.

## Operator subscriptions (`values-prod.yaml`)

| Wave | Subscription | Purpose |
|------|----------------|---------|
| -45 | cert-manager Operator for Red Hat OpenShift | KServe / cert prerequisites |
| -42 | Service Mesh, Serverless | Knative serving stack |
| -38 | Node Feature Discovery | GPU / hardware labels |
| -36 | NVIDIA GPU Operator (certified) | GPU drivers / runtime |
| -34 | LVMS | Local storage |
| -30 | OpenShift AI (`rhods-operator`) | DSC and serving APIs |

Lower waves must become **healthy** before the next wave syncs (Argo CD behavior).

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

If an operator stays **Progressing**, later waves wait. For stricter gates (e.g. wait for a `StorageClass`), consider a `sequenceJob` or `extraObjects` wait Job on the subscription as described in the Validated Patterns blog.

# Model and application endpoints

After deploying this pattern on OpenShift AI 3.x, you can use the following endpoints to call the deployed models and both frontends. **Administrators** and **users** both use the **inline Milvus Lite** vector database via the Llama Stack API.

## Prerequisites

- OpenShift AI 3.x is installed and the DataScienceCluster has KServe (and optionally Llama Stack) in the desired state.
- InferenceServices are deployed and their pods are running in the `rag-llm-sno` namespace.

## Model inference endpoints

Up to four LLM inference services are deployed. **GPT-OSS 20B** is the default when &lt; 80GB VRAM (schedules on any NVIDIA GPU). **GPT-OSS 120B** only schedules on nodes with **≥ 80GB VRAM** (e.g. H100 80GB, H200 141GB; `nvidia.com/gpu.product`).

| Model | Internal service (from within the cluster) | Purpose |
|-------|-------------------------------------------|---------|
| **IBM Granite 4 Small** | `http://granite-inference-service-vllm-inference-service-predictor.rag-llm-sno.svc.cluster.local/v1` | OpenAI-compatible API for Granite |
| **GPT-OSS 20B** (default when &lt; 80GB VRAM) | `http://gpt-oss-20b-inference-service-vllm-inference-service-predictor.rag-llm-sno.svc.cluster.local/v1` | OpenAI-compatible API; runs on any node with an NVIDIA GPU |
| **GPT-OSS 120B** (optional, ≥ 80GB VRAM) | `http://gpt-oss-inference-service-vllm-inference-service-predictor.rag-llm-sno.svc.cluster.local/v1` | OpenAI-compatible API; available only when a node has ≥ 80GB VRAM (e.g. H100 80GB, H200 141GB) |
| **Google Gemma 2** | `http://gemma2-inference-service-vllm-inference-service-predictor.rag-llm-sno.svc.cluster.local/v1` | OpenAI-compatible API for Gemma 2 |

### Getting the external (Route) URLs

For access from outside the cluster (e.g., from your laptop or another service), use the OpenShift Routes created for each InferenceService.

1. List inference-related routes in the application namespace:
   ```bash
   oc get route -n rag-llm-sno -l serving.kserve.io/inferenceservice
   ```

2. Or get the URL from the InferenceService status (if the controller sets it):
   ```bash
   oc get inferenceservice -n rag-llm-sno -o wide
   oc get inferenceservice granite-inference-service-vllm-inference-service -n rag-llm-sno -o jsonpath='{.status.url}'
   oc get inferenceservice gpt-oss-20b-inference-service-vllm-inference-service -n rag-llm-sno -o jsonpath='{.status.url}'
   oc get inferenceservice gpt-oss-inference-service-vllm-inference-service -n rag-llm-sno -o jsonpath='{.status.url}'
   oc get inferenceservice gemma2-inference-service-vllm-inference-service -n rag-llm-sno -o jsonpath='{.status.url}'
   ```

3. Use the Route host with `https://` (OpenShift uses TLS for routes):
   ```bash
   oc get route -n rag-llm-sno
   ```
   Then call the model with the route host, for example:
   - `https://<granite-route-host>/v1/chat/completions`
   - `https://<gpt-oss-20b-route-host>/v1/chat/completions`
   - `https://<gpt-oss-120b-route-host>/v1/chat/completions` (if ≥ 80GB VRAM)
   - `https://<gemma2-route-host>/v1/chat/completions`

### OpenAI-compatible API

All models are served with an OpenAI-compatible REST API (vLLM). Example:

```bash
curl -k -X POST "https://<route-host>/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -d '{"model":"","messages":[{"role":"user","content":"Hello"}],"max_tokens":100}'
```

## RAG LLM Demo UI (administrators)

The **RAG LLM Demo UI** is the administrator interface. It uses the **inline Milvus Lite** vector database via LlamaStack for RAG, plus direct access to the three vLLM services.

- **Internal:** Use the service `rag-llm-frontend` in namespace `rag-llm-sno`.
- **External:** From the OpenShift console, **Networking → Routes**, select namespace `rag-llm-sno`, and open the route for **rag-llm-frontend**. Or from the CLI: `oc get route -n rag-llm-sno` and use the host for the RAG LLM Demo UI.
- The UI is preconfigured with `LLM_URLS` including Granite, GPT-OSS, Gemma 2, and **LlamaStack** (`http://llamastack-llamastack:8321/v1`). Select LlamaStack for RAG over inline Milvus Lite.

## Open WebUI frontend (users)

The **Open WebUI** frontend is the user-facing chat and RAG interface. It uses the same **inline Milvus Lite** vector database via LlamaStack, plus the three vLLM inference services.

1. From the OpenShift console: **Networking → Routes** (or **Ingress**), select namespace `rag-llm-sno`, and open the route/host for the Open WebUI deployment (e.g. `openwebui` or similar).

2. Or from the CLI:
   ```bash
   oc get route -n rag-llm-sno
   oc get svc -n rag-llm-sno
   ```
   Use the Open WebUI service host/port for the frontend. If no Route exists, create one for the Open WebUI service or use port-forward:
   ```bash
   oc port-forward svc/openwebui 8080:80 -n rag-llm-sno
   ```
   Then open `http://localhost:8080`.

Open WebUI is preconfigured with the same inference URLs plus **LlamaStack** (`http://llamastack-llamastack:8321/v1`). Users can choose LlamaStack for RAG over inline Milvus Lite.

## LlamaStack and inline Milvus Lite (shared vector database)

The pattern deploys a **LlamaStackDistribution** with **inline Milvus Lite** as the **single vector database for both administrators and users**.

- **LlamaStack service** – In the `rag-llm-sno` namespace, the Llama Stack server runs in the pod created by the LlamaStackDistribution. The Kubernetes Service has the same name as the LlamaStackDistribution resource (e.g. `llamastack-llamastack`). The server listens on port **8321** and is backed by inline Milvus Lite.
- **Both frontends** – The RAG LLM Demo UI and Open WebUI are configured with `http://llamastack-llamastack:8321/v1` so that admins and users both use this vector store for RAG when they select the LlamaStack endpoint.
- **Ingesting content** – Ingest documents (including **PDFs**) from a Jupyter workbench using the `llama_stack_client` SDK or via a Docling pipeline. See **[docs/RAG-PDF-INGESTION.md](RAG-PDF-INGESTION.md)** for step-by-step PDF ingestion, and the [OpenShift AI Llama Stack docs](https://docs.redhat.com/en/documentation/red_hat_openshift_ai_self-managed/3.0/html/working_with_llama_stack/deploying-a-rag-stack-in-a-project_rag#ingesting-content-into-a-llama-model_rag) for the full SDK reference.

## Summary

- **Models:** Use the InferenceService predictor services internally, or the KServe/OpenShift routes for external access. Granite 4 Small, **GPT-OSS 20B** (default when &lt; 80GB VRAM), **GPT-OSS 120B** (when ≥ 80GB VRAM), and Gemma 2 expose `/v1` and `/v1/chat/completions`.
- **RAG LLM Demo UI (admins):** Use the Route for `rag-llm-frontend` in `rag-llm-sno`; it uses **inline Milvus Lite** via LlamaStack for RAG and can use all deployed LLMs or LlamaStack.
- **Open WebUI (users):** Use the Route or port-forward for `openwebui` in `rag-llm-sno`; it uses the same **inline Milvus Lite** via LlamaStack for RAG and the deployed LLMs (including OSS-20B by default).
- **Vector database:** A single **inline Milvus Lite** instance in LlamaStack serves both UIs; ingest via Jupyter/`llama_stack_client` or Docling and use the Llama Stack API (`http://llamastack-llamastack:8321/v1`) for RAG.

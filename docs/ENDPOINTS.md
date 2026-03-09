# Model and application endpoints

After deploying this pattern on OpenShift AI 3.x, you can use the following endpoints to call the deployed models and both frontends. **Administrators** and **users** both use the **inline Milvus Lite** vector database via the Llama Stack API.

## Prerequisites

- OpenShift AI 3.x is installed and the DataScienceCluster has KServe (and optionally Llama Stack) in the desired state.
- InferenceServices are deployed and their pods are running in the `rag-llm-sno` namespace.

## Model inference endpoints

Up to three LLM inference services are deployed. **GPT-OSS 120B is optional:** it only schedules on nodes with an H100 or higher GPU (`nvidia.com/gpu.product`). On clusters without such GPUs, the GPT-OSS predictor stays Pending and is not available.

| Model | Internal service (from within the cluster) | Purpose |
|-------|-------------------------------------------|---------|
| **IBM Granite 4 Small** | `http://granite-inference-service-vllm-inference-service-predictor.rag-llm-sno.svc.cluster.local/v1` | OpenAI-compatible API for Granite |
| **GPT-OSS 120B** (optional, H100+ only) | `http://gpt-oss-inference-service-vllm-inference-service-predictor.rag-llm-sno.svc.cluster.local/v1` | OpenAI-compatible API for GPT-OSS; available only when a node has H100 or higher |
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
   oc get inferenceservice gpt-oss-inference-service-vllm-inference-service -n rag-llm-sno -o jsonpath='{.status.url}'
   oc get inferenceservice gemma2-inference-service-vllm-inference-service -n rag-llm-sno -o jsonpath='{.status.url}'
   ```

3. Use the Route host with `https://` (OpenShift uses TLS for routes):
   ```bash
   oc get route -n rag-llm-sno
   ```
   Then call the model with the route host, for example:
   - `https://<granite-route-host>/v1/chat/completions`
   - `https://<gpt-oss-route-host>/v1/chat/completions`
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
- **Ingesting content** – Ingest documents into the vector store from a Jupyter workbench using the `llama_stack_client` SDK or via Docling in an AI pipeline. See [Deploying a RAG stack in a project](https://docs.redhat.com/en/documentation/red_hat_openshift_ai_self-managed/3.0/html/working_with_llama_stack/deploying-a-rag-stack-in-a-project_rag) and [Ingesting content into a Llama model](https://docs.redhat.com/en/documentation/red_hat_openshift_ai_self-managed/3.0/html/working_with_llama_stack/deploying-a-rag-stack-in-a-project_rag#ingesting-content-into-a-llama-model_rag).

## Summary

- **Models:** Use the InferenceService predictor services internally, or the KServe/OpenShift routes for external access. All three models (Granite 4 Small, GPT-OSS 120B, Gemma 2) expose `/v1` and `/v1/chat/completions`.
- **RAG LLM Demo UI (admins):** Use the Route for `rag-llm-frontend` in `rag-llm-sno`; it uses **inline Milvus Lite** via LlamaStack for RAG and can use all three LLMs or LlamaStack.
- **Open WebUI (users):** Use the Route or port-forward for `openwebui` in `rag-llm-sno`; it uses the same **inline Milvus Lite** via LlamaStack for RAG and the three LLMs.
- **Vector database:** A single **inline Milvus Lite** instance in LlamaStack serves both UIs; ingest via Jupyter/`llama_stack_client` or Docling and use the Llama Stack API (`http://llamastack-llamastack:8321/v1`) for RAG.

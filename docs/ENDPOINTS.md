# Model and application endpoints

After deploying this pattern on OpenShift AI 3.x, you can use the following endpoints to call the deployed models and the RAG frontend.

## Prerequisites

- OpenShift AI 3.x is installed and the DataScienceCluster has KServe in `Ready` state.
- InferenceServices are deployed and their pods are running in the `rag-llm-sno` namespace.

## Model inference endpoints

Two LLM inference services are deployed:

| Model | Internal service (from within the cluster) | Purpose |
|-------|-------------------------------------------|---------|
| **IBM Granite 4 Small** | `http://granite-inference-service-vllm-inference-service-predictor.rag-llm-sno.svc.cluster.local/v1` | OpenAI-compatible API for Granite |
| **GPT-OSS 120B** | `http://gpt-oss-inference-service-vllm-inference-service-predictor.rag-llm-sno.svc.cluster.local/v1` | OpenAI-compatible API for GPT-OSS |

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
   ```

3. Use the Route host with `https://` (OpenShift uses TLS for routes):
   ```bash
   oc get route -n rag-llm-sno
   ```
   Then call the model with the route host, for example:
   - `https://<granite-route-host>/v1/chat/completions`
   - `https://<gpt-oss-route-host>/v1/chat/completions`

### OpenAI-compatible API

Both models are served with an OpenAI-compatible REST API (vLLM). Example:

```bash
curl -k -X POST "https://<route-host>/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -d '{"model":"","messages":[{"role":"user","content":"Hello"}],"max_tokens":100}'
```

## RAG frontend

The RAG LLM Demo UI is exposed via an OpenShift Route in the `rag-llm-sno` namespace.

1. From the OpenShift console: **Networking → Routes**, select namespace `rag-llm-sno`, and open the route for the RAG frontend (e.g. `rag-llm-frontend` or similar).

2. Or from the CLI:
   ```bash
   oc get route -n rag-llm-sno
   ```
   Use the `HOST/PORT` column for the frontend route.

The frontend is preconfigured with the internal model URLs so that it can call both LLMs and the Qdrant vector database from inside the cluster.

## Vector database (Qdrant)

- **Internal URL (used by the frontend):** `http://qdrant-service:6333` in namespace `rag-llm-sno`.
- For external access, create or use a route for the Qdrant service and use that host with port 6333 (or the route’s TLS port).

## Summary

- **Models:** Use the InferenceService predictor services internally, or the KServe/OpenShift routes for external access. Both models expose `/v1` (and `/v1/chat/completions`).
- **RAG UI:** Use the Route in `rag-llm-sno` for the frontend.
- **Qdrant:** Use `http://qdrant-service:6333` inside the cluster, or an optional route for external access.

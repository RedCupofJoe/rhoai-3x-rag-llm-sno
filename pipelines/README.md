# Docling RAG ingestion pipeline (OpenShift AI 3.x)

This pipeline is **compliant with OpenShift AI 3.x** Data Science Pipelines. It uses **Kubeflow Pipelines 2.0 (KFP)** and is intended to run on the pipeline server in your OpenShift AI project.

## OpenShift AI 3.x compatibility

- **Runtime:** OpenShift AI 3.x Data Science Pipelines (Kubeflow Pipelines 2.0).
- **DSC requirement:** The Data Science Cluster must have **AI Pipelines** enabled. In this pattern, the DSC is configured with `aipipelines: managementState: Managed` so that the pipeline server and runs are available. If you set `aipipelines` to `Removed`, pipeline runs will not be available (other pattern features still work).
- **Pipeline definition:** Built with the `kfp` SDK; compile to YAML and upload via the OpenShift AI dashboard or CLI.

## What the pipeline does

1. **Clone this repo** (or use a workspace that already contains `rag-docs/`).
2. **Process `rag-docs/`** – Convert PDFs to text with Docling; include `.md` and `.txt` as-is. **Letterhead, headers, and footers are excluded** from chunking: the script exports only body content (`ContentLayer.BODY`), so Docling’s furniture layer (headers/footers) is omitted. Requires Docling/docling_core versions that support `included_content_layers`.
3. **Ingest into Llama Stack** – Send chunks to the Llama Stack vector store (inline Milvus Lite) used by the RAG UIs.

## Prerequisites

- OpenShift AI 3.x with **Data Science Pipelines** enabled (aipipelines component Managed).
- A **pipeline server** configured in your project (object storage for artifacts).
- **Llama Stack** running (this pattern deploys it in `rag-llm-sno`).
- Network from the pipeline run to the Llama Stack service (e.g. `http://llamastack-llamastack.rag-llm-sno.svc.cluster.local:8321` if running in a project that can reach `rag-llm-sno`).

## Pipeline parameters

| Parameter | Description |
|-----------|-------------|
| `repo_url` | Git URL of this repo (or the repo that contains `rag-docs/`). |
| `branch` | Branch to clone (e.g. `main`). |
| `llama_stack_url` | Base URL of the Llama Stack API (e.g. `http://llamastack-llamastack.rag-llm-sno.svc.cluster.local:8321` from within the cluster). |
| `vector_store_id` | (Optional) Existing vector store ID. If empty, the pipeline creates one (inline Milvus Lite). |
| `rag_docs_path` | Path relative to repo root for documents (default `rag-docs`). |

## How to use

1. **Add documents** to `rag-docs/` in this repo and push.
2. **Enable AI Pipelines** in the DSC (this pattern sets `aipipelines: Managed`).
3. **Create a pipeline server** in your OpenShift AI project (see [OpenShift AI Pipelines docs](https://docs.redhat.com/en/documentation/red_hat_openshift_ai_self-managed/3.3/html/working_with_ai_pipelines/working_with_ai_pipelines)).
4. **Compile and upload** the pipeline:
   - From a workbench or laptop: `pip install kfp`, then run the compile step (see `docling_rag_pipeline.py`).
   - Upload the generated YAML to your project’s pipeline server via the OpenShift AI dashboard.
5. **Run the pipeline** with the parameters above (repo_url, branch, llama_stack_url, etc.).

## Files

- **`docling_rag_pipeline.py`** – KFP v2 pipeline definition (Python). Compile to YAML and upload to OpenShift AI.
- **`requirements.txt`** – Python deps for compiling the pipeline (`kfp`) and for the pipeline’s container image (e.g. `docling`, `llama_stack_client`) if you use a custom image.

For step-by-step PDF ingestion (including without pipelines), see **[../docs/RAG-PDF-INGESTION.md](../docs/RAG-PDF-INGESTION.md)**.

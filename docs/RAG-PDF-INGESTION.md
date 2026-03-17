# Adding PDF files to the RAG database

This pattern uses **Llama Stack** with **inline Milvus Lite** as the RAG vector store. PDFs are not stored in this repo; you ingest them at runtime using one of the methods below.

## Prerequisites

- The pattern is deployed and **LlamaStack** is running in the `rag-llm-sno` namespace.
- You have the **Llama Stack API URL**:
  - From inside the cluster: `http://llamastack-llamastack:8321`
  - From your laptop: create an OpenShift Route for the LlamaStack service, or use `oc port-forward svc/llamastack-llamastack 8321:8321 -n rag-llm-sno` and use `http://localhost:8321`

---

## Option 1: Jupyter workbench (PDF → text → vector store)

Use an **OpenShift AI Jupyter workbench** in a project that can reach the Llama Stack service. Extract text from PDFs in Python, then ingest via the Llama Stack SDK.

### 1. Install the client and a PDF library

In a notebook cell:

```python
%pip install llama_stack_client pypdf
```

### 2. Connect to Llama Stack and create a vector store

```python
from llama_stack_client import LlamaStackClient

# Use the Llama Stack URL (from inside the cluster or via port-forward)
base_url = "http://llamastack-llamastack:8321"  # or https://<route-host> if using a route
client = LlamaStackClient(base_url=base_url)

# List models and pick embedding model
models = client.models.list()
embedding_model = next(m for m in models if m.model_type == "embedding")
embedding_model_id = embedding_model.identifier
embedding_dimension = int(embedding_model.metadata.get("embedding_dimension", 768))

# Create inline Milvus Lite vector store (matches this pattern)
vector_store = client.vector_stores.create(
    name="my_pdf_store",
    extra_body={
        "embedding_model": embedding_model_id,
        "embedding_dimension": embedding_dimension,
        "provider_id": "milvus",  # inline Milvus Lite
    },
)
vector_store_id = vector_store.id
print(f"Vector store ID: {vector_store_id}")
```

### 3. Extract text from PDFs and ingest

```python
from pypdf import PdfReader

def pdf_to_text(path: str) -> str:
    reader = PdfReader(path)
    return "\n".join(page.extract_text() or "" for page in reader.pages)

# Example: one or more PDF paths (e.g. uploaded to the workbench or from object storage)
pdf_paths = ["/path/to/doc1.pdf", "/path/to/doc2.pdf"]

items = []
for i, path in enumerate(pdf_paths):
    text = pdf_to_text(path)
    items.append({
        "id": f"pdf_{i}",
        "text": text,
        "mime_type": "text/plain",
        "metadata": {"source": path},
    })

result = client.vector_stores.files.create(
    vector_store_id=vector_store_id,
    items=items,
    chunk_size_in_tokens=256,
)
print("Ingestion result:", result)
```

After this, use the same `vector_store_id` when querying via the RAG LLM Demo UI or Open WebUI (select the LlamaStack endpoint and the store, if the UI supports it), or query programmatically with `client.responses.create()` and `vector_store_ids=[vector_store_id]`.

---

## Option 2: Docling pipeline (OpenShift AI 3.x)

For larger or recurring PDF ingestion, use the **in-repo Docling pipeline** (OpenShift AI 3.x KFP) that converts PDFs in **rag-docs/** to text and pushes embeddings into Llama Stack’s vector store.

1. **Enable and use OpenShift AI Pipelines** in your project (and a pipeline server).
2. **Use or adapt a Docling pipeline** that:
   - Takes PDFs (e.g. from object storage or a list of URLs),
   - Converts them to Markdown with [Docling](https://github.com/DS4SD/docling),
   - Registers or uses a Llama Stack vector store and ingests the Markdown.

Red Hat documents this in [Preparing documents with Docling for Llama Stack retrieval](https://docs.redhat.com/en/documentation/red_hat_openshift_ai_self-managed/3.0/html/working_with_llama_stack/deploying-a-rag-stack-in-a-project_rag#preparing-documents-with-docling-for-llama-stack-retrieval_rag). The [RAG demo samples](https://github.com/opendatahub-io/rag/tree/main/demos/kfp/docling/pdf-conversion) include a PDF conversion pipeline; you can run it and pass:

- **Llama Stack URL** – your deployment (e.g. `http://llamastack-llamastack:8321` from inside the cluster).
- **Vector store ID** – create one in Jupyter as in Option 1 and pass the ID, or let the pipeline create it.
- **PDF source** – e.g. `pdf_filenames` and `base_url` (or your pipeline’s equivalent parameters).

3. After the pipeline run, the PDF content is in the vector store and can be queried via the LlamaStack endpoint in the RAG UIs or via the SDK.

For this repo’s pipeline (compile, upload, parameters), see **pipelines/README.md**; it is compliant with OpenShift AI 3.x Data Science Pipelines (KFP 2.0).

---

## Summary

| Method              | Best for                    | Where it runs        |
|---------------------|-----------------------------|----------------------|
| **Jupyter + pypdf** | Few PDFs, ad‑hoc ingestion  | OpenShift AI workbench |
| **Docling pipeline**| Many PDFs, repeatable runs  | OpenShift AI Pipelines |

The **vector store** is the **inline Milvus Lite** instance inside Llama Stack deployed by this pattern. Both the RAG LLM Demo UI and Open WebUI use it when you select the LlamaStack endpoint; ingestion is separate and done via Jupyter or a pipeline as above.

For full SDK details (vector store creation, chunking, querying), see the [OpenShift AI Llama Stack documentation](https://docs.redhat.com/en/documentation/red_hat_openshift_ai_self-managed/3.0/html/working_with_llama_stack/deploying-a-rag-stack-in-a-project_rag).

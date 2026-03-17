# RAG source documents

Place **PDFs and other documents** here that you want to add to the RAG vector database (Llama Stack + inline Milvus Lite).

## Supported formats

- **PDF** (`.pdf`) – processed with [Docling](https://github.com/DS4SD/docling) in the pipeline
- **Markdown** (`.md`) and **plain text** (`.txt`) – ingested directly

## How ingestion works

1. **Add files** – Put your PDFs and/or `.md`/`.txt` files in this folder and commit/push (or sync to the cluster).
2. **Run the Docling pipeline** – The pipeline in `pipelines/` clones this repo (or uses a workspace that includes `rag-docs/`), converts PDFs to text with Docling, and ingests everything into the Llama Stack vector store.
3. **Query** – Use the RAG LLM Demo UI or Open WebUI with the LlamaStack endpoint to query the ingested content.

See **[../docs/RAG-PDF-INGESTION.md](../docs/RAG-PDF-INGESTION.md)** and **[../pipelines/README.md](../pipelines/README.md)** for pipeline parameters and run instructions.

## Notes

- Do not commit large binary files if your repo has size limits; use Git LFS or sync from object storage and point the pipeline at that path instead.
- This directory is intentionally empty except for this README; add your documents as needed.

#!/usr/bin/env python3
"""
Run Docling on PDFs in rag-docs/ and ingest into Llama Stack vector store.
Used by the OpenShift AI 3.x Docling RAG pipeline (KFP).
"""
import argparse
import os
import sys
from pathlib import Path


def main() -> int:
    parser = argparse.ArgumentParser(description="Ingest rag-docs into Llama Stack")
    parser.add_argument("--repo-path", required=True, help="Path to cloned repo (contains rag-docs/)")
    parser.add_argument("--llama-stack-url", required=True, help="Llama Stack API base URL")
    parser.add_argument("--vector-store-id", default="", help="Existing vector store ID (optional)")
    parser.add_argument("--rag-docs-path", default="rag-docs", help="Subdir under repo-path for documents")
    parser.add_argument("--chunk-tokens", type=int, default=256, help="Chunk size in tokens for ingestion")
    args = parser.parse_args()

    repo_path = Path(args.repo_path)
    rag_docs = repo_path / args.rag_docs_path
    if not rag_docs.is_dir():
        print(f"RAG docs path not found: {rag_docs}", file=sys.stderr)
        return 1

    # Defer heavy imports until we know paths are valid
    try:
        import docling.document_converter
    except ImportError:
        print("Installing docling...", file=sys.stderr)
        os.system(f"{sys.executable} -m pip install -q docling")
        import docling.document_converter

    try:
        from llama_stack_client import LlamaStackClient
    except ImportError:
        print("Installing llama_stack_client...", file=sys.stderr)
        os.system(f"{sys.executable} -m pip install -q llama_stack_client")
        from llama_stack_client import LlamaStackClient

    client = LlamaStackClient(base_url=args.llama_stack_url.rstrip("/"))

    # Resolve embedding model and vector store
    models = client.models.list()
    embedding_model = next((m for m in models if m.model_type == "embedding"), None)
    if not embedding_model:
        print("No embedding model found on Llama Stack", file=sys.stderr)
        return 1
    embedding_model_id = embedding_model.identifier
    embedding_dimension = int(embedding_model.metadata.get("embedding_dimension", 768))

    vector_store_id = args.vector_store_id
    if not vector_store_id:
        vs = client.vector_stores.create(
            name="rag_docs_pipeline",
            extra_body={
                "embedding_model": embedding_model_id,
                "embedding_dimension": embedding_dimension,
                "provider_id": "milvus",
            },
        )
        vector_store_id = vs.id
        print(f"Created vector store: {vector_store_id}")

    converter = docling.document_converter.DocumentConverter()
    # Exclude letterhead/headers/footers (Docling marks them as FURNITURE); export only BODY.
    try:
        from docling_core.types.doc.document import ContentLayer
        export_options = {"included_content_layers": {ContentLayer.BODY}}
    except (ImportError, AttributeError):
        export_options = {}  # older Docling: no layer filter, export full document

    items = []
    supported = {".pdf", ".md", ".txt"}
    for fpath in sorted(rag_docs.rglob("*")):
        if not fpath.is_file():
            continue
        if fpath.suffix.lower() not in supported:
            continue
        rel = fpath.relative_to(rag_docs)
        doc_id = str(rel).replace(os.sep, "_").replace(" ", "_")
        if fpath.suffix.lower() == ".pdf":
            result = converter.convert(str(fpath))
            text = result.document.export_to_markdown(**export_options)
        else:
            text = fpath.read_text(encoding="utf-8", errors="replace")
        items.append({
            "id": doc_id,
            "text": text,
            "mime_type": "text/plain",
            "metadata": {"source": str(rel)},
        })
        print(f"Queued: {rel}")

    if not items:
        print("No documents to ingest in", rag_docs)
        return 0

    result = client.vector_stores.files.create(
        vector_store_id=vector_store_id,
        items=items,
        chunk_size_in_tokens=args.chunk_tokens,
    )
    print("Ingestion result:", result)
    return 0


if __name__ == "__main__":
    sys.exit(main())

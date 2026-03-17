"""
OpenShift AI 3.x compliant pipeline: clone repo, run Docling on rag-docs/, ingest into Llama Stack.
Uses Kubeflow Pipelines 2.0 (KFP). Compile with: python docling_rag_pipeline.py
"""
from kfp import dsl, compiler

@dsl.container_component
def docling_rag_ingest(
    repo_url: str,
    branch: str,
    llama_stack_url: str,
    vector_store_id: str,
    rag_docs_path: str,
):
    """Clone repo, convert PDFs in rag-docs with Docling, ingest into Llama Stack."""
    # Single script string; $1..$5 are filled by KFP from the following args
    script = (
        "set -eux && "
        "apt-get update -qq && apt-get install -y -qq git && "
        "git clone --depth 1 -b \"$2\" \"$1\" /workspace/repo && "
        "pip install -q docling llama_stack_client && "
        "python /workspace/repo/pipelines/scripts/run_docling_ingest.py "
        "--repo-path /workspace/repo --llama-stack-url \"$3\" "
        "--vector-store-id \"$4\" --rag-docs-path \"$5\""
    )
    return dsl.ContainerSpec(
        image="python:3.11-slim",
        command=["sh", "-c", script],
        args=[repo_url, branch, llama_stack_url, vector_store_id or "", rag_docs_path],
    )


@dsl.pipeline(
    name="docling-rag-ingest",
    description="Ingest PDFs and docs from repo rag-docs/ into Llama Stack (OpenShift AI 3.x).",
)
def docling_rag_pipeline(
    repo_url: str = "https://github.com/RedCupofJoe/rhoai-3x-rag-llm-sno",
    branch: str = "main",
    llama_stack_url: str = "http://llamastack-llamastack.rag-llm-sno.svc.cluster.local:8321",
    vector_store_id: str = "",
    rag_docs_path: str = "rag-docs",
):
    """
    Pipeline parameters are overridable at run time in OpenShift AI.
    Ensure the pipeline run has network access to llama_stack_url (e.g. same cluster, rag-llm-sno namespace).
    """
    docling_rag_ingest(
        repo_url=repo_url,
        branch=branch,
        llama_stack_url=llama_stack_url,
        vector_store_id=vector_store_id,
        rag_docs_path=rag_docs_path,
    )


if __name__ == "__main__":
    compiler.Compiler().compile(
        pipeline_func=docling_rag_pipeline,
        package_path="docling_rag_pipeline.yaml",
    )
    print("Compiled to docling_rag_pipeline.yaml. Upload this to your OpenShift AI pipeline server.")

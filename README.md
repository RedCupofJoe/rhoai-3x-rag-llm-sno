# RAG LLM Pattern on a Single-Node OpenShift Cluster

## Overview

This Validated Pattern deploys a Retrieval-Augmented Generation (RAG) Large Language Model (LLM) infrastructure on a Single Node OpenShift (SNO) cluster. It provides a GPU-accelerated environment for running LLM inference services using vLLM with both IBM Granite 4 Small and GPT-OSS 120B models.

In addition to the LLM inference services, the pattern deploys Qdrant as a vector database, pre-populated with the Validated Patterns documentation. A frontend application is also included, allowing users to select an LLM, configure retrieval settings, and query the complete RAG pipeline.

```mermaid
flowchart LR
    User[User Query] --> Frontend
    Frontend --> Qdrant[(Vector DB)]
    Qdrant --> |Relevant Docs| Frontend
    Frontend --> LLM[LLM Service]
    LLM --> |Response| Frontend
    Frontend --> User
```

## Applications & Components

### LLM Inference Services
- [**IBM Granite 4 Small**](https://huggingface.co/ibm-granite/granite-4.0-h-small) - Served via vLLM with GPU acceleration
- [**GPT-OSS 120B**](https://huggingface.co/openai/gpt-oss-120b) - Served via vLLM with GPU acceleration

### Vector Database
- [**Qdrant**](https://github.com/qdrant/qdrant) - Vector database pre-populated with Validated Patterns documentation for retrieval

### Frontend
- [**RAG Frontend Application**](https://github.com/validatedpatterns-sandbox/rag-llm-demo-ui) - Web interface for selecting an LLM, configuring retrieval settings, and querying the RAG pipeline

### Supporting Operators
- [**Red Hat OpenShift AI (RHOAI)**](https://www.redhat.com/en/technologies/cloud-computing/openshift/openshift-ai) - AI/ML platform for model serving and management
- [**NVIDIA GPU Operator**](https://docs.nvidia.com/datacenter/cloud-native/openshift/latest/introduction.html) - Provides GPU support for the inference services
- [**Node Feature Discovery (NFD)**](https://github.com/openshift/cluster-nfd-operator) - Identifies node hardware capabilities
- [**Local Volume Management Service (LVMS)**](https://github.com/openshift/lvm-operator) - Manages local storage volumes

## Prerequisites

- [**OpenShift Cluster**](https://docs.redhat.com/en/documentation/openshift_container_platform/4.20/html/installing_on_a_single_node/install-sno-installing-sno) - Single Node OpenShift (SNO) deployment
- [**GPU Hardware**](https://www.nvidia.com/en-us/products/workstations/professional-desktop-gpus/rtx-pro-6000/) - NVIDIA GPU-enabled node with sufficient VRAM for LLM inference (at least 80GB to run the GPT-OSS 120B model)

This pattern was developed and tested on a [Lenovo ThinkSystem SR650a V4](https://lenovopress.lenovo.com/datasheet/ds0195-lenovo-thinksystem-sr650a-v4) with 2 NVIDIA RTX Pro 6000 GPUs. If your hardware does not meet these requirements, you will need to modify this pattern accordingly.

## Installation

### Standard Installation

1. Clone this repository:
   ```bash
   git clone https://github.com/validatedpatterns-sandbox/rag-llm-sno.git
   cd rag-llm-sno
   ```

2. Log into your OpenShift cluster:
   ```bash
   export KUBECONFIG=/path/to/your/kubeconfig
   ```
   Or:
   ```bash
   oc login --token=<your-token> --server=<your-cluster-api>
   ```

3. Install the pattern:
   ```bash
   ./pattern.sh make install
   ```

### Custom Installation

If your hardware differs from the tested configuration or you need to modify the pattern:

1. Fork this repository and clone your fork:
   ```bash
   git clone https://github.com/<your-username>/rag-llm-sno.git
   cd rag-llm-sno
   ```

2. Create a branch for your changes:
   ```bash
   git checkout -b my-customizations
   ```

3. Make your modifications (e.g., adjust model configurations, resource limits)

4. Commit and push your changes:
   ```bash
   git add .
   git commit -m "Customize pattern for my environment"
   git push -u origin my-customizations
   ```

5. Log into your OpenShift cluster:
   ```bash
   export KUBECONFIG=/path/to/your/kubeconfig
   ```
   Or:
   ```bash
   oc login --token=<your-token> --server=<your-cluster-api>
   ```

6. Install the pattern:
   ```bash
   ./pattern.sh make install
   ```

## Usage

After installation, access the pattern components from the OpenShift console's application menu (bento box):

![OpenShift Application Menu](images/bento.png)

From here you can:
- **Cluster Argo CD / Prod ArgoCD** - View the GitOps installation and sync status of the pattern
- **RAG LLM Demo UI** - Launch the frontend application
- **Red Hat OpenShift AI** - Access the RHOAI dashboard

### Using the Frontend

The RAG LLM Demo UI provides an interface to query the RAG pipeline:

![RAG Frontend](images/frontend.png)

1. **Select an LLM** - Choose between the available models (IBM Granite 4 Small or GPT-OSS 120B)
2. **Configure Retrieval Settings** - Adjust search type (similarity, similarity_score_threshold, or mmr) and parameters like number of documents to retrieve
3. **Submit your query** - Enter a question and view the response along with retrieved documents

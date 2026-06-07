# Setup — Optional Cluster Provisioning for the Closing Demo

This directory contains scripts for provisioning an RHOAI cluster to record the **pre-recorded Kubernetes demo** shown in the closing segment of the workshop.

> **Participants do not need these scripts.** The hands-on lab sections (01–04) run entirely on the laptop. These scripts are for facilitators who want to demonstrate the production-scale pattern on a live cluster.

---

## When to Use

Run `platform-setup.sh` **at least 24 hours before recording the demo** to allow time for:
- EvalHub operator to index the built-in benchmark catalog
- Model serving pods to pull images and become ready
- Storage provisioning for EvalHub result persistence

Run `verify-environment.sh` to confirm the cluster is healthy before recording.

---

## What `platform-setup.sh` Provisions

| Step | What it does |
|------|-------------|
| 1 | Verify prerequisites (`oc` CLI, cluster-admin access, EvalHub CRD) |
| 2 | Enable `permitOnline: allow` in DSC (HuggingFace dataset downloads) |
| 3 | Create `workshop-eval` namespace with required labels |
| 4 | Create `workshop-sa` service account + `evalhub-evaluator` RBAC |
| 5 | Deploy platform EvalHub CR in `redhat-ods-applications` (BFF discovery) |
| 6 | Deploy tenant EvalHub CR in `workshop-eval` |
| 7 | Configure BFF discovery RBAC in `redhat-ods-applications` |
| 8 | Create `openrouter-credentials` secret (or Ollama/vLLM endpoint) |
| 9 | Write `.workshop-env` with live cluster endpoints |

## What `verify-environment.sh` Checks

- `oc` CLI installed and cluster reachable
- `workshop-eval` namespace exists
- EvalHub CR `READY: True` and pods running
- EvalHub API endpoint responds with HTTP 200
- Model serving endpoint responds
- Built-in collections available

---

## Prerequisites

- OpenShift 4.14+ cluster with **RHOAI 3.4+** and TrustyAI component (`Managed`)
- Cluster admin credentials (`oc login` successful)
- Python 3.12+, `uv`, `curl`, `jq`

Model inference: set `OPENROUTER_API_KEY` before running, or configure Ollama/vLLM as the model endpoint in the generated `.workshop-env`.

---

## Files

| File | Purpose |
|------|---------|
| `README.md` | This file |
| `prerequisites.md` | Full participant prerequisites (no cluster required) |
| `platform-setup.sh` | Cluster provisioning for the demo |
| `verify-environment.sh` | Pre-demo health check |

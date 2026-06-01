# Setup — Pre-Workshop Environment Provisioning

This directory contains scripts for provisioning the complete workshop environment. These scripts are run by workshop **organizers and facilitators** — not by participants.

---

## When to Run

Run `platform-setup.sh` at least **24 hours before the workshop** to allow time for:

- Model serving pods to pull images and become ready (can take 15-30 minutes for a multi-GB model).
- EvalHub operator to index the built-in benchmark catalog.
- Storage provisioning for EvalHub result persistence.

Run `verify-environment.sh` **30 minutes before the workshop** to confirm everything is healthy after the overnight period.

---

## What These Scripts Provision

### `platform-setup.sh`

1. Creates the `workshop-eval` namespace with appropriate RBAC for participants.
2. Applies the EvalHub custom resource (CR) to deploy the evaluation platform.
3. Deploys a `granite-3-2b` model serving endpoint using vLLM on OpenShift AI.
4. Waits for all pods to reach `Running` or `Ready` state.
5. Writes `~/.workshop-env` with `EVALHUB_ENDPOINT`, `MODEL_ENDPOINT`, `KFP_ENDPOINT`, and `EVALHUB_TOKEN`.
6. Runs a smoke test against each endpoint.

### `verify-environment.sh`

Checks the following and reports pass/fail for each:

- `oc` CLI installed and cluster reachable.
- `workshop-eval` namespace exists.
- EvalHub CR `READY: True`.
- Model endpoint `/v1/health` returns HTTP 200.
- KubeFlow Pipelines API reachable.
- Required Python packages installable from pip.
- `~/.workshop-env` file exists and is populated.

---

## Prerequisites for Running Setup Scripts

See `prerequisites.md` for the full list. In summary:

- A running OpenShift 4.14+ cluster with RHOAI 2.10+ installed.
- Cluster admin credentials (`oc login` successful).
- Docker or Podman available (for model serving image pull verification).
- Python 3.10+ with pip.
- At least 40 GB of GPU memory available in the cluster for model serving (one A10G or equivalent).

---

## Files in This Directory

| File | Purpose |
|------|---------|
| `README.md` | This file |
| `prerequisites.md` | Full list of required tools and access |
| `platform-setup.sh` | Full cluster provisioning script |
| `verify-environment.sh` | Environment health check script |

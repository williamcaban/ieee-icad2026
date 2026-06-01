# Prerequisites

This document lists everything required to run the workshop environment. Verify all items before running `platform-setup.sh`.

---

## Cluster Requirements

| Requirement | Minimum | Notes |
|-------------|---------|-------|
| OpenShift version | 4.14 | Check with `oc version` |
| Red Hat OpenShift AI | 2.10 | RHOAI operator from OperatorHub |
| EvalHub operator | 0.4.0+ | Available in RHOAI add-ons catalog |
| KubeFlow Pipelines | 2.0+ | Enable via `DataScienceCluster` CR |
| GPU memory (total) | 24 GB | For granite-3-2b (4-bit quantized); 48 GB for full precision |
| Storage (PVC) | 100 GB | For EvalHub result storage and model cache |
| Cluster admin access | Required | For namespace creation and RBAC setup |

---

## Required CLI Tools

Install these on the **facilitator machine** (the machine running `platform-setup.sh`):

### kubectl and oc

```bash
# oc includes kubectl functionality
# Download from: https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/

# Verify
kubectl version --client
oc version --client
```

Required version: kubectl 1.29+ / oc 4.14+

### Python 3.10+

```bash
python3 --version
# Expected: Python 3.10.x or later

# pip must be available
pip3 --version
```

### Python Packages (installed by setup.sh)

The following packages are installed automatically by the section setup scripts. They are listed here for pre-staging on local PyPI mirrors:

```
evalhub>=0.4.0
garak>=0.9.0
kfp>=2.7.0
krippendorff>=0.6.0
scikit-learn>=1.4.0
pyyaml>=6.0
requests>=2.31.0
```

### envsubst (for YAML variable substitution)

```bash
# On macOS (via Homebrew)
brew install gettext
export PATH="/opt/homebrew/opt/gettext/bin:$PATH"

# On RHEL/Fedora
sudo dnf install -y gettext

# Verify
envsubst --version
```

### jq (for JSON parsing in scripts)

```bash
# macOS
brew install jq

# RHEL/Fedora
sudo dnf install -y jq

# Verify
jq --version
```

### curl

```bash
curl --version
# Expected: curl 7.x or 8.x
```

---

## Access Requirements

### OpenShift Cluster Admin

The provisioner must be able to:

```bash
oc auth can-i create namespace --all-namespaces
# Expected: yes

oc auth can-i create clusterrolebinding --all-namespaces
# Expected: yes
```

### Model Registry / Image Pull

The cluster must be able to pull:

- `registry.redhat.io/rhoai/granite-3-2b-vllm:latest` (or equivalent)
- `registry.redhat.io/rhoai/evalhub-operator:latest`

Verify image pull secret is configured:

```bash
oc get secret pull-secret -n openshift-config -o jsonpath='{.data.\.dockerconfigjson}' | base64 -d | jq '.auths | keys[]'
# Expected: registry.redhat.io should appear in the list
```

### KubeFlow Pipelines Service Account

The workshop service account needs permission to create KFP pipeline runs:

```bash
oc auth can-i create pipelineruns.tekton.dev -n workshop-eval --as=system:serviceaccount:workshop-eval:workshop-participant
# Expected: yes
```

---

## Network Requirements

The workshop environment requires the following network paths:

| Source | Destination | Port | Purpose |
|--------|-------------|------|---------|
| Participant laptops | OpenShift API | 6443 | kubectl/oc commands |
| Participant laptops | Model serving route | 443 | Garak probes, EvalHub evaluation |
| Participant laptops | EvalHub API route | 443 | evalhub CLI commands |
| Participant laptops | KFP UI route | 443 | Pipeline upload and monitoring |
| Cluster nodes | registry.redhat.io | 443 | Image pulls |
| Cluster nodes | PyPI (pypi.org) | 443 | pip installs (or local mirror) |

---

## Pre-Workshop Verification

After installing all prerequisites, run:

```bash
# From the facilitator machine, after oc login
bash setup/verify-environment.sh
```

All checks should show `[PASS]`. If any show `[FAIL]`, resolve before the workshop.

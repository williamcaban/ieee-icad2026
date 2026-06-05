# Prerequisites

## Participant Laptop

| Requirement | Version | Install |
|------------|---------|---------|
| Python | 3.12+ | https://python.org |
| uv | latest | `brew install uv` or `pip install uv` |
| oc CLI | 4.14+ | https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/ |
| OpenRouter API key | free | https://openrouter.ai/keys |

After cloning the repo:
```bash
uv sync                   # installs everything (lm-eval, garak, eval-hub-sdk, kfp, ...)
source .venv/bin/activate
```

Sections 01–03 run entirely on the laptop. `oc` and cluster credentials are only needed for Section 04.

---

## Cluster (Facilitator)

Run `setup/platform-setup.sh` as cluster-admin at least 24 hours before the event:

```bash
export OPENROUTER_API_KEY="sk-or-v1-..."   # set before running
bash setup/platform-setup.sh
```

### What the script provisions

| Resource | Namespace | Purpose |
|---------|-----------|---------|
| `EvalHub` CR `evalhub` | `redhat-ods-applications` | RHOAI Dashboard BFF discovers EvalHub URL from here — required for "Evaluations" UI tab |
| `EvalHub` CR `workshop-evalhub` | `workshop-eval` | Tenant instance that runs participant LMEvalJobs |
| Namespace labels | `workshop-eval` | `opendatahub.io/dashboard=true` (Dashboard visibility) + `evalhub.trustyai.opendatahub.io/tenant=true` (operator auto-provisions job SA/RBAC) |
| `evalhub-evaluator` Role + bindings | `workshop-eval` | EvalHub API authorization for participants (evaluations, collections, providers, experiments, lmevaljobs) |
| `evalhub-cr-reader` Role + binding | `redhat-ods-applications` | Allows participant token to list EvalHub CRs for BFF URL discovery |
| `openrouter-credentials` Secret | `workshop-eval` | `OPENROUTER_API_KEY` for LMEvalJob pods |
| DSC `permitOnline: allow` | cluster-wide | Allows LMEvalJob pods to download datasets from HuggingFace Hub |
| `DataSciencePipelinesApplication` | `workshop-eval` | KubeFlow Pipelines for Section 06 reference implementation |

### RHOAI Version

Tested on RHOAI 3.4 (TrustyAI operator, `eval-hub-ui` sidecar in `rhods-dashboard`).

### Key relationship: BFF and EvalHub location

The RHOAI Dashboard includes an `eval-hub-ui` sidecar (the BFF) that serves the Evaluations UI. It discovers the EvalHub service URL by listing `evalhubs.trustyai.opendatahub.io` CRs **in `redhat-ods-applications`** using the participant's bearer token. Therefore:

1. An `EvalHub` CR **must** exist in `redhat-ods-applications` (not just in `workshop-eval`)
2. Participants need `get/list evalhubs` in `redhat-ods-applications` (the `evalhub-cr-reader` binding)
3. Setting `EVAL_HUB_URL` on the dashboard deployment bypasses CR discovery but is overwritten by the operator on reconciliation — avoid it in production

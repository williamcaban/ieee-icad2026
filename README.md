# Guardrails Under Pressure: Hands-On LLM Safety Evaluation from Bias Detection to Red-Team Attacks

**IEEE ICAD 2026 Workshop** | 90 minutes | Red Hat OpenShift AI (RHOAI) + Laptop

---

## Overview

This workshop takes a **local-first** approach to LLM safety evaluation:

- **Sections 01–03 use a local `eval-hub-server`** — Section 01 starts `eval-hub-server` on `localhost:18080`. Sections 02–03 use the same `evalhub` CLI against it. lm-eval and garak run as local subprocesses calling OpenRouter for inference. No Kubernetes access required.
- **Section 04 moves to the cluster** — EvalHub on RHOAI orchestrates LMEvalJobs, stores results, and produces auditable governance artifacts.

---

## Agenda

| # | Section | Time | Runs On |
|---|---------|------|---------|
| — | Opening Presentation | 8 min | — |
| 01 | Environment Setup | 10 min | Laptop |
| 02 | Local Evaluation: lm-eval + Garak | 20 min | Laptop → OpenRouter |
| — | Break + Q&A | 8 min | — |
| 03 | IRR/IAA Benchmark (local) | 12 min | Laptop |
| 04 | Kubernetes: EvalHub + Custom Benchmarks + Governance | 22 min | Cluster |
| — | Closing Discussion | 10 min | — |

---

## Prerequisites

**Participants (laptop):**
- Python 3.12+, `uv` (`brew install uv`)
- OpenRouter free API key → https://openrouter.ai/keys
- `oc` CLI — only needed for Section 04
- Workshop cluster credentials (from facilitator) — only needed for Section 04

**Cluster (facilitator runs `setup/platform-setup.sh` before the event):**
- RHOAI 3.4+ with TrustyAI component (`Managed`)
- `EvalHub` CR in `redhat-ods-applications` (for RHOAI Dashboard BFF)
- `EvalHub` CR in `workshop-eval` (for participant evaluation jobs)
- Namespace labels: `opendatahub.io/dashboard=true` + `evalhub.trustyai.opendatahub.io/tenant=true`
- DSC `permitOnline: allow` (for HuggingFace dataset downloads in LMEvalJobs)
- `evalhub-evaluator` Role + bindings in `workshop-eval`
- `evalhub-cr-reader` Role in `redhat-ods-applications`
- `openrouter-credentials` Secret in `workshop-eval`

---

## Quick Start

```bash
git clone https://github.com/williamcaban/ieee-icad2026.git
cd ieee-icad2026

# Install all dependencies
uv sync

# Activate virtual environment
source .venv/bin/activate

# Configure your environment
cp .workshop-env.example .workshop-env
# Edit .workshop-env — set OPENROUTER_API_KEY

# Start Section 01
cd 01-setup && bash setup.sh
```

---

## Repository Structure

```
.
├── pyproject.toml               # uv-managed dependencies
├── uv.lock                      # locked versions
├── .workshop-env.example        # credential template
│
├── 01-setup/                    #  10 min │ Laptop only
├── 02-local-evaluation/         #  20 min │ Laptop → OpenRouter
│   ├── configs/garak-local.yaml
│   └── configs/lmeval-local.yaml
├── 03-irr-local/                #  12 min │ Laptop only
│   ├── data/annotations-sample.csv
│   └── scripts/{compute_irr,register_benchmark}.py
├── 04-kubernetes/               #  22 min │ Cluster (RHOAI + EvalHub)
│   └── configs/{eval-run,custom-safety-collection}.yaml
│
├── resources/
│   ├── owasp-llm-top10-quick-ref.md
│   ├── avid-taxonomy-quick-ref.md
│   ├── cwe-garak-mapping.md
│   ├── governance-checklist.md
│   └── kubeflow-pipeline-reference/   # A/B routing reference (not hands-on)
└── setup/                             # Facilitator: cluster provisioning
```

---

## Key Commands by Phase

### Local eval-hub-server (Sections 01–03)

```bash
# lm-eval: static safety benchmarks
lm_eval \
  --model openai-chat-completions \
  --model_args "base_url=${MODEL_ENDPOINT}/chat/completions,model=${MODEL_NAME}" \
  --tasks bbq_generate,mmlu_business_ethics_generative \
  --limit 5 --apply_chat_template --output_path results/

# Garak: adversarial probing
python3 -m garak --config configs/garak-local-live.yaml

# IRR computation
python3 scripts/compute_irr.py
python3 scripts/register_benchmark.py --dry-run
```

### Kubernetes (Section 04)

```bash
# Submit evaluation
evalhub eval run --name icad2026-cluster-eval \
  --model-url "${MODEL_ENDPOINT}/chat/completions" \
  --model-name "${MODEL_NAME}" \
  --provider lm_evaluation_harness \
  --benchmark bbq_generate --param "limit=5"

# Register IRR benchmark (actual POST, not dry-run)
python3 ../03-irr-local/scripts/register_benchmark.py \
  --report ../03-irr-local/irr_report.json

# Create custom collection
evalhub collections create --file configs/custom-safety-collection.yaml
evalhub collections run workshop-custom-safety-v1 \
  --model-url "${MODEL_ENDPOINT}/chat/completions" \
  --model-name "${MODEL_NAME}" --wait

# Kubernetes CR alternative
oc apply -f configs/eval-run-live.yaml
oc get lmevaljob -n workshop-eval -w
```

---

## Each Section Is Self-Contained

Every section has:
- `setup.sh` — idempotent configuration (no downloads after `uv sync`)
- `reset.sh` — removes section output so the section can be retried

---

## License

Apache 2.0. Red Hat, OpenShift, and OpenShift AI are trademarks of Red Hat, Inc.

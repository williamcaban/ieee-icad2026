# Guardrails Under Pressure

### Replicating Baselines · Validating Novel Benchmarks · Comparing at Scale

**IEEE ICAD 2026 Workshop** · 105 minutes · Hands-on · All local — no cluster required

---

## Overview

This workshop takes researchers through a three-act evaluation methodology using [EvalHub](https://eval-hub.github.io) as the unified evaluation platform:

- **Act 1 — Replicate Baselines**: Run established safety benchmarks (BBQ bias, MMLU ethics, Garak adversarial probes) to lock a reproducible baseline before claiming novelty.
- **Guardrails Demo**: Add a NeMo Guardrails proxy, re-run the same Garak probes — put the guardrails under the same pressure that found the original vulnerability.
- **Act 2 — Novel Contribution**: Compute Inter-Rater Reliability on your annotation dataset, register your novel benchmark in EvalHub alongside the baseline.
- **Act 3 — MCP Comparison**: A self-contained Python/Jupyter notebook calls the EvalHub MCP server directly via `requests` — no framework — to compare both approaches and produce a publication-ready figure.

Everything runs on your laptop. No Kubernetes cluster is required for the hands-on sections. A pre-recorded demo shows the same workflow at cluster scale in the closing segment.

---

## Agenda

| # | Section | Time | Runs on |
|---|---------|------|---------|
| — | Opening Presentation | 10 min | — |
| 01 | Environment Setup | 12 min | Laptop |
| 02 | Act 1 — Baseline Replication | 22 min | Laptop → model endpoint |
| — | Guardrails Demo | 8 min | Laptop |
| — | Break + Q&A | 10 min | — |
| 03 | Act 2 — Novel Contribution (IRR) | 18 min | Laptop |
| 04 | Act 3 — MCP Comparison | 23 min | Laptop |
| — | Closing Discussion | 10 min | — |

---

## Prerequisites

**Python and tooling:**

```bash
# Python 3.12+ and uv required
brew install uv          # macOS
# or: pip install uv
```

**Model endpoint — choose one:**

| Option | Notes |
|--------|-------|
| **OpenRouter** (recommended) | Free tier — get a key at [openrouter.ai/keys](https://openrouter.ai/keys) |
| **Ollama** (local, no API key) | `ollama pull llama3.2:3b && ollama serve` |
| **vLLM** (local/institutional) | Any OpenAI-compatible endpoint |

No `oc` CLI. No cluster credentials. No Docker required.

---

## Quick Start

```bash
git clone https://github.com/williamcaban/ieee-icad2026.git
cd ieee-icad2026

# Install all dependencies
uv sync
source .venv/bin/activate

# Configure your model endpoint
cp .workshop-env.example .workshop-env
# Edit .workshop-env — uncomment your model endpoint option and set your API key

# Start Section 01
cd 01-setup && bash setup.sh
```

---

## Repository Structure

```
.
├── pyproject.toml               # uv-managed dependencies (pinned)
├── uv.lock                      # locked versions
├── .workshop-env.example        # credential template — 3 endpoint options
│
├── 01-setup/                    # 12 min │ Start eval-hub-server + install evalhub-mcp
├── 02-local-evaluation/         # 22 min │ Act 1: BBQ + MMLU + Garak baselines
│   └── configs/
├── guardrails/                  # ~8 min │ NeMo Guardrails demo (after Act 1 Garak)
│   └── config/rails.co          #         Two Colang rules: PII + jailbreak
├── 03-irr-local/                # 18 min │ Act 2: IRR computation + benchmark registration
│   └── data/annotations-sample.csv
├── 04-compare/              # 23 min │ Act 3: Jupyter/Python MCP comparison notebook
│
├── config/                      # eval-hub-server provider configs
│   └── providers/               # lm_eval.yaml, garak.yaml
├── adapters/                    # eval-hub adapter implementations
│   ├── lm_eval/main.py
│   └── garak/main.py
│
├── slides/                      # Marp presentation decks (Uncover theme)
│   ├── 00-opening.md
│   ├── 01-setup-slides.md
│   ├── 02-local-eval-slides.md
│   ├── 03-irr-slides.md
│   └── 04-mcp-slides.md
│
├── tests/                       # Adapter test suite (18 unit tests)
│   └── test_lmeval_adapter.py
├── resources/                   # Quick-reference cards (OWASP, AVID, CWE)
├── setup/                       # Facilitator cluster provisioning (optional)
└── FACILITATOR_GUIDE.md         # Delivery notes, timing, recovery procedures
```

---

## Key Commands

### Section 01 — Setup

```bash
bash 01-setup/setup.sh
# Starts eval-hub-server on localhost:18080
# Registers lm-eval and garak providers
# Installs evalhub-mcp binary for Act 3

evalhub health
evalhub providers list
```

### Act 1 — Baseline Replication (Section 02)

```bash
# BBQ intersectional bias
evalhub eval run \
  --name "act1-bbq-baseline" \
  --provider lm_evaluation_harness \
  --benchmark bbq_generate \
  --model-url "${MODEL_ENDPOINT}" \
  --model-name "${MODEL_NAME}" \
  --param limit=5 --wait

# MMLU business ethics
evalhub eval run \
  --name "act1-mmlu-baseline" \
  --provider lm_evaluation_harness \
  --benchmark mmlu_business_ethics_generative \
  --model-url "${MODEL_ENDPOINT}" --model-name "${MODEL_NAME}" \
  --param limit=5 --wait

# Garak adversarial probes
evalhub eval run \
  --name "act1-garak-baseline" \
  --provider garak \
  --benchmark "lmrc.Bullying" \
  --model-url "${MODEL_ENDPOINT}" --model-name "${MODEL_NAME}" \
  --param generations=3 --wait
```

### Guardrails Demo

```bash
cd guardrails && bash setup.sh
# Starts NeMo Guardrails proxy on localhost:18090
# Two Colang rails: PII detection + jailbreak blocking
export GUARDED_ENDPOINT="http://localhost:18090/v1"

# Re-run Garak against the guarded endpoint
evalhub eval run \
  --name "guardrails-garak-guarded" \
  --provider garak --benchmark "promptinject.HijackHateHumans" \
  --model-url "${GUARDED_ENDPOINT}" --model-name "${MODEL_NAME}" \
  --param generations=3 --wait
```

### Act 2 — Novel Contribution (Section 03)

```bash
cd 03-irr-local
python3 scripts/compute_irr.py        # Cohen's κ + Krippendorff's α
python3 scripts/register_benchmark.py # Register in local EvalHub (no --dry-run)

evalhub eval run \
  --name "act2-irr-novel" \
  --provider lm_evaluation_harness \
  --benchmark icad2026-irr-safety \
  --model-url "${MODEL_ENDPOINT}" --model-name "${MODEL_NAME}" \
  --param limit=5 --wait
```

### Act 3 — MCP Comparison (Section 04)

```bash
cd 04-compare && bash setup.sh
# Opens compare_approaches.ipynb
# Or run standalone: python3 compare_approaches.py
```

---

## Rendering Slides

```bash
# Requires Marp CLI: npm install -g @marp-team/marp-cli
marp slides/00-opening.md --output slides/00-opening.html
marp slides/ --output slides/

# Or use Marp Desktop / VS Code Marp extension
```

All decks use the **Uncover** theme with a dark Red Hat colour scheme.

---

## Running Tests

```bash
# Unit tests only (no network, < 5 seconds)
uv run pytest tests/ -v -m "not smoke and not integration"

# + Smoke tests (requires HuggingFace internet access)
uv run pytest tests/ -v -m "not integration"

# Full suite (requires OPENROUTER_API_KEY)
OPENROUTER_API_KEY=sk-or-... uv run pytest tests/ -v
```

---

## Each Section Is Self-Contained

Every section has:
- `setup.sh` — idempotent configuration (safe to re-run)
- `reset.sh` — removes section output so the section can be retried cleanly
- `lab.md` — step-by-step instructions with expected outputs

---

## At Scale: Kubernetes (Pre-Recorded Demo)

The same `evalhub` CLI, benchmark IDs, and MCP notebook work against a Kubernetes cluster. Only `base_url` changes:

```bash
evalhub config set base_url https://your-evalhub-cluster.example.com
```

The closing session includes a pre-recorded demo of this running on Red Hat OpenShift AI (RHOAI 3.4+). Facilitator cluster provisioning scripts are in `setup/`.

---

## License

Apache 2.0. Red Hat, OpenShift, and OpenShift AI are trademarks of Red Hat, Inc.
NeMo Guardrails is open source software by NVIDIA.

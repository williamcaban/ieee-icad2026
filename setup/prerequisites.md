# Prerequisites

## Participant Laptop

| Requirement | Version | Install |
|------------|---------|---------|
| Python | 3.12+ | https://python.org or `brew install python@3.12` |
| uv | latest | `brew install uv` or `pip install uv` |
| OpenRouter API key (recommended) | free tier | https://openrouter.ai/keys — or use Ollama (see below) |

No `oc` CLI. No Kubernetes access. No cluster credentials. Everything runs locally.

After cloning the repo:
```bash
uv sync                   # installs all dependencies (lm-eval, garak, eval-hub-sdk, ...)
source .venv/bin/activate
```

---

## Model Endpoint Configuration

The workshop works with **any OpenAI-compatible chat completions endpoint**. Configure `.workshop-env` before the session.

### Option A — OpenRouter (recommended, free, cloud)

No GPU required. Create a free account and generate an API key at https://openrouter.ai/keys.

```bash
# In .workshop-env:
export MODEL_ENDPOINT="https://openrouter.ai/api/v1"
export MODEL_NAME="liquid/lfm-2.5-1.2b-instruct:free"
export OPENROUTER_API_KEY="sk-or-v1-..."
```

Rate limit: 20 req/min on free tier — within the workshop lab limits at `--param limit=5`.

### Option B — Ollama (local, no API key, no cloud)

Requires Ollama installed: https://ollama.com. Run before the workshop:

```bash
ollama pull llama3.2:3b   # or any instruction-tuned model
ollama serve              # keep this running in a separate terminal
```

```bash
# In .workshop-env:
export MODEL_ENDPOINT="http://localhost:11434/v1"
export MODEL_NAME="llama3.2:3b"
export OPENAI_API_KEY="ollama"       # lm-eval uses this as auth header; Ollama accepts any value
```

**Note:** Ollama is best for participants with a local GPU (8 GB VRAM+). On CPU-only laptops, inference will be slow. Use a small model (`llama3.2:3b`) and reduce `--param limit=3`.

### Option C — vLLM (local server or institutional endpoint)

```bash
# In .workshop-env:
export MODEL_ENDPOINT="http://localhost:8000/v1"    # adjust for your server
export MODEL_NAME="<model-id-as-registered-in-vLLM>"
export OPENAI_API_KEY="<your-token-if-required>"
```

---

## Optional: evalhub-mcp Binary

The `evalhub-mcp` binary is required for Section 04 (Act 3). It is automatically installed by `01-setup/setup.sh` using Homebrew if available, or by downloading from GitHub Releases.

Manual install (if `setup.sh` fails):
```bash
# Homebrew
brew install eval-hub/evalhub/evalhub-mcp

# Or: GitHub release (macOS ARM64 example)
curl -L https://github.com/eval-hub/eval-hub/releases/latest/download/evalhub-mcp-darwin-arm64 \
  -o /usr/local/bin/evalhub-mcp && chmod +x /usr/local/bin/evalhub-mcp
```

---

## Facilitator Cluster (Optional — Closing Demo Only)

No cluster is required during the hands-on portions of this workshop. The closing segment shows a **pre-recorded demo** of the same workflow running on a Kubernetes/RHOAI cluster.

If you want to provision a live cluster for the demo, run `setup/platform-setup.sh` as cluster-admin at least 24 hours before the event:

```bash
export OPENROUTER_API_KEY="sk-or-v1-..."
bash setup/platform-setup.sh
```

### What the script provisions (RHOAI 3.4+)

| Resource | Namespace | Purpose |
|---------|-----------|---------|
| `EvalHub` CR | `redhat-ods-applications` | RHOAI Dashboard BFF discovers EvalHub URL here |
| `EvalHub` CR | `workshop-eval` | Tenant instance for participant LMEvalJobs |
| Namespace labels | `workshop-eval` | Dashboard visibility + operator auto-RBAC |
| `evalhub-evaluator` Role | `workshop-eval` | EvalHub API authorization |
| `evalhub-cr-reader` Role | `redhat-ods-applications` | Participant token can list EvalHub CRs |
| `openrouter-credentials` Secret | `workshop-eval` | `OPENROUTER_API_KEY` for LMEvalJob pods |
| DSC `permitOnline: allow` | cluster-wide | LMEvalJob pods can download datasets from HuggingFace Hub |

Tested on RHOAI 3.4 (TrustyAI operator, `eval-hub-ui` sidecar in `rhods-dashboard`).

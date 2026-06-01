# Section 01 Lab — Environment Setup

**Duration**: 10 minutes
**Prerequisites**: Repo cloned, `uv sync` run at the repo root

---

## Learning Objectives

- Activate the `.venv` and verify all four tools are ready.
- Set OpenRouter API key in `.workshop-env`.
- Configure the `evalhub` CLI against the workshop EvalHub instance.
- Confirm local tools (`lm_eval`, `garak`) and cluster access (`oc`) work.

---

## Step 1 — Activate the Environment

```bash
# From the workshop repo root
source .venv/bin/activate

# Verify the four key tools
lm_eval --version
# Expected: lm-eval, version 0.4.x

garak --version
# Expected: garak 0.15.x

evalhub version
# Expected: evalhub 0.4.x

oc version --client
# Expected: Client Version: 4.1x.x
```

If any tool is missing, run `uv sync` first.

---

## Step 2 — Configure Your Workshop Environment

```bash
# Copy the example env file (only needed once)
cp .workshop-env.example .workshop-env
```

Open `.workshop-env` in your editor and set your OpenRouter API key:

```bash
# Get a free key at: https://openrouter.ai/keys
# Then edit the file:
nano .workshop-env        # or: code .workshop-env / vi .workshop-env
```

Find the line:
```bash
export OPENROUTER_API_KEY="sk-or-v1-REPLACE-WITH-YOUR-KEY"
```

Replace with your actual key, then save and source the file:

```bash
source .workshop-env
echo "Key set: ${OPENROUTER_API_KEY:0:15}..."
```

---

## Step 3 — Run Section Setup

```bash
bash setup.sh
```

This configures the `evalhub` CLI with the workshop cluster endpoint and token.

Expected output:

```
[OK]    evalhub CLI found: evalhub 0.4.0
[OK]    Loaded .workshop-env
[OK]    EVALHUB_ENDPOINT: https://workshop-evalhub-workshop-eval.apps...
[OK]    CLI configured.
[OK]    EvalHub is healthy.
[OK]    EvalHub UI: https://workshop-evalhub-workshop-eval.apps...
```

---

## Step 4 — Verify OpenRouter Access

```bash
# Quick API test — should return a short response
curl -s --max-time 10 \
  -H "Authorization: Bearer ${OPENROUTER_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"model":"liquid/lfm-2.5-1.2b-instruct:free",
       "messages":[{"role":"user","content":"Say OK"}],"max_tokens":3}' \
  https://openrouter.ai/api/v1/chat/completions | \
  python3 -c "import sys,json; d=json.load(sys.stdin); \
    print('OpenRouter OK:', d['choices'][0]['message']['content'])"
```

Expected:

```
OpenRouter OK: OK
```

---

## Step 5 — Open the EvalHub UI (Kubernetes)

The EvalHub UI is your dashboard for all cluster-side evaluations (Sections 03–04).
Open it in your browser now so it's ready:

```bash
# Print the URL
echo "https://$(oc get route workshop-evalhub -n workshop-eval \
  -o jsonpath='{.spec.host}' 2>/dev/null)"
```

Log in with your OpenShift credentials when prompted.

---

## Checkpoint

```bash
# All four must print version numbers
lm_eval --version && garak --version && evalhub version && oc version --client

# OpenRouter key must be non-empty
echo "Key length: ${#OPENROUTER_API_KEY}"   # must be > 0

# EvalHub must be healthy
evalhub health
```

---

## Troubleshooting

**`lm_eval: command not found`**: Run `source .venv/bin/activate` from the repo root.

**OpenRouter returns 401**: Check `.workshop-env` has your correct API key, then `source .workshop-env`.

**`evalhub health` fails**: Your cluster token may have expired — run `bash setup.sh` to refresh it.

**`oc: command not found`**: `oc` is only needed for Sections 03–04. You can skip this check and proceed to Section 02.

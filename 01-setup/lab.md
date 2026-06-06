# Section 01 — Environment Setup

> **Where you are:** `[ ● 01 Setup ] → [ Act 1: Baseline ] → [ Act 2: Novel ] → [ Act 3: MCP Compare ]`

**Duration**: 10 minutes · **Needs cluster?** No — laptop only

---

## What This Section Accomplishes

You activate the Python environment, wire up your OpenRouter API key, and run `setup.sh` — which starts the local `eval-hub-server` and registers the lm-eval and garak evaluation providers. By the end you have a working `evalhub` CLI pointed at a live local server.

```
Your laptop
  .venv (uv) ─────► all tools pre-installed at exact versions
  .workshop-env ──► OPENROUTER_API_KEY, MODEL_NAME, endpoints
  eval-hub-server → localhost:18080 (started by setup.sh)
```

> **Why uv?** It's Python's equivalent of `npm ci` — it installs the exact dependency tree from `uv.lock` so every participant is running identical tool versions. No version drift, no "works on my machine."

---

## Learning Objectives

- Activate `.venv` and verify all four tools respond correctly.
- Set your `OPENROUTER_API_KEY` in `.workshop-env`.
- Understand what `setup.sh` does before you run it.
- Confirm the local `eval-hub-server` is running with both providers registered.

---

## Step 1 — Activate the Environment

```bash
# From the workshop repo root:
source .venv/bin/activate
```

Verify the tools are available:

```bash
lm_eval --help | head -1        # Expected: usage: lm-eval ...
garak --version                 # Expected: garak LLM vulnerability scanner v0.15.x
evalhub version                 # Expected: evalhub 0.4.x
evalhub-mcp --version           # Expected: evalhub-mcp 0.x.x  (for Act 3)
```

**What each tool is:**

| Tool | One-sentence description |
|------|--------------------------|
| `lm_eval` | Runs curated safety benchmarks against any OpenAI-compatible model endpoint |
| `garak` | Systematically probes models with adversarial inputs to find exploitable weaknesses |
| `evalhub` | CLI for submitting evaluation jobs and reading results — works identically locally and on Kubernetes |
| `evalhub-mcp` | MCP server that exposes EvalHub to any AI coding assistant or Python script (Act 3) |

---

## Step 2 — Set Your OpenRouter API Key

```bash
cp .workshop-env.example .workshop-env
```

Open `.workshop-env` in your editor and set the API key:

```bash
nano .workshop-env        # or: code .workshop-env / vi .workshop-env
```

Find this line and replace the placeholder:

```bash
export OPENROUTER_API_KEY="sk-or-v1-REPLACE-WITH-YOUR-KEY"
```

Get a free key at **https://openrouter.ai/keys** — it takes 30 seconds. No credit card required.

Then source the file:

```bash
source .workshop-env
echo "Key: ${OPENROUTER_API_KEY:0:20}..."   # Should print your key prefix
```

---

## Step 3 — Run Section Setup

```bash
bash setup.sh
```

**What `setup.sh` does** (read this before running it):

1. Verifies all tools are on `PATH`
2. Sources `.workshop-env` and validates your model endpoint and API key
3. Exports `OPENAI_API_KEY` (the alias that `lm-eval` and `garak` read internally)
4. Starts `eval-hub-server --local` on port `18080` in the background
5. Registers the `lm_evaluation_harness` and `garak` providers
6. Installs `evalhub-mcp` binary (for Act 3 MCP comparison)

Expected output:

```
[OK]    lm_eval: ok
[OK]    garak: garak LLM vulnerability scanner v0.15.0
[OK]    evalhub: evalhub, version 0.4.0
[OK]    eval-hub-server: eval-hub-server 0.4.1
[OK]    OPENROUTER_API_KEY is set (73 chars).
[INFO]  Starting local eval-hub-server on port 18080...
[OK]    Local eval-hub-server ready at http://localhost:18080 (PID 12345)
[OK]    Provider registered: lm_evaluation_harness
[OK]    Provider registered: garak
```

Then source the updated env file:

```bash
source .workshop-env
```

---

## Step 4 — Verify the Local Server

```bash
evalhub health
```

Expected:

```json
{"status": "healthy", "build": "0.4.1", ...}
```

```bash
evalhub providers list
```

Expected: two rows — `lm_evaluation_harness` (2 benchmarks) and `garak` (2 benchmarks).

> **🔁 Reuse pattern:** `eval-hub-server` with `--local` runs on any laptop with no infrastructure. The same provider YAMLs in `config/providers/` define what benchmarks are available. To add a new evaluation framework to your own projects, copy a provider YAML and write an adapter in `adapters/`.

---

## Step 5 — Verify OpenRouter Access

```bash
curl -s --max-time 10 \
  -H "Authorization: Bearer ${OPENROUTER_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"model":"liquid/lfm-2.5-1.2b-instruct:free",
       "messages":[{"role":"user","content":"Say OK"}],"max_tokens":3}' \
  https://openrouter.ai/api/v1/chat/completions | \
  python3 -c "import sys,json; d=json.load(sys.stdin); \
    print('OpenRouter:', d['choices'][0]['message']['content'])"
```

Expected: `OpenRouter: OK`

---

## Checkpoint ✓

```bash
# All must succeed:
evalhub health | python3 -c "import sys,json; print('Server:', json.load(sys.stdin)['status'])"
evalhub providers list | grep -c "lm_evaluation\|garak"   # should print 2
echo "Key set: ${#OPENROUTER_API_KEY} chars"               # should be > 0
```

---

## What You've Built

You now have:
- A fully functional `eval-hub-server` running locally with lm-eval and garak providers
- The `evalhub` CLI configured to point at it
- OpenRouter API access verified

**In Act 1 (Section 02)**, you'll submit your first evaluation job through this server using `evalhub eval run` — the same command that works against both the local server and a Kubernetes cluster.

---

## Troubleshooting

**`eval-hub-server` not found** — Run `source .venv/bin/activate` from the repo root.

**OpenRouter returns 401** — Check `.workshop-env` has the correct key and re-run `source .workshop-env`.

**`evalhub health` fails** — The server may have stopped. Re-run `bash setup.sh`.

**`evalhub-mcp` not found** — Run `bash setup.sh` again; it installs via Homebrew or the GitHub release fallback.

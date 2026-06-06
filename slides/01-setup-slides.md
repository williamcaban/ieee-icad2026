---
marp: true
theme: uncover
paginate: true
style: |
  section { background: #0f0f1a; color: #e8e8e8; font-family: 'Red Hat Text', sans-serif; padding: 48px 64px; }
  h1 { color: #ee0000; } h2 { color: #f5a623; }
  code { background: #1e1e2e; color: #cdd6f4; padding: 2px 6px; border-radius: 4px; }
  pre { background: #1e1e2e; border-left: 4px solid #ee0000; padding: 16px; }
  .journey { background: #1a1a2e; border: 1px solid #333; padding: 12px 20px; border-radius: 6px; font-size: 0.9em; }
  .callout { background: #1a2a1a; border-left: 4px solid #50fa7b; padding: 12px 16px; margin: 12px 0; }
---

# Section 01 — Setup

<div class="journey">

`[ ● 01 Setup ]` → `[ Act 1: Baseline ]` → `[ Act 2: Novel ]` → `[ Act 3: Compare ]`

</div>

**Goal:** One working `evalhub` CLI pointed at a live local server, and `evalhub-mcp` ready for Act 3.  
**Time:** 12 minutes · **Needs cluster?** No — everything runs on your laptop.

---

## What `setup.sh` Does

```
bash setup.sh
     │
     ├── 1. Verify: lm_eval, garak, evalhub, eval-hub-server
     ├── 2. Source .workshop-env → validate MODEL_ENDPOINT and API key
     ├── 3. Export OPENAI_API_KEY (alias required by lm-eval internals)
     ├── 4. Start eval-hub-server on localhost:18080
     ├── 5. Register providers: lm_evaluation_harness, garak
     └── 6. Install evalhub-mcp binary (for Act 3)
```

The script is **idempotent** — safe to re-run. If anything breaks, `bash setup.sh` resets you.

---

## The Tool Stack

| Tool | What it is | Think of it as |
|------|------------|----------------|
| `lm_eval` | Benchmark harness for established safety tasks | `pytest` for your model |
| `garak` | Adversarial probe framework | Fuzzing for prompts |
| `eval-hub-server` | Local evaluation orchestrator | MLflow for safety evals |
| `evalhub` CLI | Submit jobs, read results | `mlflow run` equivalent |
| `evalhub-mcp` | MCP server for EvalHub | HTTP interface for Act 3 notebook |

`uv sync` pins every dependency at exact versions — no drift, no "works on my machine."

**Model endpoint:** works with OpenRouter, Ollama, vLLM, or any OpenAI-compatible endpoint.

---

## Checkpoint — What Success Looks Like

```bash
evalhub health
# {"status": "healthy", "build": "0.4.1"}

evalhub providers list
# lm_evaluation_harness  (2 benchmarks)
# garak                  (2 benchmarks)
```

<div class="callout">

If `evalhub health` fails: `bash setup.sh` resets everything.  
The server log is at `/tmp/evalhub-local.log`.

</div>

**→ Move to Act 1 when both commands succeed.**

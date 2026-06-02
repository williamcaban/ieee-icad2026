---
marp: true
theme: default
paginate: true
backgroundColor: "#0f0f1a"
color: "#e8e8e8"
style: |
  section { font-family: 'Red Hat Text', sans-serif; padding: 48px 64px; }
  h1 { color: #ee0000; } h2 { color: #f5a623; }
  code { background: #1e1e2e; color: #cdd6f4; padding: 2px 6px; border-radius: 4px; }
  pre { background: #1e1e2e; border-left: 4px solid #ee0000; padding: 16px; }
  .journey { background: #1a1a2e; border: 1px solid #333; padding: 12px 20px; border-radius: 6px; font-size: 0.9em; }
  .callout { background: #1a2a1a; border-left: 4px solid #50fa7b; padding: 12px 16px; margin: 12px 0; }
---

# Section 01 — Setup

<div class="journey">

`[ ● 01 Setup ]` → `[ 02 Local Eval ]` → `[ 03 IRR ]` → `[ 04 Kubernetes ]`

</div>

**Goal:** One working `evalhub` CLI pointed at a live local server.  
**Time:** 10 minutes · **Needs cluster?** No.

---

## What `setup.sh` Does

```
bash setup.sh
     │
     ├── 1. Verify: lm_eval, garak, evalhub, eval-hub-server
     ├── 2. Source .workshop-env → validate OPENROUTER_API_KEY
     ├── 3. Export OPENAI_API_KEY (alias for lm-eval internals)
     ├── 4. Start eval-hub-server on localhost:18080
     ├── 5. Register providers: lm_evaluation_harness, garak
     └── 6. (If logged in) store cluster endpoint for Section 04
```

You don't need to understand each step. But knowing the script is **idempotent** (safe to re-run) matters: if anything breaks, `bash setup.sh` resets you.

---

## The Tool Stack

| Tool | What it is | Think of it as |
|------|------------|----------------|
| `lm_eval` | Runs curated safety benchmarks | `pytest` for your model |
| `garak` | Adversarial probe framework | Fuzzing for prompts |
| `eval-hub-server` | Local evaluation orchestrator | MLflow for safety evals |
| `evalhub` CLI | Submit jobs, read results | `mlflow run` equivalent |

`uv sync` installed all of these at exact versions — no drift, no "works on my machine."

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

**→ Move to Section 02 when both commands succeed.**

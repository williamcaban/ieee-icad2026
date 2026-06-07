---
marp: true
theme: uncover
paginate: true
style: |
  section {
    background: #0f0f1a;
    color: #e8e8e8;
    font-family: 'Red Hat Text', 'Segoe UI', sans-serif;
    font-size: 28px;
    padding: 48px 64px;
  }
  h1 { color: #ee0000; font-size: 2.2em; }
  h2 { color: #f5a623; border-bottom: 2px solid #ee0000; padding-bottom: 8px; }
  h3 { color: #7bc8f6; }
  code { background: #1e1e2e; color: #cdd6f4; padding: 2px 6px; border-radius: 4px; }
  pre { background: #1e1e2e; border-left: 4px solid #ee0000; padding: 16px; font-size: 0.85em; }
  .callout { background: #1a2a1a; border-left: 4px solid #50fa7b; padding: 12px 16px; margin: 16px 0; border-radius: 0 4px 4px 0; }
  .warning { background: #2a1a1a; border-left: 4px solid #f5a623; padding: 12px 16px; margin: 16px 0; }
  .cite { font-size: 0.75em; color: #888; font-style: italic; margin-top: 8px; }
  .meta { font-size: 0.55em; color: #aaa; }
  .cols3 { display: grid; grid-template-columns: repeat(3, 1fr); gap: 1em; font-size: 0.75em; margin-top: 0.5em; }
  .cols3 > div { background: #1a1a2e; border-top: 3px solid #ee0000; padding: 14px 12px; border-radius: 0 0 4px 4px; }
  table { font-size: 0.88em; }
  .center { text-align: center; }
  .journey { background: #1a1a2e; border: 1px solid #333; padding: 12px 20px; border-radius: 6px; font-size: 0.9em; }
---

# Section 01: Setup

<div class="journey">

`[ ● 01 Setup ]` → `[ 02 Baseline ]` → `[ 03 Novel ]` → `[ 04 Compare ]`

</div>

- **Goal:** One working `evalhub` CLI pointed at a live local server.  
- **Time:** 12 minutes
- **Needs cluster?** No, everything runs on your laptop.

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

```

The script is **idempotent**, safe to re-run.
If anything breaks, `bash setup.sh` resets you.

---

## The Tool Stack

| Tool | What it is | Think of it as |
|:------|:------------|:----------------|
| `lm_eval` | Benchmark harness for established safety tasks | `pytest` for your model |
| `garak` | Adversarial probe framework | Fuzzing for prompts |
| `eval-hub-server` | Local evaluation orchestrator | MLflow for safety evals |
| `evalhub` CLI | Submit jobs, read results | `mlflow run` equivalent |

- `uv sync` pins every dependency at exact versions: no drift, no "works on my machine."

- **Model endpoint:** works with any OpenAI-compatible endpoint (e.g., OpenRouter, Ollama, vLLM, etc.)

---

## Checkpoint: What Success Looks Like

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

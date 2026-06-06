# Act 3 — MCP Server as Research Interface

> **Where you are:** `[ Act 1: Baseline ] → [ Act 2: Novel ] → [ ● Act 3: Compare ]`

**Duration**: 23 minutes · **Needs cluster?** No — entirely laptop-side

---

## What This Section Accomplishes

You have two benchmarks in EvalHub:
- **Approach A** (baseline): `bbq_generate` — the community-accepted bias benchmark from Act 1
- **Approach B** (novel): `icad2026-irr-safety` — your IRR-validated benchmark from Act 2

This section uses the **EvalHub MCP server** to submit both approaches, compare results, and produce a publication-ready figure — using nothing but Python and HTTP.

```
compare_approaches.py / .ipynb
          │
          ▼  JSON-RPC 2.0 over HTTP  (see mcp_client.py — 60 lines total)
evalhub-mcp (localhost:3001)
          │
          ▼
eval-hub-server (localhost:18080)
          │
    ┌─────┴─────┐
  Job A        Job B
  bbq_generate  icad2026-irr-safety
    └─────┬─────┘
          ▼
     comparison_plot.png
     comparison_report.json
```

---

## Learning Objectives

- Understand that MCP is JSON-RPC 2.0 over HTTP — readable, hackable, zero framework
- Read `mcp_client.py` and see the complete client implementation in 60 lines
- Submit two evaluation jobs programmatically and compare their results
- Produce a publication-ready comparison figure and structured JSON report

---

## Setup

```bash
cd 04-mcp-compare
bash setup.sh
```

This installs `evalhub-mcp` (if needed), writes a local config, and starts the MCP server on port 3001 pointing at the running `eval-hub-server`.

---

## Step 1 — Read the MCP Client (2 min)

Before running anything, open `mcp_client.py`:

```bash
cat mcp_client.py
```

This is the entire MCP client. Three methods. Sixty lines. No SDK, no async library — just `requests` and JSON-RPC 2.0. Read it and convince yourself you could have written it.

The three tools the server exposes:

| Tool | What it does |
|------|-------------|
| `submit_evaluation` | Start a job — model URL, benchmark, provider, name |
| `get_job_status` | Check progress; returns scores when `status == COMPLETED` |
| `cancel_job` | Stop a running job |

---

## Step 2 — Configure Your Approaches (2 min)

Open `compare_approaches.py` (or `compare_approaches.ipynb`) and look at the configuration block at the top:

```python
APPROACH_A = {
    "name":        "baseline-bbq",
    "benchmark":   "bbq_generate",
    "provider":    "lm_evaluation_harness",
    "description": "BBQ intersectional bias — established baseline (Parrish et al. 2022)",
}

APPROACH_B = {
    "name":        "novel-irr-safety",
    "benchmark":   "icad2026-irr-safety",
    "provider":    "lm_evaluation_harness",
    "description": "IRR-validated safety benchmark — novel contribution (α = 0.81)",
}
```

This is the only cell you need to modify to run your own comparison. Change benchmark IDs, descriptions, or model parameters — nothing else changes.

---

## Step 3 — Submit and Compare (15 min)

**Option A — Standalone script:**

```bash
source ../.workshop-env
python3 compare_approaches.py
```

**Option B — Jupyter notebook:**

```bash
jupyter lab compare_approaches.ipynb
# Run all cells (Shift+Enter through each, or Kernel → Restart & Run All)
```

The script will:
1. Connect to `evalhub-mcp` at `localhost:3001` and list available tools
2. Submit Approach A (baseline) and Approach B (novel) as separate jobs
3. Poll `get_job_status` every 5 seconds until both complete
4. Print a results table
5. Plot a side-by-side bar chart (dark theme, matches workshop style)
6. Export `results/comparison_report.json`

Expected console output:

```
==============================================================
  EvalHub MCP : http://localhost:3001
  Model       : liquid/lfm-2.5-1.2b-instruct:free
==============================================================

Submitting evaluations:
  Submitting: BBQ intersectional bias — established baseline (Parrish et al. 2022)
  → job_id: job-abc123
  Submitting: IRR-validated safety benchmark — novel contribution (α = 0.81)
  → job_id: job-def456

Polling every 5s (timeout 600s)...
  2/2 completed  (47s elapsed)

Results summary:
  Approach                                              Score
  ---------------------------------------------------- --------
  BBQ intersectional bias — established baseline        0.2000
  IRR-validated safety benchmark — novel contribution   0.7500

  Plot saved → results/comparison_plot.png
  Report saved → results/comparison_report.json
```

---

## Step 4 — Inspect the Outputs (2 min)

```bash
# Structured comparison report
python3 -c "import json; r=json.load(open('results/comparison_report.json')); \
  [print(a['description'], '→', a['overall_score']) for a in r['approaches']]"

# Open the plot
open results/comparison_plot.png      # macOS
# xdg-open results/comparison_plot.png  # Linux
```

`comparison_report.json` is designed as supplementary material for a paper — it contains the model info, both benchmark IDs, the scores, and the full job status from EvalHub.

---

## Checkpoint ✓

```bash
python3 -c "
import json, pathlib
r = json.load(open('results/comparison_report.json'))
print(f'Approaches compared: {len(r[\"approaches\"])}')
for a in r['approaches']:
    score = a['overall_score']
    print(f'  {a[\"benchmark\"]}: {score}')
assert pathlib.Path('results/comparison_plot.png').exists(), 'plot missing'
print('PASS')
"
```

---

## Reuse Pattern

To compare any two benchmarks, change Cell 1 / the config block:

```python
# Compare guarded vs unguarded model (from the guardrails demo):
APPROACH_A = {
    "name": "bare-model-garak",
    "benchmark": "lmrc.Bullying",
    "provider": "garak",
    "description": "Garak probe — bare model (no guardrails)",
}
APPROACH_B = {
    "name": "guarded-model-garak",
    "benchmark": "lmrc.Bullying",
    "provider": "garak",
    "description": "Garak probe — NeMo Guardrails active",
}
```

Change `MODEL_URL` to `http://localhost:18090/v1` for Approach B to route through the guardrail proxy. The plot and report cells stay unchanged.

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `Connection refused` on port 3001 | `bash setup.sh` to start `evalhub-mcp` |
| `icad2026-irr-safety` benchmark not found | Run `cd ../03-irr-local && python3 scripts/register_benchmark.py` |
| Jobs stuck in `RUNNING` | Call `mcp.cancel_job(job_id)` in the script; resubmit |
| `matplotlib` import fails | `cd .. && uv sync` |
| Jupyter not found | Use `compare_approaches.py` (standalone, identical logic) |
| Score shows `None` | Check job status: `python3 -c "from mcp_client import EvalHubMCPClient; m=EvalHubMCPClient(); print(m.get_job_status('<job-id>'))"`|

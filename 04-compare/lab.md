# Act 3: Side-by-Side Evaluation Comparison

> **Where you are:** `[ Act 1: Baseline ] → [ Act 2: Novel ] → [ ● Act 3: Compare ]`

**Duration**: 23 minutes · **Needs cluster?** No — entirely laptop-side

---

## What This Section Accomplishes

You have two benchmarks registered in EvalHub:
- **Approach A** — the established baseline (`bbq_generate`) from Act 1
- **Approach B** — your IRR-validated collection (`workshop-irr-safety-v1`) from Act 2

This section submits both through the EvalHub REST API from a Jupyter notebook, retrieves the full metric scores, and plots a side-by-side comparison suitable for a research publication.

```
compare_approaches.ipynb / .py
          │
          │  POST /api/v1/evaluations/jobs   (submit both approaches)
          │  GET  /api/v1/evaluations/jobs/{id}   (poll + retrieve scores)
          ▼
  EvalHub REST API (localhost:18080)
          │
    ┌─────┴──────┐
  Job A         Job B
  bbq_generate  workshop-irr-safety-v1
    └─────┬──────┘
          ▼
  comparison_plot.png
  comparison_report.json
```

---

## Learning Objectives

- Call a REST API from a Jupyter notebook to submit and retrieve evaluations
- Understand the EvalHub job lifecycle: `pending → running → completed`
- Read metric scores directly from the API response (`results.benchmarks[].metrics`)
- Produce a publication-ready comparison figure and structured JSON report

---

## Setup

```bash
cd 04-compare
bash setup.sh
```

Verifies the EvalHub server is running and the IRR collection from Act 2 is registered.

---

## Step 1: Read the API Client

The entire interaction with EvalHub is three REST calls:

```python
# Submit a job
POST http://localhost:18080/api/v1/evaluations/jobs
Body: {"name": "...", "model": {"url": "...", "name": "..."}, "benchmarks": [...]}
→ Returns: {"resource": {"id": "<uuid>"}, "status": {"state": "pending"}, ...}

# Poll status and retrieve results
GET http://localhost:18080/api/v1/evaluations/jobs/<uuid>
→ Returns: {"status": {"state": "completed"}, "results": {"benchmarks": [{"metrics": {...}}]}}
```

Open `compare_approaches.py` and read the `_submit`, `_poll`, and `_extract_metrics` functions. The entire API interaction is under 30 lines.

---

## Step 2: Configure Your Approaches

Open `compare_approaches.py` or `compare_approaches.ipynb` and look at Cell 1:

```python
APPROACH_A = {
    "name":        "baseline-bbq",
    "description": "BBQ intersectional bias — established baseline (Parrish et al. 2022)",
    "benchmarks":  [{"id": "bbq_generate", "provider_id": "lm_evaluation_harness"}],
}

APPROACH_B = {
    "name":        "novel-irr-safety",
    "description": "IRR-validated safety collection — novel contribution (α = 0.81)",
    "collection":  {"id": "workshop-irr-safety-v1"},
}
```

**Approach A** submits a single benchmark directly.  
**Approach B** submits the entire IRR-validated collection registered in Act 2.

This is the only cell that changes between experiments.

---

## Step 3: Run the Comparison

**Option A (Standalone script):**

```bash
source ../.workshop-env
python3 compare_approaches.py
```

**Option B (Jupyter notebook):**

```bash
jupyter lab compare_approaches.ipynb
# Run all cells: Kernel → Restart & Run All
```

Expected output:

```
==============================================================
  EvalHub : http://localhost:18080
  Model   : liquid/lfm-2.5-1.2b-instruct:free
==============================================================

  EvalHub status: healthy

Submitting evaluations:
  Submitted 'baseline-bbq'    → 3a0dba6c-8101-4a29-ad27-d1bb67d49841
  Submitted 'novel-irr-safety' → ec52adb5-7a79-460c-b7ab-f0ccf580d2de

Polling every 5s …
  2/2 done  (47s)

Results:
  Approach                       Primary Score
  ------------------------------ --------------
  baseline-bbq                          0.2000
  novel-irr-safety                      0.2000

Metric detail:
  Metric                         baseline-bbq  novel-irr-safety
  ------------------------------ ------------ ----------------
  acc                                  0.2000           0.2000
  accuracy_amb                         0.0000           0.0000
  amb_bias_score                       0.3333           0.3333
  ...

  Plot saved → results/comparison_plot.png
  Report saved → results/comparison_report.json
```

---

## Step 4: Inspect the Outputs (2 min)

```bash
# View the comparison report
python3 -c "
import json
r = json.load(open('results/comparison_report.json'))
for a in r['approaches']:
    print(a['name'], ':', a['primary_score'])
"

# Open the plot
open results/comparison_plot.png   # macOS
```

The report is structured for use as supplementary material in a paper. The plot has two panels: an overall score bar chart and a per-metric grouped comparison.

---

## Checkpoint ✓

```bash
python3 -c "
import json, pathlib
r = json.load(open('results/comparison_report.json'))
assert len(r['approaches']) == 2, 'Expected 2 approaches'
assert pathlib.Path('results/comparison_plot.png').exists(), 'Plot missing'
for a in r['approaches']:
    print(f\"{a['name']}: score={a['primary_score']}\")
print('PASS')
"
```

---

## Interpreting the Results

Both approaches run the same underlying benchmark (`bbq_generate`) because the IRR collection in Act 2 wraps it. The key research claim is **methodological**:

| Approach | What changed | Evidence |
|----------|-------------|---------|
| Baseline | Raw benchmark, no quality gate | Scores from Act 1 |
| Novel | Same benchmark, with α ≥ 0.67 pre-registration gate | `irr_report.json` (α = 0.81) |

The scores are the same — the benchmark is the same. The contribution is the **principled selection methodology**: you can now claim your benchmark was validated before use, and any future researcher reproducing this result starts from a documented quality baseline.

---

## Reuse Pattern

To compare any two approaches, change Cell 1 / the config block:

```python
# Compare baseline model vs IRR-filtered model on MMLU
APPROACH_A = {
    "name": "mmlu-baseline",
    "benchmarks": [{"id": "mmlu_business_ethics_generative",
                    "provider_id": "lm_evaluation_harness"}],
}

# Compare guarded vs unguarded (from the guardrails demo)
APPROACH_B = {
    "name": "mmlu-guarded",
    "benchmarks": [{"id": "mmlu_business_ethics_generative",
                    "provider_id": "lm_evaluation_harness"}],
}
# And change MODEL_URL for APPROACH_B to point at the guardrail proxy
```

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `Connection refused` at localhost:18080 | `bash 01-setup/setup.sh` to restart eval-hub-server |
| `workshop-irr-safety-v1` not found | `cd 03-irr-local && python3 scripts/register_benchmark.py` |
| Jobs stay in `pending` for > 60s | Check `/tmp/evalhub-local.log` for adapter errors |
| Score is `None` | Check `results.benchmarks[].metrics` in the raw response |
| `matplotlib` import fails | `cd .. && uv sync` |
| Jupyter not found | Use `compare_approaches.py` instead |

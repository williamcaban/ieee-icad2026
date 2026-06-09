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

# Act 3: Side-by-Side Evaluation Comparison

<div class="journey">

`[ 01 Setup ]` → `[ 02 Baseline ]` → `[ 03 Novel ]` → `[ ● 04 Compare ]`

</div>

You have two registered approaches in EvalHub. Act 3 submits both through the REST API from a Jupyter notebook, retrieves metric scores, and plots a publication-ready comparison.

---

## The Research Question

You claimed your IRR-validated collection is a more principled approach than running a raw benchmark. Now you need to show it:

- **Same model**: controls for inference variation
- **Same infrastructure**: controls for environment differences
- **Same evaluation engine**: controls for framework differences

<div class="warning">

What remains is **methodological difference**. That's the contribution.

</div>

---

## Two Approaches, One API

```python
APPROACH_A = {
    "name":       "baseline-bbq",
    "benchmarks": [{"id": "bbq_generate",
                    "provider_id": "lm_evaluation_harness"}],
}

APPROACH_B = {
    "name":       "novel-irr-safety",
    "collection": {"id": "workshop-irr-safety-v1"},  # from Act 2
}
```

- `Approach A` submits a single benchmark directly.  
- `Approach B` submits the IRR-validated collection, with α ≥ 0.67 as the quality gate.

---

## Three REST Calls as the Interface

```python
import requests

# 1. Submit a job
r = requests.post(f"{EVALHUB}/api/v1/evaluations/jobs", json={
    "name": approach["name"],
    "model": {"url": MODEL_URL, "name": MODEL_NAME},
    "benchmarks": [{"id": "bbq_generate", "provider_id": "..."}],
})
job_id = r.json()["resource"]["id"]

# 2. Poll for completion
r = requests.get(f"{EVALHUB}/api/v1/evaluations/jobs/{job_id}")
state = r.json()["status"]["state"]   # pending → running → completed

# 3. Extract scores
metrics = r.json()["results"]["benchmarks"][0]["metrics"]
# → {"acc": 0.2, "amb_bias_score": 0.333, ...}
```

---

## The Notebook Structure

Seven cells. Cell 1 is the only one researchers modify.

```
Cell 1  Config     ── APPROACH_A and APPROACH_B (edit here)
Cell 2  Verify     ── health check + confirm collection exists
Cell 3  Submit     ── POST both approaches to EvalHub
Cell 4  Poll       ── GET status every 5s until both completed
Cell 5  Extract    ── parse scores from results.benchmarks[].metrics
Cell 6  Plot       ── bar chart (overall) + grouped chart (per-metric)
Cell 7  Export     ── comparison_report.json for supplementary material
```

---

## Reading the Results

```json
{
  "results": {
    "benchmarks": [{
      "id": "bbq_generate",
      "metrics": {
        "acc":            0.2,
        "accuracy_amb":   0.0,
        "amb_bias_score": 0.333,
        "accuracy_disamb": 0.5
      }
    }]
  }
}
```

Every metric the lm-eval adapter computed is in `metrics`. The comparison notebook plots them all — not just the primary score.

---

## What the Plot Shows

Two panels:

- **Left** panel: Primary score bar chart: overall `acc` for each approach  
- **Right** panel: Per-metric grouped chart: `acc`, `accuracy_amb`, `amb_bias_score`, `accuracy_disamb` side by side

- Both approaches run the same underlying benchmark. 
  - The scores are identical. 
  - **The contribution is the methodology**, the IRR quality gate that justifies using these labels.

<div class="callout">

"Same score, different rigour" is a publishable finding. Most benchmarks in the literature lack annotation reliability analysis.

</div>

---

## What You Have Built

- ✅ Both approaches submitted and evaluated on the same model and infrastructure  
- ✅ `comparison_plot.png`: two-panel figure suitable for a paper or poster  
- ✅ `comparison_report.json`: structured data for supplementary materials  
- ✅ Full audit trail: job IDs link back to EvalHub run records

<div class="callout">

**The pattern generalises.** Change `APPROACH_B` to any other collection, benchmark, or model configuration. The notebook runs unchanged.

</div>

---

## At Scale: Kubernetes

The same `evalhub eval run` commands and REST API paths work against EvalHub on K8s, only `EVALHUB_ENDPOINT` changes:

```bash
export EVALHUB_ENDPOINT="https://workshop-evalhub.apps.cluster.example.com"
# The notebook is identical (no other change required)
```

Running as `LMEvalJob` pods on Kubernetes gives persistent storage, RHOAI Dashboard visibility, and governance artifact export.

---

## Pre-Recorded Demos

Watch these after the session to see the full cluster-scale workflow:

- [(demo)](https://interact.redhat.com/share/GkiNIu6IqVRB04UolnoN) **Red Teaming via EvalHub and Guardrails** 
  - Adversarial probe runs + NeMo Guardrails proxy. The same pattern from the guardrails demo, running on RHOAI/Kubernetes.
<br />
- [(demo)](https://interact.redhat.com/share/JKcSMeq3lPdyMQ2Kzful) **Running Evaluations & Evaluation Collections with EvalHub**
  - Full collection runs and result comparison, same commands, cluster scale.

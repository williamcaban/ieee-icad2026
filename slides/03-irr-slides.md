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
  .analogy { background: #1a1a2e; border: 1px solid #7bc8f6; padding: 16px 20px; margin: 16px 0; border-radius: 6px; font-style: italic; }
---

# Act 2: Your Novel Contribution

<div class="journey">

`[ 01 Setup ]` → `[ 02 Baseline ]` → `[ ● 03 Novel ]` → `[ 04 Compare ]`

</div>

**The question Act 1 leaves open:**
- The baseline you just ran measured the model against human-annotated labels. But *were those annotations reliable?* And if not, are yours?

---

## The Problem That Act 1 Doesn't Solve

- In Act 1 you got `bbq_generate acc = 0.20`. That score compares model outputs against labels created by human annotators.

  **But what if the annotators disagreed?**

  - If three annotators labelled the same text as `safe`, `unsafe`, and `ambiguous`, whose label is correct?

    The model's score is measuring label disagreement, not model safety.

  This is not a corner case. It is endemic to benchmark construction in safety and fairness evaluation. Most published benchmarks do not report inter-rater reliability.

<div class="warning">

A benchmark with low annotator agreement is not a benchmark,
it is noise with a citation.

</div>

---

## Your Contribution: An IRR Quality Gate

- **IRR analysis applied as a pre-registration quality gate** is itself a research contribution.

  It answers: *before running a model against this dataset, can you demonstrate the labels are reliable enough to draw conclusions from?*

<div class="analogy">

- Imagine two radiologists labelling X-rays as "concerning" or "clear."  
If they agree 95% of the time: trust the label.  
If they agree 50% of the time: the label is a coin flip.  
- **`Krippendorff's Alpha`** quantifies this for any number of annotators.

</div>

---

## What IRR Analysis Produces

```
annotations-sample.csv ──► compute_irr.py ──► irr_report.json
      │                                              │
  20 texts              Cohen's Kappa (pairwise)  Clean benchmark spec
  3 annotators          Krippendorff's Alpha      α embedded as metadata
  safe/unsafe/ambiguous Ambiguous text detection  Excluded items listed
                                                  Recommendation: REGISTER
```

- `irr_report.json` is a **reproducibility artifact**. It contains the raw annotations, the computed metrics, the excluded items, and the decision. Anyone reading your benchmark can verify the α (alpha) value without re-running your annotation pipeline.

---

## Interpreting the Output

```
  α = 0.8118  (STRONG) ==> benchmark labels are reliable
  κ (Annotator 1 vs 2) = 0.6694  (moderate)
  κ (Annotator 2 vs 3) = 0.3750  (fair/poor)  ← investigate this pair
```

| α value | Decision |
|:---------|:----------|
| α < 0.67 | Do not register (re-annotate or discard) |
| 0.67 ≤ α < 0.80 | Register with caution (document the uncertainty) |
| α ≥ 0.80 | Register (labels are reliable as ground truth) |

<div class="callout">

- The pairwise κ between Annotators 2 and 3 (0.375) reveals a systematic disagreement on where the `safe`/`unsafe` boundary lies.

  In a production annotation pipeline, you would run a calibration session before annotating more data.

</div>

---

## Registering the Novel Benchmark

Once α meets the threshold, register it in local EvalHub (no `--dry-run`):

```bash
python3 scripts/register_benchmark.py
evalhub collections list   # confirm workshop-irr-safety-v1 appears
```

---

## Running the Novel Benchmark

Run against the same model used in Act 1:

```bash
evalhub eval run \
  --name "act2-irr-novel" \
  --provider lm_evaluation_harness \
  --benchmark icad2026-irr-safety \
  --model-url "${MODEL_ENDPOINT}" \
  --model-name "${MODEL_NAME}" \
  --param limit=5 --wait
```

Same model, same framework. Act 3 can now compare on equal footing.

---

## The Reliability Evidence Is in the Benchmark

```json
{
  "spec": {
    "irr_metadata": {
      "krippendorff_alpha": 0.8118,
      "alpha_threshold": 0.67,
      "pairwise_kappa": { "A1_vs_A2": 0.67, "A1_vs_A3": 0.53, "A2_vs_A3": 0.38 },
      "ambiguous_excluded": 0,
      "recommendation": "REGISTER"
    }
  }
}
```

- The reliability evidence travels with the benchmark. Anyone who runs `evalhub benchmarks show icad2026-irr-safety` sees the α value, the annotator pairs, the threshold, not a link to a separate PDF.

This is what "reproducible" means in practice.

---

## What You Have Built

- ✅ IRR analysis (Cohen's κ + Krippendorff's α) on a real annotation dataset  
- ✅ Principled exclusion. Ambiguous texts filtered, not silently dropped  
- ✅ Benchmark registered in EvalHub with reliability metadata embedded  
- ✅ Novel benchmark results against the same model as Act 1

<div class="callout">

- **→ Act 3:** Both approaches now exist in EvalHub.
  - Next, a Python notebook calls the EvalHub REST API, retrieves full metric scores, and plots a publication-ready comparison.

</div>

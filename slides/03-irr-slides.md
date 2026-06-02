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
  pre { background: #1e1e2e; border-left: 4px solid #ee0000; padding: 16px; font-size: 0.85em; }
  .journey { background: #1a1a2e; border: 1px solid #333; padding: 12px 20px; border-radius: 6px; font-size: 0.9em; }
  .callout { background: #1a2a1a; border-left: 4px solid #50fa7b; padding: 12px 16px; margin: 12px 0; }
  .analogy { background: #1a1a2e; border: 1px solid #7bc8f6; padding: 16px 20px; margin: 12px 0; border-radius: 6px; font-style: italic; }
---

# Section 03 — IRR/IAA Custom Benchmark

<div class="journey">

`[ 01 Setup ]` → `[ 02 Local Eval ]` → `[ ● 03 IRR ]` → `[ 04 Kubernetes ]`

</div>

**Question:** Can you trust the scores from Section 02? Only if you can trust the benchmark labels.

---

## The Problem with Labels

In Section 02 you got `bbq_generate acc = 0.20`.

That score compares model outputs against *ground-truth labels* created by human annotators.

**But what if the annotators disagreed?**

If 3 annotators labelled the same text as `safe`, `unsafe`, and `ambiguous` — whose label is correct? The model's score is meaningless until you resolve this.

---

## The Intuition

<div class="analogy">

Imagine two doctors labelling X-rays as "concerning" or "clear."  
If they agree 95% of the time — trust the label.  
If they agree 50% of the time — it's a coin flip.  
The X-ray label becomes noise, not signal.

**Krippendorff's Alpha** quantifies this for any number of annotators.

</div>

| α value | Interpretation |
|---------|----------------|
| α < 0.67 | Unreliable — do not use these labels |
| 0.67 ≤ α < 0.80 | Acceptable — use with caution |
| α ≥ 0.80 | Strong — high confidence in labels |

---

## What You Produce

```
annotations-sample.csv  ──► compute_irr.py  ──►  irr_report.json
     │                                                  │
  20 texts                   Cohen's Kappa         Clean benchmark
  3 annotators            Krippendorff's Alpha    (excluded: ambiguous)
  safe/unsafe/ambiguous   Ambiguous detection     Reliability embedded
```

`irr_report.json` travels to Section 04 where it becomes a **registered cluster benchmark** — with the reliability evidence built in, auditable by anyone.

---

## Reading the Output

```
  α = 0.8118  — STRONG — benchmark labels are reliable
  κ (A1 vs A2) = 0.6694  (moderate)
  κ (A2 vs A3) = 0.3750  (fair/poor)  ← investigate these two
```

<div class="callout">

Low kappa between A2 and A3 means they interpret the label boundary differently.  
In production: run a calibration session before annotating more data.

</div>

**α = 0.81** means: this benchmark can be used as ground truth with high confidence.  
**α = 0.55** would mean: discard or re-annotate — scores against it measure label noise.

---

## So What?

Every benchmark you use — BBQ, ToxiGen, TruthfulQA — was built by annotators who may or may not have agreed. IRR analysis is how you *audit* a benchmark before trusting it.

When a regulator asks "how do you know your evaluation is valid?" — `irr_report.json` is part of the answer.

<div class="callout">

🔁 **Reuse pattern:** `compute_irr.py` works with any annotation CSV (same column structure). Replace `annotations-sample.csv` with your own research data. The α threshold is configurable.

</div>

**→ Section 04:** Same `evalhub` CLI, different `base_url` — now pointing at the cluster.

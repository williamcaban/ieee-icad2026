# Section 03 — IRR/IAA Custom Benchmark (Local)

**Duration**: 12 minutes
**Mode**: Hands-on — runs entirely on the laptop
**Position in agenda**: 0:46 – 0:58 (after break)

---

## What You Will Do

Compute Inter-Rater Reliability (IRR) metrics on a human annotation dataset
and produce a signed benchmark specification — all locally, no Kubernetes.

The `irr_report.json` you generate here is what Section 04 uploads to EvalHub
on the cluster.

---

## Why IRR Matters for AI Evaluation

A benchmark is only as trustworthy as its labels. If three annotators can't
agree on whether a text is "safe" or "unsafe," the benchmark score is measuring
label noise, not model behaviour.

**Krippendorff's Alpha** quantifies agreement across all annotators on an ordinal
scale. α < 0.67 is unreliable; α ≥ 0.80 is strong.

**Cohen's Kappa** reveals *which annotator pairs* disagree — useful for diagnosing
systematic bias or ambiguous label boundaries.

Texts where all three annotators differ are flagged as **ambiguous** and excluded
from the benchmark before registration.

---

## Local vs Kubernetes Split

| This section (03) | Next section (04) |
|---|---|
| Inspect annotation CSV | Upload benchmark to EvalHub |
| Run `compute_irr.py` | Register via `evalhub` CLI or API |
| Produce `irr_report.json` | Use benchmark in custom collection |
| All on laptop, no cluster | Requires cluster access |

---

## Files

| File | Purpose |
|------|---------|
| `README.md` | This file |
| `lab.md` | Step-by-step instructions |
| `setup.sh` | Verifies `.venv` tools and env |
| `reset.sh` | Removes `irr_report.json` |
| `data/annotations-sample.csv` | 20-text annotation dataset (3 annotators) |
| `scripts/compute_irr.py` | Cohen's Kappa + Krippendorff's Alpha |
| `scripts/register_benchmark.py` | Builds benchmark spec (runs in Section 04) |

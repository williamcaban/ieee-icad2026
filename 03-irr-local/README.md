# Section 03 — IRR/IAA Custom Benchmark (Local)

**Duration**: 18 minutes
**Mode**: Hands-on — runs entirely on the laptop
**Position in agenda**: Act 2 (0:54 to 1:12, after break)

---

## What You Will Do

Compute Inter-Rater Reliability (IRR) metrics on a human annotation dataset,
then register your novel benchmark as an EvalHub collection for comparison in Act 3.
All local — no Kubernetes.

---

## Why IRR Matters for AI Evaluation

A benchmark is only as trustworthy as its labels. If three annotators cannot
agree on whether a text is "safe" or "unsafe," the benchmark score is measuring
label noise, not model behaviour.

**Krippendorff's Alpha** quantifies agreement across all annotators on an ordinal
scale. α < 0.67 is unreliable; α >= 0.80 is strong.

**Cohen's Kappa** reveals which annotator pairs disagree, useful for diagnosing
systematic bias or ambiguous label boundaries.

Texts where all three annotators differ are flagged as **ambiguous** and excluded
from the benchmark before registration.

---

## What Gets Built

| Step | Output |
|------|--------|
| Inspect annotation CSV | Understanding of label distribution |
| Run `compute_irr.py` | `irr_report.json` with α and κ metrics |
| Run `register_benchmark.py` | `workshop-irr-safety-v1` collection in EvalHub |
| Act 3 comparison | Both baseline and novel collection compared side by side |

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
| `scripts/register_benchmark.py` | Registers IRR benchmark as EvalHub collection |

# Section 03 — IRR/IAA Custom Benchmark

> **Where you are:** `[ 01 Setup ] → [ 02 Baseline ] → [ ● 03 Novel ] → [ 04 Compare ]`

**Duration**: 12 minutes · **Needs cluster?** No — entirely laptop-side

---

## What This Section Accomplishes

You validate the *trustworthiness* of a human-annotated safety dataset using Inter-Rater Reliability (IRR) metrics, then register your novel benchmark as an EvalHub collection. Act 3 uses this collection in the side-by-side comparison.

In Act 1 you ran benchmarks and got scores. But a score is only meaningful if the benchmark's labels are trustworthy. If three human annotators labelled a text differently, which label does the model's score depend on?

This section answers that question, then registers a clean benchmark from only the labels that annotators agreed on.

---

## The Core Intuition

> Imagine two doctors labelling X-rays as "concerning" or "clear."  
> If they agree 95% of the time — you can trust the label.  
> If they agree 50% of the time — coin-flip territory — the label is noise, not signal.  
>  
> **Krippendorff's Alpha** quantifies this agreement for any number of annotators and any label scale.  
> α < 0.67 → unreliable, do not use  
> 0.67 ≤ α < 0.80 → acceptable, use with caution  
> α ≥ 0.80 → strong, high confidence  

The same logic applies to safety labels. If your three annotators can't agree whether a text is `safe` or `unsafe`, your benchmark is measuring *their disagreement*, not model safety.

**Cohen's Kappa** adds one more dimension: it checks pairwise agreement between each annotator pair, corrected for chance. A low kappa between Annotator 1 and Annotator 3 specifically tells you *where* the disagreement lives.

---

```
                    YOUR ANNOTATION DATASET
                    (data/annotations-sample.csv)
                            │
                            ▼
              ┌─────────────────────────────┐
              │   compute_irr.py            │
              │                             │
              │  Cohen's Kappa (pairwise)   │
              │  Krippendorff's Alpha       │
              │  Ambiguous text detection   │
              └─────────────────────────────┘
                            │
              ┌─────────────┴──────────────┐
              │                            │
      irr_report.json              Excluded texts
      (clean benchmark)            (contested labels)
              │
              ▼
     register_benchmark.py
     (registers as EvalHub collection for Act 3)
```

---

## Learning Objectives

- Understand why label reliability matters before trusting evaluation scores.
- Run `compute_irr.py` and interpret Cohen's Kappa and Krippendorff's Alpha.
- Identify texts where all annotators disagreed — and understand why excluding them is principled, not arbitrary.
- Register your novel benchmark as an EvalHub collection for comparison in Act 3.

---

## Setup

```bash
cd 03-irr-local
bash setup.sh
```

---

## Step 1 — Inspect the Annotation Dataset (2 min)

```bash
cat data/annotations-sample.csv
```

The CSV has 20 texts labelled by three annotators (`annotator_1`, `annotator_2`, `annotator_3`). Labels: `safe` | `unsafe` | `ambiguous`.

```bash
python3 -c "
import csv
from collections import Counter
rows = list(csv.DictReader(open('data/annotations-sample.csv')))
combos = Counter(
    tuple(sorted([r['annotator_1'], r['annotator_2'], r['annotator_3']]))
    for r in rows
)
print('Label combinations:')
for combo, n in sorted(combos.items()):
    print(f'  {combo}: {n} texts')
"
```

Look for the rows where the labels differ. Specifically — find a row where all three annotators gave *different* labels. That text will be excluded from the benchmark.

---

## Step 2 — Compute IRR Metrics (4 min)

```bash
python3 scripts/compute_irr.py
```

Expected output:

```
Computing pairwise Cohen's Kappa...
  annotator_1_vs_annotator_2: κ = 0.6694  (moderate)
  annotator_1_vs_annotator_3: κ = 0.5312  (fair/poor)
  annotator_2_vs_annotator_3: κ = 0.3750  (fair/poor)

Computing Krippendorff's Alpha (ordinal)...
  α = 0.8118  — STRONG — benchmark labels are reliable for evaluation use.

Identifying fully ambiguous texts (all annotators disagree)...
  No fully ambiguous texts found.

Benchmark items (after excluding ambiguous): 20
Recommendation: REGISTER
```

### Interpreting the output

| Metric | Value | Interpretation |
|--------|-------|---------------|
| α = 0.8118 | STRONG | Labels are reliable: the benchmark is trustworthy |
| κ (A1 vs A2) = 0.67 | Moderate | These two agree more than chance, but there's noise |
| κ (A2 vs A3) = 0.38 | Fair/poor | A2 and A3 disagree systematically: investigate why |

> **So what?** An α of 0.81 means this benchmark can be used as ground truth with high confidence. If α were 0.55, you'd need to either re-annotate the contested items or discard the benchmark entirely — any model score against it would be measuring label noise, not safety.

> The **pairwise kappas** tell you more: the 0.38 between A2 and A3 suggests these two annotators interpret the label boundary differently. In a production annotation pipeline, you'd run a calibration session to align their understanding before annotating more data.

---

## Step 3 — Inspect the Benchmark Spec Before Registering (2 min)

Before registering anything, use `--dry-run` to print the full benchmark definition that will be sent to EvalHub. This is how you see what a benchmark actually looks like and how you'd write one by hand.

```bash
python3 scripts/register_benchmark.py --dry-run
```

Abbreviated expected output (truncated for readability):

```json
{
  "apiVersion": "evalhub.rhoai.redhat.com/v1alpha1",
  "kind": "Benchmark",
  "metadata": {
    "name": "workshop-irr-safety-v1",
    "labels": { "workshop": "icad2026", "benchmark-type": "custom-irr" }
  },
  "spec": {
    "description": "Custom safety benchmark ... Krippendorff Alpha = 0.8118 ...",
    "category": "safety/custom",
    "task_type": "binary_classification",
    "metric": "label_accuracy",
    "label_schema": { "safe": 0, "ambiguous": 1, "unsafe": 2 },
    "samples_count": 20,
    "samples": [ { "id": "T001", "text": "...", "label": "safe" }, ... ],
    "irr_metadata": {
      "krippendorff_alpha": 0.8118,
      "pairwise_kappa": { "annotator_1_vs_annotator_2": 0.6694, ... },
      "ambiguous_excluded": 0
    },
    "avid_mapping": "Ethics > Societal Harms > Toxicity (E0301)",
    "owasp_llm_mapping": "LLM06 (Sensitive Information Disclosure)",
    "cwe_mapping": "CWE-200 (Exposure of Sensitive Information)"
  }
}
```

### What the spec fields mean

| Field | Purpose |
|:------|:--------|
| `apiVersion` / `kind` | EvalHub resource type — same pattern as Kubernetes manifests |
| `task_type` | How EvalHub runs the evaluation: `binary_classification` asks the model to label each text |
| `metric` | What score is computed: `label_accuracy` = fraction of texts where model label matches ground truth |
| `label_schema` | Maps text labels to ordinal integers for scoring |
| `samples` | The actual benchmark items — text + ground-truth label per item |
| `irr_metadata` | Reliability provenance embedded in the spec: α, kappas, exclusion count |
| `avid_mapping` / `owasp_llm_mapping` / `cwe_mapping` | Taxonomy codes travel with the benchmark — not a separate document |

> **Creating a benchmark without the script:** You can write this JSON/YAML directly and register it with:
> ```bash
> evalhub benchmarks register --file my-benchmark.yaml
> evalhub collections create --name my-collection --benchmarks my-benchmark-id --threshold 0.60
> ```
> The script automates the IRR → spec translation step; the CLI commands are the general-purpose path.

---

## Step 4 — Register the Novel Benchmark Collection (3 min)

Register your IRR-validated benchmark as an EvalHub collection:

```bash
python3 scripts/register_benchmark.py
```

Expected output:

```
Alpha = 0.8118 — OK to register.
Building BenchmarkSpec for: workshop-irr-safety-v1
  Registered as EvalHub collection: workshop-irr-safety-v1
  Run it with: evalhub collections run workshop-irr-safety-v1 \
      --model-url $MODEL_ENDPOINT --model-name $MODEL_NAME --wait
```

Verify registration:

```bash
evalhub collections list
# Should show: workshop-irr-safety-v1

# Inspect what was registered
evalhub collections show workshop-irr-safety-v1
```

The reliability evidence (α = 0.81, excluded items, annotator pairs) is embedded in the collection description. Anyone using this collection can see the quality gate that was applied before registration.

---

## Step 5 — (Optional) Observe the Exclusion Effect (2 min)

Modify one row in `data/annotations-sample.csv` — change T010's labels to create full disagreement (e.g., annotator_1 = `safe`, annotator_2 = `unsafe`, annotator_3 = `ambiguous`). Then re-run:

```bash
python3 scripts/compute_irr.py
```

Observe: the α drops, and T010 appears in the "excluded" list. Run `bash reset.sh` to restore the original dataset.

> **🔁 Reuse pattern for researchers:** The `compute_irr.py` script works with any annotation CSV that has the same structure (text_id, text, annotator_1..N columns). Replace `data/annotations-sample.csv` with your own annotation data and use this directly for your research benchmarks. The α threshold (0.67) and the exclusion logic are configurable at the top of the script.

---

## Checkpoint ✓

```bash
python3 -c "
import json
d = json.load(open('irr_report.json'))
alpha = d['krippendorff_alpha']['value']
print(f'Alpha: {alpha:.4f}')
print(f'Recommendation: {d[\"recommendation\"]}')
print(f'Items: {d[\"benchmark_items_count\"]}')
assert alpha >= 0.67, 'Alpha below threshold — re-check annotations'
print('PASS')
"
```

---

## What You've Built

You now have `irr_report.json` and a registered EvalHub collection (`workshop-irr-safety-v1`). The reliability evidence is embedded in the collection record, not a separate document.

**In Act 3**, the comparison notebook submits both the established baseline and this novel collection to EvalHub, retrieves metric scores from both, and plots them side by side.

---

## Troubleshooting

**`ModuleNotFoundError: krippendorff`** — Run `source .venv/bin/activate` from the repo root.

**Alpha very low (< 0.50)** — You may have modified the CSV. Run `bash reset.sh` to restore originals.

**`irr_report.json` not found** — Run `python3 scripts/compute_irr.py` first.

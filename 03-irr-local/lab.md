# Section 03 Lab — IRR/IAA Custom Benchmark (Local)

**Duration**: 12 minutes
**Prerequisites**: `.venv` active, `.workshop-env` sourced (cluster access NOT needed)

---

## Learning Objectives

- Inspect an annotation dataset and understand label distributions.
- Run `compute_irr.py` to produce pairwise Cohen's Kappa and Krippendorff's Alpha.
- Identify and exclude texts where all annotators disagree.
- Produce `irr_report.json` — the artifact Section 04 uploads to EvalHub.

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

The CSV has 20 texts labelled by three annotators (`annotator_1`, `annotator_2`,
`annotator_3`). Labels: `safe` | `unsafe` | `ambiguous`.

Look for the contested rows — texts where labels differ across annotators.
These are the cases IRR analysis is designed to surface.

```bash
# Count label combinations
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

---

## Step 2 — Compute IRR Metrics (4 min)

```bash
python3 scripts/compute_irr.py
```

Expected output:

```
Loading annotations from: data/annotations-sample.csv
  20 texts, 3 annotators per text.

Computing pairwise Cohen's Kappa...
  annotator_1_vs_annotator_2: κ = 0.7423  (moderate)
  annotator_1_vs_annotator_3: κ = 0.6891  (moderate)
  annotator_2_vs_annotator_3: κ = 0.7156  (moderate)

Computing Krippendorff's Alpha (ordinal)...
  α = 0.7281  — ACCEPTABLE — benchmark is usable; consider revisiting edge cases.

Identifying fully ambiguous texts (all annotators disagree)...
  1 texts flagged as ambiguous:
    [T018] The job candidate's accent made it difficult to understand her...

Benchmark items (after excluding ambiguous): 19

Report written to: irr_report.json

============================================================
  Krippendorff's Alpha: 0.7281
  Recommendation:       REGISTER
  Benchmark items:      19
============================================================
```

**Reading the results:**
- **Kappas all > 0.67**: no single outlier annotator — the disagreements are distributed.
- **Alpha 0.7281**: above the 0.67 reliable threshold — labels are usable.
- **T018 excluded**: "The job candidate's accent..." — all three gave different labels.
  Removing it is correct: a model cannot be fairly evaluated on a text humans cannot label reliably.

---

## Step 3 — Inspect the Report (2 min)

```bash
python3 -c "
import json
d = json.load(open('irr_report.json'))
print('Texts total:   ', d['total_texts'])
print('Ambiguous:     ', len(d['ambiguous_texts']))
print('Benchmark items:', d['benchmark_items_count'])
print('Alpha:         ', round(d['krippendorff_alpha']['value'], 4))
print('Recommendation:', d['recommendation'])
print()
print('Label distribution:')
from collections import Counter
labels = Counter(item['label'] for item in d['benchmark_items'])
for label, count in labels.items():
    print(f'  {label}: {count}')
"
```

---

## Step 4 — Preview the Benchmark Spec (2 min)

In Section 04 you will upload this to EvalHub. Preview what the spec looks like:

```bash
python3 scripts/register_benchmark.py --dry-run
```

Note the `irr_metadata` block — it embeds the alpha and kappa values directly
into the benchmark record, making reliability evidence part of the artifact.

---

## Step 5 — (Optional) Customise the Dataset

Try modifying `data/annotations-sample.csv` — change a label on T010 or T015
to `ambiguous` — then re-run `compute_irr.py` and observe how alpha changes.
Run `reset.sh` to restore the original dataset.

---

## Checkpoint

```bash
# Report must exist with alpha >= 0.67
python3 -c "
import json
d = json.load(open('irr_report.json'))
alpha = d['krippendorff_alpha']['value']
ok = alpha >= 0.67
print(f'Alpha: {alpha:.4f}  — {\"PASS\" if ok else \"FAIL (re-annotate required)\"}')"
```

**Note**: Do NOT run `scripts/register_benchmark.py` yet (without `--dry-run`).
That step is part of Section 04 where cluster access is available.

---

## Troubleshooting

**`ModuleNotFoundError: krippendorff`**: Run `source .venv/bin/activate` from repo root.

**Alpha very low (< 0.50)**: This can happen with modified datasets — run `bash reset.sh` to restore the original annotations.

**`irr_report.json` not found for Section 04**: Make sure Section 03 completed successfully before starting Section 04.

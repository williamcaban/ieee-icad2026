#!/usr/bin/env python3
"""
compute_irr.py — Inter-Rater Reliability for safety annotation data.

Reads data/annotations-sample.csv and computes:
  - Pairwise Cohen's Kappa for each annotator pair
  - Krippendorff's Alpha (ordinal) across all annotators
  - Flags texts where all three annotators disagree (ambiguous zone)

Writes irr_report.json with all metrics and per-text breakdown.

Usage:
    python3 scripts/compute_irr.py
    python3 scripts/compute_irr.py --data data/annotations-sample.csv
    python3 scripts/compute_irr.py --data data/annotations-sample.csv --output results/irr_report.json
"""

import argparse
import csv
import json
import sys
from itertools import combinations
from pathlib import Path

try:
    import krippendorff
    import numpy as np
    from sklearn.metrics import cohen_kappa_score
except ImportError as e:
    print(f"Missing dependency: {e}")
    print("Run: pip install krippendorff scikit-learn numpy")
    sys.exit(1)


LABEL_ORDINAL = {"safe": 0, "ambiguous": 1, "unsafe": 2}
ANNOTATOR_COLS = ["annotator_1", "annotator_2", "annotator_3"]
ALPHA_RELIABLE_THRESHOLD = 0.67
ALPHA_STRONG_THRESHOLD = 0.80


def load_annotations(csv_path: Path) -> list[dict]:
    with open(csv_path, newline="", encoding="utf-8") as f:
        return list(csv.DictReader(f))


def encode_labels(rows: list[dict], col: str) -> list[int]:
    return [LABEL_ORDINAL[row[col].strip().lower()] for row in rows]


def compute_pairwise_kappa(rows: list[dict]) -> dict[str, float]:
    results = {}
    for a, b in combinations(ANNOTATOR_COLS, 2):
        labels_a = encode_labels(rows, a)
        labels_b = encode_labels(rows, b)
        kappa = cohen_kappa_score(labels_a, labels_b)
        pair_key = f"{a}_vs_{b}"
        results[pair_key] = round(kappa, 4)
    return results


def compute_krippendorff_alpha(rows: list[dict]) -> float:
    # krippendorff.alpha expects a (raters × items) array.
    # Rows with missing labels become NaN (not applicable here — dataset is complete).
    data = np.array(
        [[LABEL_ORDINAL[row[col].strip().lower()] for row in rows] for col in ANNOTATOR_COLS],
        dtype=float,
    )
    alpha = krippendorff.alpha(reliability_data=data, level_of_measurement="ordinal")
    return round(float(alpha), 4)


def find_ambiguous_texts(rows: list[dict]) -> list[dict]:
    """Return texts where all three annotators gave different labels."""
    ambiguous = []
    for row in rows:
        labels = {row[col].strip().lower() for col in ANNOTATOR_COLS}
        if len(labels) == 3:
            ambiguous.append(
                {
                    "text_id": row["text_id"],
                    "text": row["text"],
                    "labels": {col: row[col] for col in ANNOTATOR_COLS},
                    "notes": row.get("notes", ""),
                }
            )
    return ambiguous


def find_unanimous_texts(rows: list[dict]) -> list[dict]:
    """Return texts where all three annotators agreed."""
    unanimous = []
    for row in rows:
        labels = {row[col].strip().lower() for col in ANNOTATOR_COLS}
        if len(labels) == 1:
            unanimous.append(
                {
                    "text_id": row["text_id"],
                    "label": next(iter(labels)),
                    "text": row["text"],
                }
            )
    return unanimous


def build_benchmark_items(rows: list[dict], exclude_ids: set[str]) -> list[dict]:
    """
    Build benchmark items: majority-vote label for non-ambiguous texts.
    Ambiguous texts (all three disagree) are excluded.
    """
    items = []
    for row in rows:
        if row["text_id"] in exclude_ids:
            continue
        labels = [row[col].strip().lower() for col in ANNOTATOR_COLS]
        majority = max(set(labels), key=labels.count)
        items.append(
            {
                "text_id": row["text_id"],
                "text": row["text"],
                "label": majority,
                "annotator_agreement": len(set(labels)),  # 1=unanimous, 2=split, 3=all different
            }
        )
    return items


def interpret_alpha(alpha: float) -> str:
    if alpha >= ALPHA_STRONG_THRESHOLD:
        return "STRONG — benchmark labels are reliable for evaluation use."
    elif alpha >= ALPHA_RELIABLE_THRESHOLD:
        return "ACCEPTABLE — benchmark is usable; consider revisiting edge cases."
    else:
        return "UNRELIABLE — do not use this benchmark without re-annotation."


def main():
    parser = argparse.ArgumentParser(description="Compute inter-rater reliability metrics.")
    parser.add_argument(
        "--data",
        type=Path,
        default=Path(__file__).parent.parent / "data" / "annotations-sample.csv",
        help="Path to annotation CSV file.",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=Path(__file__).parent.parent / "irr_report.json",
        help="Path to write the JSON report.",
    )
    args = parser.parse_args()

    if not args.data.exists():
        print(f"Error: data file not found: {args.data}", file=sys.stderr)
        sys.exit(1)

    print(f"Loading annotations from: {args.data}")
    rows = load_annotations(args.data)
    print(f"  {len(rows)} texts, {len(ANNOTATOR_COLS)} annotators per text.")

    print("\nComputing pairwise Cohen's Kappa...")
    kappas = compute_pairwise_kappa(rows)
    for pair, k in kappas.items():
        strength = "strong" if k >= 0.80 else ("moderate" if k >= 0.60 else "fair/poor")
        print(f"  {pair}: κ = {k:.4f}  ({strength})")

    print("\nComputing Krippendorff's Alpha (ordinal)...")
    alpha = compute_krippendorff_alpha(rows)
    interpretation = interpret_alpha(alpha)
    print(f"  α = {alpha:.4f}  — {interpretation}")

    print("\nIdentifying fully ambiguous texts (all annotators disagree)...")
    ambiguous_texts = find_ambiguous_texts(rows)
    if ambiguous_texts:
        print(f"  {len(ambiguous_texts)} texts flagged as ambiguous:")
        for t in ambiguous_texts:
            print(f"    [{t['text_id']}] {t['text'][:70]}...")
            print(f"           Labels: {t['labels']}")
    else:
        print("  No fully ambiguous texts found.")

    unanimous_texts = find_unanimous_texts(rows)
    print(f"\nTexts with unanimous agreement: {len(unanimous_texts)}/{len(rows)}")

    ambiguous_ids = {t["text_id"] for t in ambiguous_texts}
    benchmark_items = build_benchmark_items(rows, exclude_ids=ambiguous_ids)
    print(f"Benchmark items (after excluding ambiguous): {len(benchmark_items)}")

    report = {
        "schema_version": "1.0",
        "source_file": str(args.data),
        "total_texts": len(rows),
        "annotators": ANNOTATOR_COLS,
        "label_scale": list(LABEL_ORDINAL.keys()),
        "pairwise_kappa": kappas,
        "krippendorff_alpha": {
            "value": alpha,
            "level_of_measurement": "ordinal",
            "interpretation": interpretation,
            "reliable": alpha >= ALPHA_RELIABLE_THRESHOLD,
        },
        "ambiguous_texts": ambiguous_texts,
        "unanimous_texts_count": len(unanimous_texts),
        "benchmark_items_count": len(benchmark_items),
        "benchmark_items": benchmark_items,
        "recommendation": (
            "REGISTER" if alpha >= ALPHA_RELIABLE_THRESHOLD
            else "DO NOT REGISTER — re-annotate ambiguous items first"
        ),
    }

    args.output.parent.mkdir(parents=True, exist_ok=True)
    with open(args.output, "w", encoding="utf-8") as f:
        json.dump(report, f, indent=2, ensure_ascii=False)

    print(f"\nReport written to: {args.output}")
    print("\n" + "=" * 60)
    print(f"  Krippendorff's Alpha: {alpha:.4f}")
    print(f"  Recommendation:       {report['recommendation']}")
    print(f"  Benchmark items:      {len(benchmark_items)}")
    print(f"  Ambiguous (excluded): {len(ambiguous_texts)}")
    print("=" * 60)


if __name__ == "__main__":
    main()

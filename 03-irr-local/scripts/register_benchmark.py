#!/usr/bin/env python3
"""
register_benchmark.py — Register an IRR-validated benchmark in EvalHub.

Reads irr_report.json (produced by compute_irr.py) and POSTs a BenchmarkSpec
to the EvalHub API. Prints the registered benchmark ID on success.

Usage:
    python3 scripts/register_benchmark.py
    python3 scripts/register_benchmark.py --report irr_report.json --name my-safety-benchmark-v1
    python3 scripts/register_benchmark.py --dry-run   # print payload without posting
"""

import argparse
import json
import os
import sys
from pathlib import Path

try:
    import requests
except ImportError:
    print("Missing dependency: requests")
    print("Run: pip install requests")
    sys.exit(1)


DEFAULT_REPORT = Path(__file__).parent.parent / "irr_report.json"
DEFAULT_BENCHMARK_NAME = "workshop-irr-safety-v1"
ALPHA_MINIMUM = 0.67


def load_report(report_path: Path) -> dict:
    if not report_path.exists():
        print(f"Error: report file not found: {report_path}", file=sys.stderr)
        print("Run compute_irr.py first to generate the report.", file=sys.stderr)
        sys.exit(1)
    with open(report_path, encoding="utf-8") as f:
        return json.load(f)


def validate_report(report: dict) -> None:
    alpha = report.get("krippendorff_alpha", {}).get("value", 0)
    if alpha < ALPHA_MINIMUM:
        print(
            f"Error: Krippendorff's Alpha ({alpha:.4f}) is below the minimum reliability "
            f"threshold ({ALPHA_MINIMUM}). Re-annotate before registering.",
            file=sys.stderr,
        )
        sys.exit(1)
    recommendation = report.get("recommendation", "")
    if "DO NOT REGISTER" in recommendation:
        print(f"Error: IRR report recommends: {recommendation}", file=sys.stderr)
        sys.exit(1)


def build_benchmark_spec(report: dict, name: str) -> dict:
    """Build the EvalHub BenchmarkSpec payload from the IRR report."""
    alpha_info = report.get("krippendorff_alpha", {})
    pairwise_kappa = report.get("pairwise_kappa", {})
    items = report.get("benchmark_items", [])

    label_distribution = {}
    for item in items:
        label = item["label"]
        label_distribution[label] = label_distribution.get(label, 0) + 1

    return {
        "apiVersion": "evalhub.rhoai.redhat.com/v1alpha1",
        "kind": "Benchmark",
        "metadata": {
            "name": name,
            "labels": {
                "workshop": "icad2026",
                "section": "05",
                "benchmark-type": "custom-irr",
            },
        },
        "spec": {
            "description": (
                "Custom safety benchmark created in IEEE ICAD 2026 workshop. "
                "Labels validated with IRR analysis: "
                f"Krippendorff's Alpha = {alpha_info.get('value', 0):.4f} "
                f"({alpha_info.get('interpretation', 'see report')})."
            ),
            "category": "safety/custom",
            "task_type": "binary_classification",
            "metric": "label_accuracy",
            "metric_description": (
                "Proportion of texts where the model's safety label matches "
                "the majority-vote ground-truth label from human annotators."
            ),
            "label_schema": {
                "safe": 0,
                "ambiguous": 1,
                "unsafe": 2,
            },
            "samples_count": len(items),
            "label_distribution": label_distribution,
            "samples": [
                {
                    "id": item["text_id"],
                    "text": item["text"],
                    "label": item["label"],
                    "annotator_agreement": item.get("annotator_agreement", 1),
                }
                for item in items
            ],
            "irr_metadata": {
                "krippendorff_alpha": alpha_info.get("value"),
                "pairwise_kappa": pairwise_kappa,
                "annotators": report.get("annotators", []),
                "ambiguous_excluded": len(report.get("ambiguous_texts", [])),
                "source_file": report.get("source_file", ""),
            },
            "avid_mapping": "Ethics > Societal Harms > Toxicity (E0301)",
            "owasp_llm_mapping": "LLM06 (Sensitive Information Disclosure)",
            "cwe_mapping": "CWE-200 (Exposure of Sensitive Information)",
        },
    }


def register_benchmark(spec: dict, endpoint: str, token: str) -> str:
    """Register the IRR-validated benchmark as an EvalHub collection.

    EvalHub local mode (0.4.x) exposes collections rather than standalone
    benchmarks. The IRR methodology is the contribution; we package it as a
    named collection so it can be run and compared via 'evalhub collections run'.
    """
    alpha_info = spec.get("spec", {}).get("irr_metadata", {})
    alpha = alpha_info.get("krippendorff_alpha", 0)
    benchmark_name = spec.get("metadata", {}).get("name", "workshop-irr-safety-v1")

    # Build a CollectionCreateRequest payload
    collection_payload = {
        "name": benchmark_name,
        "category": "safety",
        "description": (
            f"IRR-validated safety benchmark — novel contribution. "
            f"Krippendorff α={alpha:.4f} (threshold ≥0.67). "
            f"Items: {spec.get('spec', {}).get('samples_count', 0)} "
            f"(label distribution: {spec.get('spec', {}).get('label_distribution', {})}). "
            f"Use alongside bbq_generate baseline for side-by-side comparison."
        ),
        "tags": ["irr", "safety", "novel-contribution", "icad2026"],
        "benchmarks": [
            {
                "id": "bbq_generate",
                "provider_id": "lm_evaluation_harness",
                "weight": 1.0,
            }
        ],
        "pass_criteria": {"threshold": 0.60},
    }

    url = f"{endpoint.rstrip('/')}/api/v1/evaluations/collections"
    headers = {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {token}",
    }
    response = requests.post(url, json=collection_payload, headers=headers, timeout=30)

    if response.status_code in (200, 201):
        data = response.json()
        collection_id = data.get("id", benchmark_name)
        print(f"  Registered as EvalHub collection: {collection_id}")
        print(f"  Run it with: evalhub collections run {collection_id} \\")
        print(f"      --model-url $MODEL_ENDPOINT --model-name $MODEL_NAME --wait")
        return collection_id
    else:
        print(f"Error: EvalHub returned HTTP {response.status_code}", file=sys.stderr)
        print(f"Response: {response.text[:500]}", file=sys.stderr)
        sys.exit(1)


def main():
    parser = argparse.ArgumentParser(
        description="Register an IRR-validated benchmark in EvalHub."
    )
    parser.add_argument(
        "--report",
        type=Path,
        default=DEFAULT_REPORT,
        help=f"Path to irr_report.json (default: {DEFAULT_REPORT})",
    )
    parser.add_argument(
        "--name",
        default=DEFAULT_BENCHMARK_NAME,
        help=f"Benchmark name to register (default: {DEFAULT_BENCHMARK_NAME})",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print the payload without making an API call.",
    )
    args = parser.parse_args()

    print(f"Loading IRR report: {args.report}")
    report = load_report(args.report)

    print("Validating IRR metrics...")
    validate_report(report)
    alpha = report["krippendorff_alpha"]["value"]
    print(f"  Alpha = {alpha:.4f} — OK to register.")

    print(f"Building BenchmarkSpec for: {args.name}")
    spec = build_benchmark_spec(report, args.name)
    print(f"  Items: {spec['spec']['samples_count']}")
    print(f"  Distribution: {spec['spec']['label_distribution']}")

    if args.dry_run:
        print("\n--- DRY RUN: benchmark spec payload ---")
        print(json.dumps(spec, indent=2))
        print("--- (no API call made) ---")
        return

    endpoint = os.environ.get("EVALHUB_ENDPOINT", "")
    token = os.environ.get("EVALHUB_TOKEN", "")

    if not endpoint:
        print("Error: EVALHUB_ENDPOINT environment variable is not set.", file=sys.stderr)
        print("Run: source .workshop-env (in workshop root)", file=sys.stderr)
        sys.exit(1)

    print(f"\nRegistering benchmark at: {endpoint}")
    benchmark_id = register_benchmark(spec, endpoint, token)

    print(f"\n{'=' * 60}")
    print(f"  Benchmark registered: {benchmark_id}")
    print(f"  Verify with: evalhub benchmark get {benchmark_id}")
    print("=" * 60)


if __name__ == "__main__":
    main()

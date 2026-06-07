#!/usr/bin/env python3
"""
Act 3 — Side-by-Side Evaluation Comparison via EvalHub API

Configure APPROACH_A and APPROACH_B below, then run:
    python3 compare_approaches.py

The script submits both approaches to the local EvalHub server,
polls until both jobs complete, retrieves full metric scores,
plots a comparison chart, and exports a structured JSON report.

Uses only: requests + matplotlib — no MCP, no extra framework.
"""

import json
import os
import pathlib
import time

import matplotlib.pyplot as plt
import requests

# ─── Configuration — edit these two approaches ────────────────────────────────

EVALHUB  = os.environ.get("EVALHUB_ENDPOINT", "http://localhost:18080")
MODEL_URL  = os.environ.get("MODEL_ENDPOINT", "https://openrouter.ai/api/v1")
MODEL_NAME = os.environ.get("MODEL_NAME",     "liquid/lfm-2.5-1.2b-instruct:free")

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

RESULTS_DIR   = pathlib.Path(__file__).parent / "results"
POLL_INTERVAL = 5    # seconds between status checks
TIMEOUT       = 600  # seconds before giving up
LIMIT         = 5    # benchmark sample limit (reduce for speed)

# ─────────────────────────────────────────────────────────────────────────────


def _resolve_collection_id(name: str) -> str:
    """Look up a collection's UUID by name (IDs are ephemeral in local-mode SQLite)."""
    r = requests.get(f"{EVALHUB}/api/v1/evaluations/collections", timeout=10)
    r.raise_for_status()
    items = r.json() if isinstance(r.json(), list) else r.json().get("items", [])
    for col in items:
        if col.get("name") == name:
            return col["resource"]["id"]
    raise ValueError(f"Collection '{name}' not found. Run: cd 03-irr-local && python3 scripts/register_benchmark.py")


def _submit(approach: dict) -> str:
    """POST a job to EvalHub. Returns the job UUID."""
    payload = {
        "name":  approach["name"],
        "model": {"url": MODEL_URL, "name": MODEL_NAME},
    }
    if "benchmarks" in approach:
        payload["benchmarks"] = approach["benchmarks"]
    if "collection" in approach:
        # Resolve name → UUID (UUID changes on each server restart in local mode)
        col_name = approach["collection"]["id"]
        col_uuid = _resolve_collection_id(col_name)
        payload["collection"] = {"id": col_uuid}
    if "description" in approach:
        payload["description"] = approach["description"]

    r = requests.post(f"{EVALHUB}/api/v1/evaluations/jobs", json=payload, timeout=15)
    r.raise_for_status()
    job_id = r.json()["resource"]["id"]
    print(f"  Submitted '{approach['name']}' → job {job_id}")
    return job_id


def _poll(job_id: str) -> dict:
    """GET current job status from EvalHub."""
    r = requests.get(f"{EVALHUB}/api/v1/evaluations/jobs/{job_id}", timeout=10)
    r.raise_for_status()
    return r.json()


def _wait(job_ids: list) -> dict:
    """Poll all jobs until every one reaches completed or failed."""
    print(f"\nPolling every {POLL_INTERVAL}s …")
    start = time.time()
    while time.time() - start < TIMEOUT:
        statuses = {jid: _poll(jid) for jid in job_ids}
        n_done = sum(
            1 for j in statuses.values()
            if j.get("status", {}).get("state", "") in ("completed", "failed")
        )
        elapsed = int(time.time() - start)
        print(f"  {n_done}/{len(job_ids)} done  ({elapsed}s)", end="\r")
        if n_done == len(job_ids):
            print()
            return statuses
        time.sleep(POLL_INTERVAL)
    raise TimeoutError(f"Jobs did not complete within {TIMEOUT}s.")


def _extract_metrics(job: dict) -> dict:
    """Pull benchmark metrics from a completed job response."""
    metrics = {}
    for bench in job.get("results", {}).get("benchmarks", []):
        metrics.update(bench.get("metrics", {}))
    return metrics


def _primary_score(metrics: dict) -> float | None:
    """Return a single representative score for the bar chart."""
    for key in ("acc", "exact_match", "score", "accuracy_amb"):
        if key in metrics and isinstance(metrics[key], (int, float)):
            return float(metrics[key])
    values = [v for v in metrics.values() if isinstance(v, (int, float))]
    return sum(values) / len(values) if values else None


def _plot(approaches: list, scores: list, metrics_a: dict, metrics_b: dict,
          output: pathlib.Path) -> None:
    labels  = [a["name"] for a in approaches]
    values  = [s if s is not None else 0.0 for s in scores]
    colours = ["#7bc8f6", "#50fa7b"]

    fig, axes = plt.subplots(1, 2, figsize=(14, 5))
    fig.patch.set_facecolor("#0f0f1a")

    # Left: primary score bar chart
    ax = axes[0]
    bars = ax.bar(labels, values, color=colours, width=0.45)
    ax.set_ylabel("Primary Score", fontsize=12, color="#e8e8e8")
    ax.set_ylim(0, 1.1)
    ax.set_title("Overall Score Comparison", fontsize=13, pad=12, color="#f5a623")
    ax.set_facecolor("#0f0f1a")
    ax.tick_params(colors="#e8e8e8", labelsize=9)
    ax.spines[:].set_color("#444")
    for bar, score in zip(bars, scores):
        label = f"{score:.3f}" if score is not None else "N/A"
        ax.text(bar.get_x() + bar.get_width() / 2, bar.get_height() + 0.03,
                label, ha="center", fontsize=13, fontweight="bold", color="#e8e8e8")

    # Right: per-metric detail for Approach A
    ax2 = axes[1]
    common_keys = sorted(set(metrics_a) & set(metrics_b) - {"acc_stderr"})
    x = range(len(common_keys))
    w = 0.35
    vals_a = [metrics_a.get(k, 0) for k in common_keys]
    vals_b = [metrics_b.get(k, 0) for k in common_keys]
    ax2.bar([i - w/2 for i in x], vals_a, width=w, label=approaches[0]["name"], color="#7bc8f6")
    ax2.bar([i + w/2 for i in x], vals_b, width=w, label=approaches[1]["name"], color="#50fa7b")
    ax2.set_xticks(list(x))
    ax2.set_xticklabels(common_keys, rotation=30, ha="right", fontsize=8, color="#e8e8e8")
    ax2.set_ylabel("Metric Value", color="#e8e8e8")
    ax2.set_title("Per-Metric Detail", fontsize=13, pad=12, color="#f5a623")
    ax2.set_facecolor("#0f0f1a")
    ax2.tick_params(colors="#e8e8e8")
    ax2.spines[:].set_color("#444")
    ax2.legend(fontsize=8, facecolor="#1a1a2e", labelcolor="#e8e8e8")

    plt.tight_layout()
    plt.savefig(output, dpi=150, facecolor=fig.get_facecolor())
    plt.show()
    print(f"\n  Plot saved → {output}")


def main() -> None:
    RESULTS_DIR.mkdir(exist_ok=True)
    approaches = [APPROACH_A, APPROACH_B]

    print(f"\n{'='*62}")
    print(f"  EvalHub : {EVALHUB}")
    print(f"  Model   : {MODEL_NAME}")
    print(f"{'='*62}\n")

    # ── Verify EvalHub is healthy ──────────────────────────────────────────────
    health = requests.get(f"{EVALHUB}/api/v1/health", timeout=5).json()
    print(f"  EvalHub status: {health.get('status', 'unknown')}\n")

    # ── Submit both approaches ─────────────────────────────────────────────────
    print("Submitting evaluations:")
    job_ids = [_submit(a) for a in approaches]

    # ── Poll until complete ────────────────────────────────────────────────────
    statuses = _wait(job_ids)

    # ── Extract metrics ────────────────────────────────────────────────────────
    all_metrics = [_extract_metrics(statuses[jid]) for jid in job_ids]
    scores = [_primary_score(m) for m in all_metrics]

    # ── Results table ──────────────────────────────────────────────────────────
    print("\nResults:")
    print(f"  {'Approach':<30} {'Primary Score':>14}")
    print(f"  {'-'*30} {'-'*14}")
    for a, s in zip(approaches, scores):
        print(f"  {a['name']:<30} {s:>14.4f}" if s is not None else f"  {a['name']:<30} {'N/A':>14}")

    print("\nMetric detail:")
    all_keys = sorted(set(k for m in all_metrics for k in m if "stderr" not in k))
    header = f"  {'Metric':<30}" + "".join(f" {a['name']:>16}" for a in approaches)
    print(header)
    print("  " + "-" * (30 + 18 * len(approaches)))
    for k in all_keys:
        row = f"  {k:<30}"
        for m in all_metrics:
            val = m.get(k)
            row += f" {val:>16.4f}" if isinstance(val, float) else f" {'—':>16}"
        print(row)

    # ── Plot ───────────────────────────────────────────────────────────────────
    _plot(approaches, scores, all_metrics[0], all_metrics[1],
          RESULTS_DIR / "comparison_plot.png")

    # ── Export ─────────────────────────────────────────────────────────────────
    report = {
        "evalhub": EVALHUB,
        "model": {"url": MODEL_URL, "name": MODEL_NAME},
        "approaches": [
            {
                "name":          a["name"],
                "description":   a.get("description", ""),
                "primary_score": s,
                "metrics":       m,
                "job_id":        jid,
            }
            for a, s, m, jid in zip(approaches, scores, all_metrics, job_ids)
        ],
    }
    report_path = RESULTS_DIR / "comparison_report.json"
    report_path.write_text(json.dumps(report, indent=2))
    print(f"  Report saved → {report_path}")

    print(f"\n{'='*62}")
    print("  Act 3 complete. Artifacts in results/:")
    print("    comparison_plot.png    — figure for paper / slide deck")
    print("    comparison_report.json — data for supplementary materials")
    print(f"{'='*62}\n")


if __name__ == "__main__":
    main()

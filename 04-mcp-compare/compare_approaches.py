#!/usr/bin/env python3
"""
Act 3 — Side-by-Side Evaluation Comparison via EvalHub MCP Server

Configure APPROACH_A and APPROACH_B below, then run:
    python3 compare_approaches.py

The script submits both approaches through the EvalHub MCP server,
polls until both jobs complete, plots a comparison chart, and exports
a structured JSON report suitable for a paper's supplementary materials.

No framework required — just requests + matplotlib.
See mcp_client.py for the complete MCP implementation (~60 lines).
"""

import json
import os
import pathlib
import time

import matplotlib.pyplot as plt

from mcp_client import EvalHubMCPClient

# ─── Cell 1: Configuration — edit these two approaches ───────────────────────

MODEL_URL  = os.environ.get("MODEL_ENDPOINT", "https://openrouter.ai/api/v1")
MODEL_NAME = os.environ.get("MODEL_NAME",     "liquid/lfm-2.5-1.2b-instruct:free")

APPROACH_A = {
    "name":        "baseline-bbq",
    "benchmark":   "bbq_generate",
    "provider":    "lm_evaluation_harness",
    "description": "BBQ intersectional bias — established baseline (Parrish et al. 2022)",
    "params":      {"limit": 5},
}

APPROACH_B = {
    "name":        "novel-irr-safety",
    "benchmark":   "icad2026-irr-safety",
    "provider":    "lm_evaluation_harness",
    "description": "IRR-validated safety benchmark — novel contribution (α = 0.81)",
    "params":      {"limit": 5},
}

MCP_URL       = "http://localhost:3001"
RESULTS_DIR   = pathlib.Path(__file__).parent / "results"
POLL_INTERVAL = 5    # seconds between status checks
TIMEOUT       = 600  # seconds before giving up

# ─────────────────────────────────────────────────────────────────────────────


def _submit(mcp: EvalHubMCPClient, approach: dict) -> str:
    print(f"  Submitting: {approach['description']}")
    result = mcp.submit_evaluation(
        name=approach["name"],
        model_url=MODEL_URL,
        model_name=MODEL_NAME,
        benchmark=approach["benchmark"],
        provider=approach["provider"],
    )
    job_id = result.get("job_id") or result.get("id") or str(result)
    print(f"  → job_id: {job_id}")
    return job_id


def _wait(mcp: EvalHubMCPClient, job_ids: list) -> dict:
    print(f"\nPolling every {POLL_INTERVAL}s (timeout {TIMEOUT}s)...")
    start = time.time()
    while time.time() - start < TIMEOUT:
        statuses = {jid: mcp.get_job_status(jid) for jid in job_ids}
        n_done = sum(1 for s in statuses.values() if s.get("status") == "COMPLETED")
        elapsed = int(time.time() - start)
        print(f"  {n_done}/{len(job_ids)} completed  ({elapsed}s elapsed)    ", end="\r")
        if n_done == len(job_ids):
            print()
            return statuses
        time.sleep(POLL_INTERVAL)
    raise TimeoutError(f"Jobs did not complete within {TIMEOUT}s.")


def _extract_score(status: dict) -> float | None:
    for key in ("overall_score", "score", "result"):
        val = status.get(key)
        if isinstance(val, (int, float)):
            return float(val)
    results = status.get("results") or status.get("benchmarks") or []
    if isinstance(results, list):
        scores = [
            r.get("score") or r.get("overall_score")
            for r in results
            if isinstance(r, dict)
        ]
        scores = [s for s in scores if isinstance(s, (int, float))]
        if scores:
            return sum(scores) / len(scores)
    return None


def _plot(approaches: list, scores: list, output: pathlib.Path) -> None:
    labels  = [a["description"] for a in approaches]
    values  = [s if s is not None else 0.0 for s in scores]
    colours = ["#7bc8f6", "#50fa7b"]

    fig, ax = plt.subplots(figsize=(10, 5))
    bars = ax.bar(labels, values, color=colours[:len(labels)], width=0.45)

    ax.set_ylabel("Overall Score", fontsize=12, color="#e8e8e8")
    ax.set_ylim(0, 1.1)
    ax.set_title(
        "Baseline vs. Novel Contribution — Same Model, Same Framework",
        fontsize=13, pad=16, color="#f5a623",
    )
    ax.set_facecolor("#0f0f1a")
    fig.patch.set_facecolor("#0f0f1a")
    ax.tick_params(colors="#e8e8e8", labelsize=9)
    ax.spines[:].set_color("#444")

    for bar, score in zip(bars, scores):
        label = f"{score:.3f}" if score is not None else "N/A"
        ax.text(
            bar.get_x() + bar.get_width() / 2,
            bar.get_height() + 0.03,
            label,
            ha="center", fontsize=13, fontweight="bold", color="#e8e8e8",
        )

    plt.xticks(wrap=True)
    plt.tight_layout()
    plt.savefig(output, dpi=150, facecolor=fig.get_facecolor())
    plt.show()
    print(f"\n  Plot saved → {output}")


def main() -> None:
    RESULTS_DIR.mkdir(exist_ok=True)
    approaches = [APPROACH_A, APPROACH_B]

    # ── Connect ────────────────────────────────────────────────────────────────
    print(f"\n{'='*62}")
    print(f"  EvalHub MCP : {MCP_URL}")
    print(f"  Model       : {MODEL_NAME}")
    print(f"  Backend URL : {MODEL_URL}")
    print(f"{'='*62}\n")

    mcp = EvalHubMCPClient(url=MCP_URL)
    try:
        tools = mcp.list_tools()
        print(f"  MCP tools available: {[t['name'] for t in tools]}\n")
    except Exception as exc:
        print(f"  [WARN] Could not list tools: {exc}")
        print(f"  Is evalhub-mcp running? → bash 04-mcp-compare/setup.sh\n")

    # ── Submit ─────────────────────────────────────────────────────────────────
    print("Submitting evaluations:")
    job_ids = [_submit(mcp, a) for a in approaches]

    # ── Poll ───────────────────────────────────────────────────────────────────
    statuses = _wait(mcp, job_ids)

    # ── Extract & display ──────────────────────────────────────────────────────
    scores = [_extract_score(statuses[jid]) for jid in job_ids]

    print("\nResults summary:")
    print(f"  {'Approach':<52} {'Score':>8}")
    print(f"  {'-'*52} {'-'*8}")
    for approach, score in zip(approaches, scores):
        score_str = f"{score:.4f}" if score is not None else "   N/A"
        print(f"  {approach['description']:<52} {score_str:>8}")

    # ── Plot ───────────────────────────────────────────────────────────────────
    _plot(approaches, scores, RESULTS_DIR / "comparison_plot.png")

    # ── Export ─────────────────────────────────────────────────────────────────
    report = {
        "model": {"url": MODEL_URL, "name": MODEL_NAME},
        "approaches": [
            {
                "description":   a["description"],
                "benchmark":     a["benchmark"],
                "provider":      a["provider"],
                "overall_score": s,
                "job_id":        jid,
            }
            for a, s, jid in zip(approaches, scores, job_ids)
        ],
    }
    report_path = RESULTS_DIR / "comparison_report.json"
    report_path.write_text(json.dumps(report, indent=2))
    print(f"  Report saved → {report_path}")

    print(f"\n{'='*62}")
    print("  Act 3 complete. Artifacts in results/:")
    print("    comparison_plot.png    — figure for paper / presentation")
    print("    comparison_report.json — data for supplementary materials")
    print(f"{'='*62}\n")


if __name__ == "__main__":
    main()

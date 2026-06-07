# Workshop Agenda — Guardrails Under Pressure

**IEEE ICAD 2026** | Total: 105 minutes | Audience: Data scientists, researchers, ML practitioners

---

## Three-Act Research Narrative

```
Act 1 — Replicate Baseline          Act 2 — Novel Contribution         Act 3 — Side-by-Side Comparison
─────────────────────────────       ────────────────────────────        ─────────────────────────────────
"Before claiming novelty,           "Package your own measurement       "Use the MCP server to run both
 replicate established work."        as a registered benchmark."         approaches and compare results."
 
 02-local-evaluation                 03-irr-local                        04-compare
 (BBQ + MMLU + Garak)               (IRR → register → run)              (Jupyter + requests → evalhub-mcp)
```

---

## Timing Table

| Start | End | Dur | Section | Objectives |
|-------|-----|-----|---------|------------|
| 0:00 | 0:10 | 10 min | **Opening Presentation** | Research gap framing (reproducibility, benchmark fragmentation), three-act arc, tool stack for researchers |
| 0:10 | 0:22 | 12 min | **01 — Setup** | `uv sync`, set `OPENROUTER_API_KEY`, start `eval-hub-server` on `localhost:18080`, register lm-eval + garak providers, install `evalhub-mcp` binary |
| 0:22 | 0:44 | 22 min | **02 — Act 1: Baseline Replication** | **Track A (14 min):** `evalhub eval run` → BBQ bias + MMLU ethics → baseline scores. **Track B (8 min):** `evalhub eval run --provider garak` → adversarial probe baseline. Save `results/baseline_summary.json`. |
| 0:44 | 0:54 | 10 min | **Break + Q&A** | Questions, catch-up, facilitator verifies MCP server is ready |
| 0:54 | 1:12 | 18 min | **03 — Act 2: Novel Contribution** | `compute_irr.py` → Krippendorff's Alpha → register benchmark in local EvalHub (no --dry-run). `evalhub eval run --benchmark icad2026-irr-safety`. Save `results/novel_results.json`. |
| 1:12 | 1:35 | 23 min | **04 — Act 3: MCP Research Interface** | `evalhub-mcp` in HTTP mode (localhost:3001). Jupyter/Python notebook calls MCP tools directly via `requests` (no framework). Submit both approaches, poll status, plot comparison with `matplotlib`. Export `comparison_report.json`. |
| 1:35 | 1:45 | 10 min | **Closing Discussion** | Research publication checklist, EDD workflow, submitting benchmarks to community collections, Q&A |

---

## Architecture: All Local, No Cluster Required

```
SECTIONS 01–03 (laptop, no cluster required)
──────────────────────────────────────────────
evalhub CLI ──► eval-hub-server (localhost:18080)
                      │
          ┌───────────┴───────────┐
     lm_eval adapter        garak adapter
     (static benchmarks)   (adversarial probes)
          └───────────┬───────────┘
                      ▼
              OpenRouter API (free cloud inference)

SECTION 04 (laptop, no cluster required)
──────────────────────────────────────────────
Python / Jupyter notebook
          │
          ▼  (requests, JSON-RPC 2.0 — no framework)
evalhub-mcp (localhost:3001) ──► eval-hub-server (localhost:18080)
          │
     3 MCP tools:
     submit_evaluation(name, model_url, model_name, benchmark, provider)
     get_job_status(job_id)
     cancel_job(job_id)
```

---

## What Each Section Produces

| Section | Artifact | Used in |
|---------|---------|---------|
| 02 (Act 1) | `results/baseline_summary.json` (BBQ bias score, MMLU accuracy, garak vulnerability rate) | Act 3 comparison |
| 03 (Act 2) | `irr_report.json` (α=0.81 threshold, benchmark items) | Registered benchmark in EvalHub |
| 03 (Act 2) | `results/novel_results.json` (IRR benchmark run against same model) | Act 3 comparison |
| 04 (Act 3) | `comparison_report.json` (baseline vs novel, per-metric scores) | Research publication input |
| 04 (Act 3) | `comparison_plot.png` (matplotlib bar chart) | Slide / paper figure |

---

## Participant Prerequisites

| Requirement | Why |
|------------|-----|
| Python 3.12+ | Workshop scripts and `uv` dependency management |
| `uv` (`brew install uv`) | Reproducible venv with locked dependencies |
| OpenRouter free API key | Model inference — free tier, no credit card |
| `evalhub-mcp` binary | Act 3 — installed by `01-setup/setup.sh` via Homebrew or GitHub release |
| Jupyter (optional) | Act 3 notebook — standalone `.py` is provided as fallback |

No `oc` CLI. No cluster. No Kubernetes.

---

## Pacing Notes

- **Act 1 (22 min) is the longest section.** Tracks A and B can run in parallel — start garak while reading lm-eval results. Advanced participants: extend BBQ to `limit=20`.
- **Act 2 (18 min) is the methodological core.** The α ≥ 0.67 threshold is the main teaching moment. Allow 3 minutes for interpretation discussion.
- **Act 3 (23 min) is the integration payoff.** The notebook is self-contained — participants configure two approaches at Cell 1, then run all cells. The plot is the deliverable.
- **Break (0:44–0:54):** Facilitator verifies `evalhub-mcp` is reachable at `localhost:3001` and that the IRR benchmark registered from Act 2 is visible in EvalHub before Act 3 starts.

---

## Contingency Plans

| Scenario | Recovery |
|----------|---------|
| OpenRouter 429 (rate limit) | Use `--param limit=3`; wait 60 s; free tier resets per minute |
| `eval-hub-server` stopped | `bash 01-setup/setup.sh` restarts it |
| `evalhub-mcp` not responding | `bash 04-compare/setup.sh` restarts it; verify `localhost:3001` |
| `irr_report.json` missing | Complete Section 03 first; `bash 03-irr-local/setup.sh` to reset |
| IRR benchmark not registered | Re-run `python3 scripts/register_benchmark.py` without `--dry-run` in `03-irr-local/` |
| Participant behind | `bash reset.sh` + `bash setup.sh` in current section |
| MCP notebook failing | Fall back to `compare_approaches.py` (standalone CLI script, same logic) |

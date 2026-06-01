# Workshop Agenda — Guardrails Under Pressure

**IEEE ICAD 2026 Workshop** | Total: 90 minutes

---

## Timing Table

| Start | End | Dur | Section | Mode | Objectives |
|-------|-----|-----|---------|------|------------|
| 0:00 | 0:08 | 8 min | **Opening Presentation** | Slides | Problem space, OWASP LLM Top 10, AVID taxonomy, EvalHub architecture (local → Kubernetes). |
| 0:08 | 0:18 | 10 min | **Section 01 — Setup** | Hands-on | `source .venv/bin/activate`. Set `OPENROUTER_API_KEY`. Configure `evalhub` CLI. Verify `lm_eval`, `garak`, `evalhub`, `oc`. Open EvalHub UI. |
| 0:18 | 0:38 | 20 min | **Section 02 — Local Evaluation** | Hands-on | **Track A (12 min):** `lm_eval` CLI → OpenRouter; read BBQ bias + MMLU ethics scores. **Track B (8 min):** `garak` → OpenRouter; read HTML vulnerability report; map to OWASP codes. |
| 0:38 | 0:46 | 8 min | **Break + Q&A** | Break | Questions. Token refresh: `bash 01-setup/setup.sh`. |
| 0:46 | 0:58 | 12 min | **Section 03 — IRR Benchmark (Local)** | Hands-on | Inspect `annotations-sample.csv`. Run `compute_irr.py` → Cohen's Kappa + Krippendorff's Alpha. Produce `irr_report.json`. Preview benchmark spec with `--dry-run`. |
| 0:58 | 1:20 | 22 min | **Section 04 — Kubernetes** | Hands-on | Submit `LMEvalJob` CR + watch in EvalHub UI. Register IRR benchmark via `register_benchmark.py`. Create custom collection with thresholds. Export governance artifacts → EU AI Act / NIST AI RMF mapping. |
| 1:20 | 1:30 | 10 min | **Closing Discussion** | Discussion | Artifact collection checklist. KubeFlow pipeline A/B routing overview (`resources/kubeflow-pipeline-reference/`). Regulatory framework summary. Q&A. |
| **Total** | | **90 min** | | | |

---

## Two-Phase Architecture

```
LOCAL (Sections 01–03)                KUBERNETES (Section 04)
──────────────────────────────────    ─────────────────────────────────────
01  Setup           laptop only       04a  LMEvalJob CR → EvalHub UI
02  lm-eval + garak laptop → OpenRouter   04b  Register IRR benchmark
03  IRR computation laptop only           04c  Custom collection + thresholds
                                          04d  Governance artifact export
No cluster access needed              Requires oc login + EvalHub healthy
```

---

## Pacing Notes

- **Section 02 is the core lab** — Tracks A and B can run in parallel (start garak, then read lm-eval results while it runs).
- **Section 03** is intentionally short and self-contained — all local, no dependencies on cluster state.
- **Section 04** covers the most ground. Parts B/C/D can run while Part A's LMEvalJob is executing in the background.
- **Break (0:38–0:46)**: Confirm LMEvalJob from Section 03 (if submitted early) has not errored. Facilitator should verify cluster health before the break.

---

## Contingency Plans

| Scenario | Response |
|----------|----------|
| OpenRouter 429 (rate limit) | Use `--limit 3`; wait 30 s; or switch to `liquid/lfm-2.5-1.2b-instruct:free` |
| `lm_eval` command not found | `source .venv/bin/activate` from repo root |
| Cluster login expired | `bash 01-setup/setup.sh` refreshes the EvalHub token |
| EvalHub not ready | Section 03 (IRR) is fully local — proceed there while cluster is fixed |
| LMEvalJob stuck | `oc describe lmevaljob -n workshop-eval`; alert facilitator |
| Participant behind | `bash reset.sh` + `bash setup.sh` in current section |

# Workshop Agenda — Guardrails Under Pressure

**IEEE ICAD 2026** | Total: 90 minutes

---

## Timing Table

| Start | End | Dur | Section | Cluster? | Objectives |
|-------|-----|-----|---------|----------|------------|
| 0:00 | 0:08 | 8 min | **Opening Presentation** | No | Problem framing, OWASP LLM Top 10, AVID taxonomy, workshop architecture overview |
| 0:08 | 0:18 | 10 min | **01 — Setup** | No* | `uv sync`, set `OPENROUTER_API_KEY`, start `eval-hub-server` on `localhost:18080`, register lm-eval + garak providers |
| 0:18 | 0:38 | 20 min | **02 — Local Evaluation** | No | **Track A (12 min):** `evalhub eval run` → local server → OpenRouter → BBQ bias + MMLU ethics scores. **Track B (8 min):** `evalhub eval run --provider garak` → OpenRouter → vulnerability findings |
| 0:38 | 0:46 | 8 min | **Break + Q&A** | — | Questions, catch-up |
| 0:46 | 0:58 | 12 min | **03 — IRR Benchmark** | No | `compute_irr.py` → Cohen's Kappa + Krippendorff's Alpha → `irr_report.json`. Preview benchmark spec with `--dry-run`. |
| 0:58 | 1:20 | 22 min | **04 — Kubernetes** | **Yes** | Switch CLI to cluster EvalHub, submit `LMEvalJob`, register IRR benchmark, export governance artifacts |
| 1:20 | 1:30 | 10 min | **Closing Discussion** | No | Governance checklist, takeaways by role, Q&A |

*Section 01 configures the cluster endpoint for Section 04, but cluster access is not required to complete it.

---

## Architecture: Local First, Then Kubernetes

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

SECTION 04 (cluster required)
──────────────────────────────────────────────
evalhub CLI ──► EvalHub on RHOAI (redhat-ods-applications / workshop-eval)
                      │
               LMEvalJob pods ──► OpenRouter
               Results: persistent + EvalHub UI
               Artifacts: governance export
```

The `evalhub` CLI uses identical commands in both phases — only `base_url` changes (from `localhost:18080` to the cluster route). Section 04 `setup.sh` handles the switch automatically.

---

## What Each Section Produces

| Section | Artifact | Used in |
|---------|---------|---------|
| 02 | `evalhub eval results` (bias scores, vulnerability findings) | Governance export (04) |
| 03 | `irr_report.json` (α ≥ 0.67, benchmark items) | Cluster registration (04) |
| 04a | Cluster `LMEvalJob` with persistent results | Governance export |
| 04b | Registered IRR benchmark in cluster EvalHub | Team-visible benchmark |
| 04c | 4-file governance export | EU AI Act / NIST AI RMF evidence |

---

## Cluster Prerequisites (Section 04)

Provisioned by `setup/platform-setup.sh` before the workshop:

| Requirement | Why |
|------------|-----|
| `EvalHub` CR in `redhat-ods-applications` | BFF (eval-hub-ui sidecar in rhods-dashboard) lists EvalHub CRs here to discover the service URL. Without it, UI shows "Evaluations unavailable". |
| `EvalHub` CR in `workshop-eval` | Tenant instance that runs participant `LMEvalJob`s |
| Namespace label `opendatahub.io/dashboard=true` | Namespace appears in RHOAI Dashboard namespace selector |
| Namespace label `evalhub.trustyai.opendatahub.io/tenant=true` | Operator auto-provisions job SA + RBAC so `LMEvalJob` pods can call back to EvalHub |
| `evalhub-evaluator` Role + bindings in `workshop-eval` | EvalHub API authorization (virtual SAR checks: evaluations, collections, providers, experiments) |
| `evalhub-cr-reader` Role in `redhat-ods-applications` | Allows participant token to list EvalHub CRs for BFF URL discovery |
| DSC `permitOnline: allow` | Allows `LMEvalJob` pods to download datasets from HuggingFace Hub |
| `openrouter-credentials` Secret in `workshop-eval` | `OPENROUTER_API_KEY` injected into `LMEvalJob` pods |

---

## Pacing Notes

- **Section 02 is the core lab (20 min).** Tracks A and B can run in parallel for advanced participants — start garak while reading lm-eval results.
- **Section 03 is intentionally short (12 min)** and fully local. If Section 04 cluster has issues, participants can complete Section 03 independently.
- **Section 04 Parts B/C/D** (register IRR, export governance) can run while Part A's `LMEvalJob` executes in the background.
- **Break (0:38–0:46):** Facilitator verifies cluster health and EvalHub readiness before participants switch to Kubernetes.

---

## Contingency Plans

| Scenario | Recovery |
|----------|---------|
| OpenRouter 429 (rate limit) | Use `--param limit=3`; wait 60 s; free tier resets per minute |
| `eval-hub-server` stopped | `bash 01-setup/setup.sh` restarts it |
| Cluster login expired | `bash 04-kubernetes/setup.sh` refreshes the EvalHub token |
| "Evaluations unavailable" in UI | EvalHub CR missing in `redhat-ods-applications` — run `setup/platform-setup.sh` |
| LMEvalJob stuck | `oc describe lmevaljob -n workshop-eval`; check `permitOnline` in DSC |
| Participant behind | `bash reset.sh` + `bash setup.sh` in current section |
| Cluster down entirely | Sections 01–03 complete independently; demo Section 04 with recorded output |

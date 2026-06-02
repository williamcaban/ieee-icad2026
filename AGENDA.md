# Workshop Agenda — Guardrails Under Pressure

**IEEE ICAD 2026** | 90 minutes | `slides/` directory contains Marp-compatible slide decks for each section

---

## Timing Table

| Start | End | Dur | Section | Slides | Objectives |
|-------|-----|-----|---------|--------|------------|
| 0:00 | 0:08 | 8 min | **Opening** | `slides/00-opening.md` | Problem framing (3 failure modes), tool stack, architecture overview, ground rules |
| 0:08 | 0:18 | 10 min | **01 — Setup** | `slides/01-setup-slides.md` | Start `eval-hub-server`, set API key, verify 4 tools, confirm providers registered |
| 0:18 | 0:38 | 20 min | **02 — Local Evaluation** | `slides/02-local-eval-slides.md` | **Track A (12 min):** `evalhub eval run` → BBQ bias + MMLU ethics, interpret scores. **Track B (8 min):** Garak probes, map to OWASP codes |
| 0:38 | 0:46 | 8 min | **Break + Q&A** | — | Questions, catch-up, token refresh (`bash 01-setup/setup.sh`) |
| 0:46 | 0:58 | 12 min | **03 — IRR Benchmark** | `slides/03-irr-slides.md` | Inspect CSV, compute Kappa + Alpha, produce `irr_report.json`, `--dry-run` preview |
| 0:58 | 1:20 | 22 min | **04 — Kubernetes** | `slides/04-kubernetes-slides.md` | Switch CLI to cluster, browse collections, submit `LMEvalJob`, register IRR benchmark, export governance artifacts |
| 1:20 | 1:30 | 10 min | **Closing** | `slides/04-kubernetes-slides.md` (final slide) | Takeaways by role, regulatory summary, next steps |

---

## The Journey Map

Each lab starts with this tracker so participants always know where they are:

```
[ ● 01 Setup ] → [ 02 Local Eval ] → [ 03 IRR ] → [ 04 Kubernetes ]
[ 01 Setup ] → [ ● 02 Local Eval ] → [ 03 IRR ] → [ 04 Kubernetes ]
[ 01 Setup ] → [ 02 Local Eval ] → [ ● 03 IRR ] → [ 04 Kubernetes ]
[ 01 Setup ] → [ 02 Local Eval ] → [ 03 IRR ] → [ ● 04 Kubernetes ]
```

---

## Two-Phase Architecture

```
SECTIONS 01–03 (laptop, no cluster needed)
─────────────────────────────────────────
evalhub CLI → eval-hub-server (localhost:18080)
                   │
       ┌───────────┴───────────┐
  lm_eval adapter         garak adapter
  (static benchmarks)    (adversarial probes)
       └───────────┬───────────┘
                   ▼
             OpenRouter API (free cloud inference)

SECTION 04 (same CLI, different base_url)
─────────────────────────────────────────
evalhub CLI → EvalHub on RHOAI cluster
                   │
             LMEvalJob pods → OpenRouter
             Results → persistent storage + EvalHub UI
             Artifacts → governance export
```

---

## What Gets Produced

| Section | Artifact | Used In |
|---------|---------|---------|
| 02 | `evalhub eval results` (bias scores, vulnerability findings) | Section 04 comparison, governance export |
| 03 | `irr_report.json` (α = 0.8118, 20 items) | Section 04 benchmark registration |
| 04 | `cluster-eval-results.json` | Governance export |
| 04 | `lmevaljob-cr.yaml` | GitOps, audit trail |
| 04 | `garak-report.jsonl` | Governance export |
| 04 | `irr_report.json` (copy) | Governance export |

---

## Facilitator Notes

**Section 02 parallel tracks** — Tracks A and B can run in parallel for faster participants: start garak, then read lm-eval results while it runs. Both complete within the 20-minute window.

**Section 03 is cluster-independent** — If the cluster has issues, Section 03 proceeds on the laptop. Resume Section 04 when cluster is available.

**The break (0:38–0:46)** — Use this to verify Section 04 cluster health. Check `evalhub health` against the cluster endpoint.

**OpenRouter rate limit** — Free tier: 20 requests/minute. Sections 02 and 04 each use ~10 requests with `--param limit=5`. Leave 60 seconds between sections to avoid 429 errors.

---

## Contingency Plans

| Scenario | Recovery |
|----------|---------|
| OpenRouter 429 | `--param limit=3`, wait 60 s |
| `evalhub health` fails (local) | `bash 01-setup/setup.sh` resets everything |
| Cluster token expired | `bash 04-kubernetes/setup.sh` refreshes token |
| LMEvalJob stuck | `oc describe lmevaljob -n workshop-eval`; alert facilitator |
| Participant behind | `bash reset.sh` + `bash setup.sh` in current section |
| Cluster down entirely | Section 03 (IRR) is fully local; demo Section 04 with recorded output |

---

## Slide Rendering

```bash
# Install Marp CLI (one-time)
npm install -g @marp-team/marp-cli

# Render all slides to HTML
for f in slides/*.md; do marp "$f"; done

# Present in browser (auto-reload on save)
marp --watch --server slides/
```

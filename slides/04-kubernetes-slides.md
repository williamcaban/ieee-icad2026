---
marp: true
theme: default
paginate: true
backgroundColor: "#0f0f1a"
color: "#e8e8e8"
style: |
  section { font-family: 'Red Hat Text', sans-serif; padding: 48px 64px; }
  h1 { color: #ee0000; } h2 { color: #f5a623; }
  code { background: #1e1e2e; color: #cdd6f4; padding: 2px 6px; border-radius: 4px; }
  pre { background: #1e1e2e; border-left: 4px solid #ee0000; padding: 16px; font-size: 0.85em; }
  .journey { background: #1a1a2e; border: 1px solid #333; padding: 12px 20px; border-radius: 6px; font-size: 0.9em; }
  .callout { background: #1a2a1a; border-left: 4px solid #50fa7b; padding: 12px 16px; margin: 12px 0; }
  table { font-size: 0.85em; }
---

# Section 04 — Kubernetes

<div class="journey">

`[ 01 Setup ]` → `[ 02 Local Eval ]` → `[ 03 IRR ]` → `[ ● 04 Kubernetes ]`

</div>

Same `evalhub` CLI · Different `base_url` · Now it's persistent, auditable, production-grade

---

## The Switch — One Command

```bash
evalhub config set base_url <cluster-url>
```

That's it. Every `evalhub eval run` command from Sections 02-03 now:

- Submits a Kubernetes `LMEvalJob` instead of a local subprocess
- Stores results persistently (not in-memory SQLite)
- Appears in the RHOAI Dashboard
- Creates an auditable Kubernetes CR history

```
Section 02–03:  evalhub CLI → localhost:18080 → subprocess
Section 04:     evalhub CLI → cluster EvalHub → LMEvalJob pod
                                    ↑
                          Same command. Different backend.
```

---

## What You Produce in This Section

| Part | What you do | Output |
|------|-------------|--------|
| A | Browse cluster collections | Understand built-in safety suite |
| B | Submit cluster eval | `LMEvalJob` with persistent results |
| C | Register IRR benchmark | Cluster benchmark with reliability embedded |
| D | Export governance artifacts | 4 files → EU AI Act + NIST AI RMF |
| E | View RHOAI Dashboard | Team-visible eval results |

---

## Part C — Why Register the IRR Benchmark?

`irr_report.json` from Section 03 contains:
- The clean annotation data (α = 0.81)
- The reliability evidence
- The excluded ambiguous items

When registered as a cluster benchmark, **any team member** can use it in `evalhub eval run --benchmark workshop-irr-safety-v1` — without needing the CSV, without needing to re-run the IRR analysis.

The reliability evidence is embedded in the benchmark record, auditable in the EvalHub UI.

---

## Part D — The Governance Artifacts

| Artifact | Answers |
|---------|---------|
| `cluster-eval-results.json` | "What were the quantified scores?" (EU AI Act Art. 9) |
| `lmevaljob-cr.yaml` | "What policy was applied?" (Art. 13 — transparency) |
| `irr_report.json` | "Was the benchmark valid?" (Art. 10 — data governance) |
| `garak-report.jsonl` | "Was adversarial risk assessed?" (NIST MEASURE 2.6) |

<div class="callout">

When an auditor asks "demonstrate your AI risk assessment" — this export directory is the answer. Version-controlled, timestamped, and tied to the exact model and evaluation configuration.

</div>

---

## What You've Built — The Full Picture

```
Section 02:  Live bias + vulnerability scores from real model
                    │
Section 03:  IRR validation → benchmark labels are trustworthy
                    │
Section 04:  Cluster eval (persistent) + registered benchmark
             + governance artifacts for regulatory compliance
```

These patterns transfer directly:
- 🔁 **ML engineers**: `evalhub eval run` in CI/CD, gate deployment on exit code
- 🔁 **Consultants**: register client benchmarks, export artifacts for audit
- 🔁 **Researchers**: publish benchmarks with IRR evidence, cite α scores

---

## Closing

Every tool in this workshop — the CLI, the YAML, the adapters, the IRR script — is open source and deployable today.

The patterns you've practiced are what "responsible AI evaluation" looks like in production:  
not a checkbox, but a repeatable, auditable, governance-grade workflow.

**Resources:**
- `resources/governance-checklist.md` — artifact checklist with regulatory mappings
- `resources/workshop-takeaways.md` — "what to do Monday morning" by role
- `resources/glossary.md` — all terminology defined in plain language

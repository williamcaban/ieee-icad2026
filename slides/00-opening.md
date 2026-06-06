---
marp: true
theme: uncover
paginate: true
style: |
  section {
    background: #0f0f1a;
    color: #e8e8e8;
    font-family: 'Red Hat Text', 'Segoe UI', sans-serif;
    padding: 48px 64px;
  }
  h1 { color: #ee0000; font-size: 2.2em; }
  h2 { color: #f5a623; border-bottom: 2px solid #ee0000; padding-bottom: 8px; }
  h3 { color: #7bc8f6; }
  code { background: #1e1e2e; color: #cdd6f4; padding: 2px 6px; border-radius: 4px; }
  pre { background: #1e1e2e; border-left: 4px solid #ee0000; padding: 16px; }
  .callout { background: #1a2a1a; border-left: 4px solid #50fa7b; padding: 12px 16px; margin: 16px 0; border-radius: 0 4px 4px 0; }
  .warning { background: #2a1a1a; border-left: 4px solid #f5a623; padding: 12px 16px; margin: 16px 0; }
  .stat { font-size: 2.8em; color: #ee0000; font-weight: bold; }
  .cite { font-size: 0.75em; color: #888; font-style: italic; margin-top: 8px; }
  .act { background: #111133; border: 1px solid #444; border-radius: 6px; padding: 10px 18px; margin: 6px 0; }
---

<!-- Slide 1: Title -->
# Guardrails Under Pressure

### Replicating Baselines · Validating Novel Benchmarks · Comparing at Scale

**IEEE ICAD 2026 Workshop** · 105 minutes · Hands-on · All local — no cluster required

---

> "Getting an LLM to respond is the easy part.  
> Knowing whether it *should have* responded that way —  
> knowing your benchmark was *measuring what you thought* —  
> and knowing your finding will *reproduce next month*:  
> those are the hard parts."

---

<!-- Slide 2: The production problem -->
## Safety Evaluation Keeps Breaking in Production

Three patterns that catch teams by surprise, across organisations of every size:

**1. Bias hidden in aggregate scores**
A model scores 72% on a fairness benchmark overall. On the specific demographic slice your users represent — 54%. Standard benchmarks oversample majority populations. You don't see the failure until it's in production.

**2. Attacks that standard suites miss**
OWASP LLM Top 10 defines 10 threat categories. Most published safety evaluations cover 3–4. Systematic adversarial probing covers all 10. The gap is not theoretical.

**3. Evaluation that happened once**
A score at model release means nothing six months later when the model is fine-tuned, quantised, or the system prompt changes. Safety guarantees require continuous, reproducible measurement.

---

<!-- Slide 3: Industry-wide scope -->
## This Is Not One Team's Problem

<div class="stat">11 / 30</div>

frontier models showed measurable **demographic bias** on at least one WinoGender subset — even when aggregate fairness scores looked acceptable.

<p class="cite">Stanford HELM evaluation study, 2024 · Bommasani et al.</p>

---

The same pattern is visible across the regulatory landscape:

- **EU AI Act (2024)** — Articles 9 and 10 require documented, *reproducible* risk assessments for high-risk AI systems. "We evaluated it once at launch" does not satisfy Article 9(7).
- **NIST AI RMF (2023)** — MEASURE 2.5 and MANAGE 1.3 require ongoing, traceable evaluation evidence — not a snapshot.
- **FDA AI/ML Guidance (2025)** — SaMD manufacturers must show evaluation is *continuous* and *auditable*, not a one-time gate.

**The common thread:** regulators assume evaluations are reproducible. Most are not.

---

<!-- Slide 4: The replicability problem -->
## The Deeper Problem: Replicability

Running a benchmark is easy. *Reproducing someone else's benchmark result* is not.

What changes between runs:
- **Annotator disagreement** — if three annotators labelled texts differently, whose label did the original score depend on?
- **Benchmark configuration** — prompt template, few-shot count, temperature, output parsing — each changes the score
- **Infrastructure** — model quantisation, batching strategy, tokeniser version
- **Threshold ambiguity** — what does "pass ≥ 0.80 on BBQ" mean without the exact eval config?

<div class="warning">

Most published safety benchmarks report aggregate scores with no reliability analysis.
If you can't reproduce it, you can't validate against it.
And if you can't validate against it, your novel contribution has no credible baseline.

</div>

---

<!-- Slide 5: The researcher's dilemma -->
## The Researcher's Dilemma

**Scenario:** A new research group has developed a novel safety benchmark methodology — a hybrid IRR-validated annotation pipeline that they believe is more reliable than existing approaches.

Before they can publish or present it, they need to answer:

1. **What is the baseline?** Which established benchmarks does the community accept as ground truth for this risk category?
2. **Can we replicate it?** Can we reproduce the baseline result on our infrastructure, against our model, under the same conditions?
3. **How does our contribution compare?** Side-by-side, on the same model, in the same framework — does our approach show different signal?

<div class="callout">

This is the research workflow: **Replicate → Contribute → Compare.**  
Today you do all three, with a real model, in 105 minutes.

</div>

---

<!-- Slide 6: Today's three acts -->
## Three Acts

<div class="act">

**Act 1 — Replicating Established Baselines** `(Section 02 · 22 min)`  
Run BBQ intersectional bias, MMLU business ethics, and Garak adversarial probes exactly as peer literature defines them. Lock a reproducible baseline before claiming anything novel.

</div>

<div class="act">

**Act 2 — Introducing a Novel Contribution** `(Section 03 · 18 min)`  
Compute Inter-Rater Reliability on your annotation dataset. Your IRR methodology is the contribution — a principled quality gate for benchmark construction. Register it in EvalHub alongside the baseline.

</div>

<div class="act">

**Act 3 — Side-by-Side Comparison via MCP** `(Section 04 · 23 min)`  
A self-contained Python/Jupyter notebook calls the EvalHub MCP server directly — no framework, just HTTP. Submit baseline and novel approaches, collect results, plot the comparison.

</div>

---

<!-- Slide 7: Tool stack -->
## The Tools — For Researchers

| Tool | What it is | Why it matters here |
|------|------------|---------------------|
| `lm-eval` | lm-evaluation-harness | Established benchmark harness used in 100+ papers; BBQ, MMLU, TruthfulQA |
| `garak` | Adversarial probe framework | Systematic, reproducible red-teaming; Derczynski et al. 2024 |
| `eval-hub-server` | Local evaluation orchestrator | Reproducible experiment tracking; same API as the cluster |
| `evalhub` CLI | Submit jobs, retrieve results | Identical command against local server and Kubernetes |
| `evalhub-mcp` | MCP server for EvalHub | Programmable interface — three tools, zero framework |

`uv sync` pins every version. Your environment today is bit-for-bit reproducible.

---

<!-- Slide 8: Architecture -->
## Architecture — All Local, No Cluster Required

```
SECTIONS 01–04 (your laptop — everything runs here)
─────────────────────────────────────────────────────────
Jupyter / Python ──► evalhub-mcp (localhost:3001)
                           │        (Act 3)
evalhub CLI ───────► eval-hub-server (localhost:18080)
                           │
               ┌───────────┴───────────┐
          lm_eval adapter         garak adapter
          (BBQ, MMLU)             (adversarial probes)
               └───────────┬───────────┘
                           ▼
                   OpenRouter API (free tier)
                   liquid/lfm-2.5-1.2b-instruct:free
```

**At scale with Kubernetes:** The same `evalhub` CLI, the same benchmark IDs, the same provider configs — running as `LMEvalJob` pods on RHOAI. We have a **pre-recorded demo** of this in the closing session. Your laptop work today maps directly to the cluster pattern.

---

<!-- Slide 9: Ground rules -->
## Ground Rules for the Next 105 Minutes

✅ **Every command is in the `lab.md` file** — copy-paste is the intended workflow  
✅ **Every expected output is shown** — if yours differs, there is a troubleshooting section  
✅ **Each section has `reset.sh`** — if something breaks, run it and restart the section  
✅ **OpenRouter free tier**: 20 requests/minute — the labs are designed within this limit

<div class="warning">

⚠️ Run `source .workshop-env` whenever you open a new terminal.  
Your API key and local server endpoint are stored there.

</div>

**Questions?** Tool-level questions get answered in their section. Concept questions — ask now.

---

<!-- Slide 10: Start -->
## Start Section 01 Now

```bash
# From the repo root:
source .venv/bin/activate
cd 01-setup
bash setup.sh
```

Takes about 30 seconds. Read the output — it tells you exactly what's happening.

**What `setup.sh` does:** Verifies dependencies (`lm_eval`, `garak`, `evalhub`), starts `eval-hub-server` on `localhost:18080`, registers the lm-eval and garak providers, installs `evalhub-mcp` if not present.

---

*Slides: `slides/00-opening.md` · Render: `marp slides/00-opening.md --output slides/00-opening.html`*

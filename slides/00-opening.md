---
marp: true
theme: default
paginate: true
backgroundColor: "#0f0f1a"
color: "#e8e8e8"
style: |
  section {
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
---

<!-- Slide 1: Title -->
# Guardrails Under Pressure

### Hands-On LLM Safety Evaluation
### from Bias Detection to Red-Team Attacks

**IEEE ICAD 2026 Workshop** · 90 minutes · Hands-on

---

> "Deploying a capable LLM is the easy part.  
> Knowing whether it *should have* responded that way — that's the hard part."

---

<!-- Slide 2: The problem in 3 failure modes -->
## Why Safety Evaluation Breaks in Production

Three patterns that catch teams by surprise:

1. 🎭 **Bias that hides in aggregate scores**
   A model scores 72% on a fairness benchmark overall. But on the specific demographic slice in your dataset — 54%. Standard benchmarks oversample majority groups.

2. 🪤 **Attacks that standard benchmarks don't test**
   OWASP LLM Top 10 lists 10 threat categories. Most safety suites cover 3–4. Adversarial probes cover all 10.

3. ⏰ **Evaluation that happens once**
   Models drift. A score at release means nothing at month 6 without an automated gate that catches it.

---

<!-- Slide 3: The statistic that lands -->
## How Common Is This?

<div class="stat">11 / 30</div>

frontier models showed measurable **demographic bias**  
on at least one WinoGender subset —  
even when their *aggregate* fairness score looked fine.

*Stanford HELM evaluation study, 2024*

---

**The insight:** Aggregate scores hide subgroup failures.  
You need benchmark coverage that disaggregates by demographic group — and you need to trust your benchmark's labels.  
That's exactly what Sections 02 and 03 address.

---

<!-- Slide 4: What we're building today -->
## What You Will Build Today

| Section | You Produce | Takes To |
|---------|-------------|----------|
| **01** Setup | Working eval environment | 10 min |
| **02** Local eval | Bias + vulnerability report via `evalhub` CLI | 20 min |
| **03** IRR benchmark | Reliability-validated benchmark spec | 12 min |
| **04** Kubernetes | Governance artifacts + cluster eval run | 22 min |

<div class="callout">

Every output from today maps to a real compliance requirement.  
The governance checklist in `resources/governance-checklist.md` shows exactly which EU AI Act article each artifact satisfies.

</div>

---

<!-- Slide 5: The tool stack, without jargon -->
## The Tools — Plain Language

| Tool | What it is | Analogy |
|------|------------|---------|
| `lm-eval` | Runs curated safety benchmarks | `pytest` for your model |
| `garak` | Probes for exploitable vulnerabilities | Fuzzing for prompts |
| `eval-hub-server` | Orchestrates evaluations, stores results | MLflow for safety evals |
| `evalhub` CLI | Submits jobs, reads results | `mlflow run` equivalent |
| KubeFlow Pipeline | Automates eval → routing decision | CI/CD gate for model upgrades |

---

<!-- Slide 6: Architecture — two phases -->
## Architecture: Local First, Then Kubernetes

```
SECTIONS 01–03 (your laptop, no cluster needed)
┌─────────────────────────────────────────────────┐
│  evalhub CLI → eval-hub-server (localhost:18080) │
│                    │                             │
│         ┌──────────┴──────────┐                  │
│    lm_eval adapter       garak adapter            │
│         └──────────┬──────────┘                  │
│                    ▼                             │
│              OpenRouter API (free, cloud)        │
└─────────────────────────────────────────────────┘

SECTION 04 (same CLI, different base_url)
┌─────────────────────────────────────────────────┐
│  evalhub CLI → EvalHub on RHOAI cluster          │
│                    │                             │
│             LMEvalJob pods → OpenRouter          │
│             Results → EvalHub UI + governance    │
└─────────────────────────────────────────────────┘
```

---

<!-- Slide 7: The frameworks explained -->
## Safety Frameworks You'll Use Today

**OWASP LLM Top 10** — The 10 threat categories every LLM deployment faces.  
Each garak probe maps to one or more of these codes. (Quick-ref: `resources/owasp-llm-top10-quick-ref.md`)

**AVID Taxonomy** — Categorises AI failures as Ethics / Performance / Security.  
EvalHub's built-in collections use AVID codes to tag benchmarks.

**NIST AI RMF** — Four functions: GOVERN · MAP · MEASURE · MANAGE.  
Your Section 04 artifacts map directly to MEASURE 2.5 and MANAGE 1.3.

**EU AI Act** — Articles 9, 10, 13 mandate risk management and data governance.  
The workshop produces the documentation those articles require.

---

<!-- Slide 8: Ground rules for the lab -->
## Ground Rules for the Next 90 Minutes

✅ **Every command is in the `lab.md` file** — copy-paste is encouraged  
✅ **Every expected output is shown** — if yours differs, there's a troubleshooting section  
✅ **Each section has `reset.sh`** — if something breaks, run it and start the section fresh  
✅ **OpenRouter free tier**: 20 requests/minute — the labs are designed to stay within this  

<div class="warning">

⚠️ Run `source .workshop-env` whenever you open a new terminal.  
Your API key and endpoints are stored there.

</div>

**Questions?** Anything tool-level gets answered in its section. Concepts — ask now.

---

<!-- Slide 9: Let's go -->
## Start Section 01 Now

```bash
# In your terminal, from the repo root:
source .venv/bin/activate
cd 01-setup
bash setup.sh
```

This takes about 30 seconds. Read the output — it tells you what's happening.

**While it runs:** The setup script starts `eval-hub-server` on `localhost:18080`, registers the lm-eval and garak providers, and stores your cluster endpoint for Section 04.

---

*Slides source: `slides/00-opening.md` · Render with Marp CLI: `marp slides/00-opening.md`*

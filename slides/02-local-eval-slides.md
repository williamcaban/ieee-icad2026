---
marp: true
theme: uncover
paginate: true
style: |
  section { background: #0f0f1a; color: #e8e8e8; font-family: 'Red Hat Text', sans-serif; font-size: 28px; padding: 48px 64px; }
  h1 { color: #ee0000; } h2 { color: #f5a623; }
  code { background: #1e1e2e; color: #cdd6f4; padding: 2px 6px; border-radius: 4px; }
  pre { background: #1e1e2e; border-left: 4px solid #ee0000; padding: 16px; font-size: 0.85em; }
  .journey { background: #1a1a2e; border: 1px solid #333; padding: 12px 20px; border-radius: 6px; font-size: 0.9em; }
  .callout { background: #1a2a1a; border-left: 4px solid #50fa7b; padding: 12px 16px; margin: 12px 0; }
  .warning { background: #2a1a1a; border-left: 4px solid #f5a623; padding: 12px 16px; margin: 12px 0; }
  .cite { font-size: 0.78em; color: #888; font-style: italic; }
  table { font-size: 0.85em; }
---

# Act 1 — Replicating Established Baselines

<div class="journey">

`[ 01 Setup ]` → `[ ● Act 1: Baseline ]` → `[ Act 2: Novel ]` → `[ Act 3: Compare ]`

</div>

**Why replicate before claiming novelty?** Because a benchmark that no one else can reproduce is not a contribution — it's a claim.

---

## What Replication Means Here

You are not writing new benchmarks. You are running well-established evaluations, on your infrastructure, against your model, under exactly the conditions the original authors specified.

This produces two things:

1. **A reproducible baseline** — a score you can defend, because you used the community-accepted method
2. **A point of comparison** — when Act 2 introduces your novel methodology, you can say "baseline was X, our approach measures Y"

This is standard practice in NLP and ML safety research. It is also what regulators mean when they ask for "validated evaluation methodology."

---

## The Three Baselines You Will Run

| Benchmark | Origin | What it measures |
|-----------|--------|-----------------|
| `bbq_generate` | Parrish et al., 2022 (BBQ) | Intersectional demographic bias across 9 social categories |
| `mmlu_business_ethics_generative` | Hendrycks et al., 2021 (MMLU) | Ethics alignment — business ethics domain |
| `lmrc.Bullying` + `promptinject.*` | Derczynski et al., 2024 (Garak) | Adversarial exploitability — harassment elicitation, prompt injection |

<p class="cite">Each of these has been cited in peer-reviewed work. Running them against your model gives you a baseline position relative to the existing literature.</p>

---

## Two Tracks — Static + Adversarial

```
Track A — Static benchmarks (lm-eval)    Track B — Adversarial probes (Garak)
┌──────────────────────────────────┐     ┌──────────────────────────────────┐
│ "Does the model produce biased   │     │ "Can an adversary exploit the    │
│  outputs on known failure modes  │     │  model's behaviour in ways the   │
│  identified in the literature?"  │     │  static benchmark doesn't test?" │
│                                  │     │                                  │
│  BBQ: 9 demographic categories   │     │  lmrc.Bullying     (OWASP LLM06) │
│  MMLU: 100 ethics questions      │     │  promptinject.*    (OWASP LLM01) │
└──────────────────────────────────┘     └──────────────────────────────────┘
```

A model that passes Track A can still fail Track B.
Both baselines are needed for a complete picture.

---

## Track A — Running the Bias Baseline

```bash
evalhub eval run \
  --provider lm_evaluation_harness \
  --benchmark bbq_generate \
  --model-url "${MODEL_ENDPOINT}" \
  --model-name "${MODEL_NAME}" \
  --param limit=5 --wait
```

Expected metrics:

| Metric | Typical value | Meaning |
|--------|---------------|---------|
| `acc` | 0.20 | 1 in 5 bias questions answered correctly |
| `accuracy_amb` | 0.00 | Always picks stereotyped answer in ambiguous context |
| `amb_bias_score` | 0.33 | 33% of ambiguous answers favour one demographic group |

<p class="cite">BBQ was designed specifically to surface subgroup failures invisible in aggregate fairness scores.</p>

---

## So What? — The BBQ Score in Context

<div class="warning">

**amb_bias_score = 0.33** — when context is ambiguous, the model picks stereotyped answers one-third of the time. Not because it was instructed to: because of training data patterns.

For a hiring tool, a loan system, or a healthcare triage assistant, this is a deployment risk requiring explicit mitigation and documented evidence.

**OWASP LLM06** — Sensitive Information Disclosure

</div>

This is your baseline. Act 2 measures the same risk domain through a different lens.

---

## Track B — Running the Adversarial Baseline

```bash
evalhub eval run \
  --provider garak \
  --benchmark "lmrc.Bullying" \
  --model-url "${MODEL_ENDPOINT}" \
  --model-name "${MODEL_NAME}" \
  --param generations=3 --wait
```

<div class="warning">

`promptinject.HijackHateHumans` typically produces `"I hate humans."` with no additional prompt engineering.  
**OWASP LLM01** — Prompt Injection: Critical severity

</div>

This probe is a peer-reviewed systematic attack, not an ad hoc jailbreak. It is reproducible, repeatable, and citable.

---

## Saving the Baseline

After both tracks complete, save a structured summary for Act 3:

```bash
evalhub eval results --format json > results/baseline_summary.json
```

`results/baseline_summary.json` is the input to the Act 3 MCP comparison notebook.

---

## What You Have Built

✅ Reproducible bias baseline (BBQ, MMLU) — citable against published benchmarks  
✅ Adversarial baseline (Garak) — systematic probe coverage, OWASP-mapped  
✅ Both stored in `eval-hub-server` — queryable via CLI and MCP  
✅ `results/baseline_summary.json` — the Act 3 comparison input

<div class="callout">

**→ Act 2:** Before you trust these scores — do you trust the labels they're measured against?  
That is the IRR question. And answering it is itself a research contribution.

</div>

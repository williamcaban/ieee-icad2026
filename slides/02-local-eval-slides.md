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
  .warning { background: #2a1a1a; border-left: 4px solid #f5a623; padding: 12px 16px; margin: 12px 0; }
  table { font-size: 0.85em; }
---

# Section 02 — Local Safety Evaluation

<div class="journey">

`[ 01 Setup ]` → `[ ● 02 Local Eval ]` → `[ 03 IRR ]` → `[ 04 Kubernetes ]`

</div>

Two evaluation tracks · Same `evalhub` CLI you'll use in Section 04 · No cluster needed

---

## The Two Tracks

```
Track A — Static benchmarks        Track B — Adversarial probes
┌─────────────────────────┐        ┌──────────────────────────────┐
│ lm_eval adapter         │        │ garak adapter                │
│ "Does the model score   │        │ "Can an adversary exploit    │
│  well on curated        │        │  the model's behaviour?"     │
│  safety datasets?"      │        │                              │
│                         │        │ Prompt injection             │
│ • BBQ (bias)            │        │ Toxic output elicitation     │
│ • MMLU ethics           │        │ Context leakage              │
└─────────────────────────┘        └──────────────────────────────┘
         Both are necessary. High Track A score ≠ low Track B risk.
```

---

## What Each Tool Is

**lm-eval** = `pytest` for your model.  
You define a dataset of inputs + expected outputs.  
It runs them at scale and reports pass rates.  
These datasets were designed by AI safety researchers — not you.

**garak** = fuzzing for prompts.  
A fuzzer sends malformed inputs to find crashes.  
Garak sends adversarially crafted prompts to find safety failures.

---

## Track A — Submit and Read

```bash
evalhub eval run \
  --provider lm_evaluation_harness \
  --benchmark bbq_generate \
  --model-url "${MODEL_ENDPOINT}" \
  --model-name "${MODEL_NAME}" \
  --param limit=5 --wait
```

| Metric | Typical value | What it means |
|--------|---------------|----------------|
| `acc` | 0.20 | 1 in 5 bias questions answered correctly |
| `accuracy_amb` | 0.00 | Always picks stereotyped answer when context is ambiguous |
| `amb_bias_score` | 0.33 | 33% of ambiguous answers favour Age stereotype |

---

## So What? (BBQ score = 0.20)

<div class="warning">

If this model powers a hiring tool and a candidate's age is unclear from context,  
it will systematically recommend against the older candidate 1 in 3 times —  
not because of any instruction to discriminate,  
but because of what it learned from training data.

**OWASP LLM06** — Sensitive Information Disclosure (demographic stereotyping as information harm)

</div>

This is why aggregate fairness scores mislead. The model may score 0.72 overall — and 0.00 on the subgroup your application most needs it to be fair on.

---

## Track B — Adversarial Probes

```bash
evalhub eval run \
  --provider garak \
  --benchmark "lmrc.Bullying" \
  --model-url "${MODEL_ENDPOINT}" \
  --model-name "${MODEL_NAME}" \
  --param generations=3 --wait
```

Inspect raw model responses:

```bash
JOB_DIR=$(ls -t /tmp/evalhub-jobs/ | head -1)
cat /tmp/evalhub-jobs/${JOB_DIR}/0/garak/*/jobrun.log | tail -20
```

<div class="warning">

`promptinject.HijackHateHumans` typically elicits `"I hate humans."`  
**OWASP LLM01** — Prompt Injection: Critical severity

</div>

---

## Both Tracks Together

| Track | Finding | OWASP | Action |
|-------|---------|-------|--------|
| A — BBQ | `amb_bias_score = 0.33` | LLM06 | Bias mitigation fine-tune |
| A — MMLU | `exact_match = 0.00` | LLM09 | RLHF on factual calibration |
| B — Injection | Harmful output triggered | LLM01 | Input validation layer |

A model can score well on Track A while failing Track B. You need both.

---

## What You've Built

✅ Live bias scores from a real model  
✅ Adversarial vulnerability findings  
✅ Both stored in `eval-hub-server` — retrievable with `evalhub eval results`

**→ Section 03:** Before you trust these benchmark scores, can you trust the benchmark's labels? That's the IRR question.

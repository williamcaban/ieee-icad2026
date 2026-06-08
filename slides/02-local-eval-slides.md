---
marp: true
theme: uncover
paginate: true
style: |
  section {
    background: #0f0f1a;
    color: #e8e8e8;
    font-family: 'Red Hat Text', 'Segoe UI', sans-serif;
    font-size: 28px;
    padding: 48px 64px;
  }
  h1 { color: #ee0000; font-size: 2.2em; }
  h2 { color: #f5a623; border-bottom: 2px solid #ee0000; padding-bottom: 8px; }
  h3 { color: #7bc8f6; }
  code { background: #1e1e2e; color: #cdd6f4; padding: 2px 6px; border-radius: 4px; }
  pre { background: #1e1e2e; border-left: 4px solid #ee0000; padding: 16px; font-size: 0.85em; }
  .callout { background: #1a2a1a; border-left: 4px solid #50fa7b; padding: 12px 16px; margin: 16px 0; border-radius: 0 4px 4px 0; }
  .warning { background: #2a1a1a; border-left: 4px solid #f5a623; padding: 12px 16px; margin: 16px 0; }
  .cite { font-size: 0.75em; color: #888; font-style: italic; margin-top: 8px; }
  .meta { font-size: 0.55em; color: #aaa; }
  .cols3 { display: grid; grid-template-columns: repeat(3, 1fr); gap: 1em; font-size: 0.75em; margin-top: 0.5em; }
  .cols3 > div { background: #1a1a2e; border-top: 3px solid #ee0000; padding: 14px 12px; border-radius: 0 0 4px 4px; }
  table { font-size: 0.88em; }
  .center { text-align: center; }
  .journey { background: #1a1a2e; border: 1px solid #333; padding: 12px 20px; border-radius: 6px; font-size: 0.9em; }
---

# Act 1: Replicating Established Baselines

<div class="journey">

`[ 01 Setup ]` → `[ ● 02 Baseline ]` → `[ 03 Novel ]` → `[ 04 Compare ]`

</div>

<div class="warning">

**Why replicate before claiming novelty?**
Because a benchmark that no one else can reproduce
is not a contribution, it's a claim.

</div>

---

## What Replication Means Here

You are not writing new benchmarks. You are running well-established
evaluations, on your infrastructure, against your model,
under exactly the conditions the original authors specified.

This produces two things:

1. **A reproducible baseline**: a score you can defend, because you used the community-accepted method
2. **A point of comparison**: when Act 2 introduces your novel methodology, you can say "baseline was X, our approach measures Y"

<div class="warning">

This is standard practice in NLP and ML safety research. It is also what regulators mean when they ask for "validated evaluation methodology."

</div>

---

## The Three Baselines You Will Run

| Benchmark | Origin | What it measures |
|:-----------|:--------|:-----------------|
| `bbq_generate` | Parrish et al., 2022 (BBQ) | Intersectional demographic bias across 9 social categories |
| `mmlu_business_ethics_generative` | Hendrycks et al., 2021 (MMLU) | Ethics alignment, business ethics domain |
| `lmrc.Bullying` + `promptinject.*` | Derczynski et al., 2024 (Garak) | Adversarial exploitability: harassment elicitation, prompt injection |

<p class="cite">Each of these has been cited in peer-reviewed work. Running them against your model gives you a baseline position relative to the existing literature.</p>

---

## Three Taxonomies You'll See in This Section

One Garak finding → three standard codes, three reporting contexts.

<div class="cols3">
<div>

**OWASP LLM Top 10**
Label the **threat type**

- LLM01 Prompt Injection
- LLM06 Info Disclosure
- LLM09 Overreliance

`owasp-llm-top10-quick-ref.md`

</div>
<div>

**CWE** (MITRE)
Label the **weakness**

- CWE-77 Cmd Injection
- CWE-200 Info Exposure
- CWE-284 Access Control

`cwe-garak-mapping.md`

</div>
<div>

**AVID**
Label the **AI failure mode**

- E0101 Group Fairness
- E0301 Toxicity
- S0201 Prompt Injection

`avid-taxonomy-quick-ref.md`

</div>
</div>

<div class="warning">

`lmrc.Bullying` hit → **OWASP LLM06** · **CWE-200** · **AVID E0301**

See cards in `resources/`
</div>

---

## Two Tracks: Static + Adversarial

```
Track A: Static benchmarks (lm-eval)    Track B: Adversarial probes (Garak)
┌──────────────────────────────────┐     ┌──────────────────────────────────┐
│ "Does the model produce biased   │     │ "Can an adversary exploit the    │
│  outputs on known failure modes  │     │  model's behaviour in ways the   │
│  identified in the literature?"  │     │  static benchmark doesn't test?" │
│                                  │     │                                  │
│  BBQ: 9 demographic categories   │     │  lmrc.Bullying     (OWASP LLM06) │
│  MMLU: 100 ethics questions      │     │  promptinject.*    (OWASP LLM01) │
└──────────────────────────────────┘     └──────────────────────────────────┘
```

A model that passes `Track A` can still fail `Track B`.
Both baselines are needed for a complete picture.

---

## Track A: Running the Bias Baseline

```bash
evalhub eval run \
  --name "act1-bbq-baseline" \
  --provider lm_evaluation_harness \
  --benchmark bbq_generate \
  --model-url "${MODEL_ENDPOINT}" \
  --model-name "${MODEL_NAME}" \
  --param limit=5 --wait
```

Expected metrics:

| Metric | Value | Interpretation |
|:--------|:-------|:---------------|
| `acc` | 0.20 | 1 in 5 questions correct |
| `accuracy_amb` | 0.00 | Always picks stereotyped answer when ambiguous |
| `amb_bias_score` | 0.33 | 33% of answers favour one demographic group |

<p class="cite">BBQ was designed specifically to surface <br />
subgroup failures invisible in aggregate fairness scores.</p>

---

## So What?: The BBQ Score in Context

<div class="warning">

- **amb_bias_score = 0.33**
    When context is ambiguous, the model picks stereotyped answers one-third of the time. Not because it was instructed to, but because of training data patterns.

    For a hiring tool, a loan system, or a healthcare triage assistant, this is a deployment risk requiring explicit mitigation and documented evidence.

- **OWASP LLM06**: Sensitive Information Disclosure

</div>

This is your baseline. Act 2 measures the
same risk domain through a different lens.

---

## Track B: Running the Adversarial Baseline

```bash
evalhub eval run \
  --name "act1-garak-baseline" \
  --provider garak \
  --benchmark "lmrc.Bullying" \
  --model-url "${MODEL_ENDPOINT}" \
  --model-name "${MODEL_NAME}" \
  --param generations=3 --wait
```

<div class="warning">

- `promptinject.HijackHateHumans` typically produces `"I hate humans."` with no additional prompt engineering.  
- **OWASP LLM01**: Prompt Injection: Critical severity

</div>

This probe is a peer-reviewed systematic attack,
not an ad hoc jailbreak. It is reproducible, repeatable, and citable.

---

## Map Your Garak Finding to OWASP + CWE

Open `resources/owasp-llm-top10-quick-ref.md` and fill in this row.

| Field | Your value |
|:------|:-----------|
| Probe run | `lmrc.Bullying` |
| Hit rate (`evalhub eval results`) | ___ % |
| OWASP LLM category | **LLM06**: Sensitive Information Disclosure |
| CWE | **CWE-200**: Exposure of Sensitive Data |
| AVID code | **E0301**: Ethics > Societal Harms > Toxicity |
| Remediation | Output safety classifier + content filter |

<div class="callout">

- This row is a **citable finding**: probe ID, hit rate, taxonomy codes.  
  - Paste it verbatim into a model card, a compliance report, or a paper appendix.

</div>

---

## Saving the Baseline

After both tracks complete, save a structured summary for Act 3:

```bash
evalhub eval results --format json > results/baseline_summary.json
```

- `results/baseline_summary.json` is the input to the Act 3 comparison notebook.

---

## What You Have Built

- ✅ Reproducible bias baseline (BBQ, MMLU): citable against published benchmarks  
- ✅ Adversarial baseline (Garak): systematic probe coverage, OWASP-mapped  
- ✅ Both stored in `eval-hub-server`: queryable via CLI and the REST API  
- ✅ `results/baseline_summary.json`: the Act 3 comparison input

<div class="callout">

- **→ Act 2:** Before you trust these scores: do you trust the labels they're measured against?  
- That is the IRR question. And answering it is itself a research contribution.

</div>

# Section 02 — Local Safety Evaluation

> **Where you are:** `[ 01 Setup ] → [ ● 02 Baseline ] → [ 03 Novel ] → [ 04 Compare ]`

**Duration**: 20 minutes (Track A: 12 min | Track B: 8 min) · **Needs cluster?** No

---

## What This Section Accomplishes

You submit two types of safety evaluations through the local `eval-hub-server`. The model answers real questions; you read real scores.

```
                           YOUR LAPTOP
┌──────────────────────────────────────────────────────────┐
│                                                          │
│  evalhub CLI ──► eval-hub-server (localhost:18080)       │
│                        │                                 │
│            ┌───────────┴───────────┐                     │
│      lm_eval adapter          garak adapter              │
│      (static benchmarks)     (adversarial probes)        │
│            └───────────┬───────────┘                     │
│                        │                                 │
│                  OpenRouter API                          │
│              (free cloud inference)                      │
└──────────────────────────────────────────────────────────┘
```

**Track A** tests *known failure modes* at scale — bias, ethics accuracy.  
**Track B** tests *exploitability* — can an adversary make the model misbehave?  
Both are necessary. A model can score well on Track A while being trivially exploitable by Track B.

> **Conceptual anchor — lm-eval:** Think of `lm_eval` as `pytest` for your model. You provide a dataset of inputs with expected outputs, and it runs them at scale and reports pass rates. The difference: these datasets were designed by AI safety researchers, not you.

> **Conceptual anchor — garak:** Think of `garak` as fuzzing for prompts. A fuzzer sends malformed inputs to a system to find crashes. Garak sends adversarially crafted prompts to find safety failures.

---

## Learning Objectives

- Submit static benchmarks through `evalhub eval run` and interpret scored results.
- Submit adversarial garak probes and connect findings to OWASP LLM threat codes.
- Understand why Track A and Track B together tell a fuller story than either alone.
- Understand that `evalhub eval run` works identically against the local server and on Kubernetes — only `base_url` changes.

---

## Setup

```bash
cd 02-local-evaluation
bash setup.sh
source ../.workshop-env
```

Verify the server is running:

```bash
evalhub health
evalhub providers list
```

---

## Track A — Static Benchmarks (12 min)

### What you're measuring

**BBQ (Bias Benchmark for QA)** — Tests whether the model defaults to stereotyped answers when context is ambiguous. 9 social categories: age, gender, nationality, race, religion, SES, disability, sexual orientation, physical appearance.

**MMLU Business Ethics** — Tests whether the model can reason correctly about ethical scenarios. Presented as multiple-choice; scored on exact match.

### Submit BBQ

```bash
evalhub eval run \
  --name "act1-bbq-baseline" \
  --provider lm_evaluation_harness \
  --benchmark bbq_generate \
  --model-url "${MODEL_ENDPOINT}" \
  --model-name "${MODEL_NAME}" \
  --param limit=5 \
  --wait
```

Watch the adapter log while it runs (second terminal):

```bash
tail -f /tmp/evalhub-local.log | grep -v "^{"
```

### Submit MMLU Ethics

```bash
evalhub eval run \
  --name "act1-mmlu-baseline" \
  --provider lm_evaluation_harness \
  --benchmark mmlu_business_ethics_generative \
  --model-url "${MODEL_ENDPOINT}" \
  --model-name "${MODEL_NAME}" \
  --param limit=5 \
  --wait
```

### Read the results

```bash
# List all completed jobs
evalhub eval status

# Read detailed metrics (replace <job-id> with the BBQ job ID)
evalhub eval results <job-id>
```

Expected BBQ output:

```
BENCHMARK     PROVIDER              METRIC            VALUE
bbq_generate  lm_evaluation_harness acc               0.2000
bbq_generate  lm_evaluation_harness accuracy_amb      0.0000
bbq_generate  lm_evaluation_harness accuracy_disamb   0.5000
bbq_generate  lm_evaluation_harness amb_bias_score    0.3333
```

### Interpreting the scores

| Metric | Value | What it means |
|--------|-------|----------------|
| `acc` | 0.20 | Model answers only 1 in 5 bias-sensitive questions correctly |
| `accuracy_amb` | 0.00 | When context is *ambiguous*, the model always picks the stereotyped answer |
| `accuracy_disamb` | 0.50 | When context *names* the individual, performance is random |
| `amb_bias_score` | 0.33 | 33% of ambiguous-context answers favour the Age stereotype |

> **So what?** If this model powers a hiring tool and a candidate's age is unclear from context, the model will systematically recommend against the older candidate 1 in 3 times — not because of any instruction to discriminate, but because of what it learned from training data. This is an **LLM06** finding: demographic stereotyping as information harm.

> The MMLU `exact_match = 0.00` tells a different story: the model cannot produce correctly formatted ethics answers. An application that relies on the model to *reason about* ethics policies is essentially guessing. This is an **LLM09** finding: the model will hallucinate confident-sounding ethics judgments that are wrong.

---

## Track B — Adversarial Probes (8 min)

### What you're testing

**Prompt injection** — Can an adversary redirect the model's output by embedding hidden instructions?  
**Bullying elicitation** — Can the model be prompted to produce bullying content?

These are *exploitability* tests. A model can score 0.80 on BBQ (good bias score) and still be trivially injectable. Track A and Track B test different threat surfaces.

### Submit garak probes

```bash
evalhub eval run \
  --name "act1-garak-baseline" \
  --provider garak \
  --benchmark "lmrc.Bullying" \
  --model-url "${MODEL_ENDPOINT}" \
  --model-name "${MODEL_NAME}" \
  --param generations=3 \
  --wait
```

### Inspect the adapter output

```bash
# Find the most recent job directory
JOB_DIR=$(ls -t /tmp/evalhub-jobs/ | head -1)
cat /tmp/evalhub-jobs/${JOB_DIR}/0/garak/*/jobrun.log | tail -20
```

The log shows the model's raw responses to each probe. Look for responses that contain harmful content — that's a triggered vulnerability.

```bash
evalhub eval results <garak-job-id>
```

> **So what?** When `promptinject.HijackHateHumans` elicits `"I hate humans."` — as it typically does with smaller models — that's not a quirky edge case. It's a reproducible attack path. Any application that accepts user-provided context (a document, a URL, a form field) is potentially exposed. This is an **LLM01** finding.

### Map your finding to OWASP + CWE (2 min)

Open `../resources/owasp-llm-top10-quick-ref.md` alongside your results and fill in this row. You only need the hit rate from `evalhub eval results`.

```
Probe run:   lmrc.Bullying
Hit rate:    ___% (fill from your results)
OWASP LLM:  LLM06 — Sensitive Information Disclosure
CWE:         CWE-200 — Exposure of Sensitive Information to an Unauthorized Actor
AVID code:   E0301 — Ethics > Societal Harms > Toxicity
Remediation: Output safety classifier; content filter before response reaches user
```

Copy this block into `results/baseline_summary.json` as a `findings` array entry — it becomes your citable evidence record for the governance checklist in the closing discussion.

```bash
# Quick-open the reference card
open ../resources/owasp-llm-top10-quick-ref.md       # macOS
xdg-open ../resources/owasp-llm-top10-quick-ref.md   # Linux
```

---

## Track C — LightEval Provider (optional, 4 min)

This track demonstrates the key architectural point of EvalHub: **the same CLI works with different evaluation frameworks**. Track A used `lm_evaluation_harness`; Track C uses `lighteval` — different backend, identical command shape.

### Install LightEval (if not already done)

```bash
uv pip install -r adapters/lighteval/requirements.txt
```

### Run TruthfulQA via LightEval

```bash
evalhub eval run \
  --name "act1-truthfulqa-lighteval" \
  --provider lighteval \
  --benchmark truthfulqa_lighteval \
  --model-url "${MODEL_ENDPOINT}" \
  --model-name "${MODEL_NAME}" \
  --param limit=5 \
  --wait
```

Expected output:

```
BENCHMARK              PROVIDER    METRIC    VALUE
truthfulqa_lighteval   lighteval   mc1       0.40
truthfulqa_lighteval   lighteval   mc2       0.58
```

### (Optional) Run WinoGender

```bash
evalhub eval run \
  --name "act1-winogender-lighteval" \
  --provider lighteval \
  --benchmark winogender_lighteval \
  --model-url "${MODEL_ENDPOINT}" \
  --model-name "${MODEL_NAME}" \
  --param limit=5 \
  --wait
```

### Interpreting Track C

| Metric | Benchmark | OWASP | AVID | What it means |
|--------|-----------|-------|------|---------------|
| `mc1` < 0.50 | TruthfulQA | LLM09 | E0303 | Model picks false answers at human-myth rate — overreliance risk |
| `acc` < 0.60 | WinoGender | LLM06 | E0101 | Model resolves pronouns by occupational stereotype |

> **The architectural point:** `evalhub providers list` now shows three registered backends — `lm_evaluation_harness`, `garak`, and `lighteval`. The eval-hub-server routes each job to the correct adapter. You add a new evaluation framework by writing one adapter and one provider YAML — the orchestration layer is unchanged.

---

## Track A + Track B Together

| Source | Finding | OWASP | Severity |
|--------|---------|-------|---------|
| lm-eval BBQ | `amb_bias_score = 0.33` | LLM06 | Medium |
| lm-eval MMLU | `exact_match = 0.00` | LLM09 | High |
| garak injection | Harmful output triggered | LLM01 | Critical |

The combination tells you: this model has *both* a systematic fairness problem *and* an exploitable injection surface. Neither finding alone would justify the response that both together do.

> **🔁 Reuse pattern:** `evalhub eval run` is identical on laptop and Kubernetes — only `evalhub config set base_url <cluster-url>` changes. The closing demo shows this running on RHOAI.

---

## Checkpoint ✓

```bash
# At least 2 completed jobs in the local server
evalhub eval status 2>&1 | grep -c "completed"

# Server still healthy after running evaluations
evalhub health | python3 -c "import sys,json; print('Server:', json.load(sys.stdin)['status'])"
```

---

## What You've Built

You now have live evaluation results from a real model — bias scores, ethics accuracy, and adversarial probe findings — all stored in the local `eval-hub-server`.

**In Section 03**, you'll shift from evaluating a model to validating an evaluation dataset itself. Before you can trust your benchmark scores, you need to know whether the benchmark labels are trustworthy.

---

## Troubleshooting

**`evalhub health` fails** — Server stopped. Re-run `bash ../01-setup/setup.sh`.

**Job stays in `running`** — Check: `cat /tmp/evalhub-jobs/<uuid>/0/*/*/jobrun.log | tail -20`.

**OpenRouter 429 (rate limit)** — Free tier: 20 req/min. Wait 60 seconds and resubmit. The `--param limit=3` flag reduces the number of API calls if needed.

**`OPENAI_API_KEY` error in log** — Run `source ../.workshop-env`, then re-run `bash setup.sh`.

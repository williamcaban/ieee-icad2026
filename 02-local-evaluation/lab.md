# Section 02 Lab — Local Safety Evaluation

**Duration**: 20 minutes (Track A: 12 min | Track B: 8 min)
**Prerequisites**: Section 01 complete, `.workshop-env` sourced, `.venv` active

---

## Learning Objectives

- Use the same `evalhub` CLI against the **local eval-hub-server** that you will use in Section 04 against the cluster — zero learning curve when switching environments.
- Submit static bias and ethics benchmarks (BBQ + MMLU) through the local server.
- Submit adversarial garak probes through the local server.
- Read scored results with `evalhub eval results`.

---

## Architecture

```
Your laptop (no cluster needed)
  evalhub CLI ──► eval-hub-server (localhost:18080, started by Section 01)
                       │
                       ├── adapters/lm_eval/main.py ──► OpenRouter
                       └── adapters/garak/main.py   ──► OpenRouter
```

The local server writes job specs to `/tmp/evalhub-jobs/`, spawns adapters as
subprocesses, and accepts results via callback at `http://localhost:18080`.

---

## Step 1 — Section Setup

```bash
cd 02-local-evaluation
bash setup.sh
source ../.workshop-env
```

Expected output:

```
[OK]    OPENROUTER_API_KEY is set.
[OK]    OPENAI_API_KEY set.
[OK]    Local eval-hub-server is running.
[OK]    Providers registered: 2
```

---

## Step 2 — Verify Local Server

```bash
evalhub health
# Expected: {"status":"healthy","build":"0.4.1",...}

evalhub providers list
# Expected: lm_evaluation_harness (2 benchmarks), garak (2 benchmarks)
```

---

## Track A — Static Benchmarks (12 min)

### Submit BBQ Bias Evaluation

```bash
evalhub eval run \
  --name "local-bbq-$(date +%s)" \
  --provider lm_evaluation_harness \
  --benchmark bbq_generate \
  --model-url "${MODEL_ENDPOINT}" \
  --model-name "${MODEL_NAME}" \
  --param limit=5 \
  --wait
```

`--wait` blocks until the adapter finishes (~30 seconds). Watch the job log live:

```bash
# In a second terminal while the above runs:
tail -f /tmp/evalhub-local.log | grep -v "^{"
```

Expected result:

```
Job submitted: <uuid>
Waiting for job <uuid> to complete...
Job <uuid> finished with state: completed
```

### Submit MMLU Ethics Evaluation

```bash
evalhub eval run \
  --name "local-mmlu-$(date +%s)" \
  --provider lm_evaluation_harness \
  --benchmark mmlu_business_ethics_generative \
  --model-url "${MODEL_ENDPOINT}" \
  --model-name "${MODEL_NAME}" \
  --param limit=5 \
  --wait
```

### Read Scores

```bash
# List all jobs with status
evalhub eval status

# Get full metric table for the BBQ job
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

**Reading the results:**

- `acc = 0.20`: model answers only 20% of bias-sensitive questions correctly.
- `amb_bias_score = 0.33`: when context is ambiguous, the model picks the Age-stereotyped answer 33% of the time → **LLM06 (Sensitive Information Disclosure)** finding.
- `exact_match = 0.00` (MMLU ethics): model cannot produce correctly formatted ethics answers → **LLM09 (Overreliance)** finding.

---

## Track B — Adversarial Probes (8 min)

### Submit Garak Probes

```bash
evalhub eval run \
  --name "local-garak-$(date +%s)" \
  --provider garak \
  --benchmark "lmrc.Bullying" \
  --model-url "${MODEL_ENDPOINT}" \
  --model-name "${MODEL_NAME}" \
  --param generations=3 \
  --wait
```

### Read Results and Adapter Log

```bash
evalhub eval results <garak-job-id>
```

The garak adapter captures raw model responses. Inspect them:

```bash
# Find the job directory and read what the model said
JOB_DIR=$(ls -t /tmp/evalhub-jobs/ | head -1)
cat /tmp/evalhub-jobs/${JOB_DIR}/0/garak/*/jobrun.log | grep -A2 "Running probe"
```

**Key finding**: `promptinject.HijackHateHumans` typically elicits harmful output like `"I hate humans."` — a clear **LLM01 (Prompt Injection)** vulnerability.

---

## Compare Local vs Cluster (Preview of Section 04)

| | Section 02 (local) | Section 04 (cluster) |
|---|---|---|
| Server | `eval-hub-server` on laptop | EvalHub on RHOAI |
| Job execution | Host subprocess | Kubernetes pod |
| Results stored | In-memory SQLite | Persistent storage |
| Auth required | No | Yes (SA token) |
| CLI command | **Identical** `evalhub eval run` | **Identical** `evalhub eval run` |

Section 04 only changes `evalhub config set base_url` — all other commands stay the same.

---

## Checkpoint

```bash
# Local server healthy
evalhub health | python3 -c "import sys,json; d=json.load(sys.stdin); print('Server:', d['status'])"

# At least 2 completed jobs
evalhub eval status 2>&1 | grep -c "completed"
```

---

## Troubleshooting

**`evalhub health` fails** — Local server stopped. Re-run: `bash ../01-setup/setup.sh`

**Job stays in `running` indefinitely** — Check the adapter log:
```bash
tail -30 /tmp/evalhub-local.log
ls /tmp/evalhub-jobs/   # find the job dir
cat /tmp/evalhub-jobs/<uuid>/0/*/*/jobrun.log | tail -20
```

**OpenRouter 429 rate limit** — Free tier: 20 req/min. Wait 60 seconds and resubmit.

**`lm-eval failed` in adapter log** — Verify `OPENAI_API_KEY` is set:
```bash
echo $OPENAI_API_KEY   # must not be empty
```
If empty: re-run `bash ../01-setup/setup.sh` which exports it before starting the server.

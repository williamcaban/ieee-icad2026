# Section 04 — Kubernetes: EvalHub, Benchmarks & Governance

> **Where you are:** `[ 01 Setup ] → [ 02 Local Eval ] → [ 03 IRR ] → [ ● 04 Kubernetes ]`

**Duration**: 22 minutes · **Needs cluster?** Yes — `oc` login required

---

## What This Section Accomplishes

You switch the `evalhub` CLI from `localhost:18080` to the cluster EvalHub in one command, then run the same evaluation workflow you ran locally — but now it executes inside Kubernetes pods, stores results persistently, and produces governance artifacts.

```
           SECTION 04 — SAME CLI, DIFFERENT BACKEND
┌─────────────────────────────────────────────────────────┐
│                                                         │
│  evalhub CLI ──► EvalHub on RHOAI cluster               │
│   (same commands as Sections 02-03)                     │
│                        │                               │
│                 LMEvalJob pod ──► OpenRouter            │
│                        │                               │
│                 Results stored persistently             │
│                 Visible in EvalHub UI                   │
│                 Auditable in Kubernetes CR history      │
│                                                         │
│  PLUS:                                                  │
│  Register IRR benchmark from Section 03                 │
│  Export governance artifacts (EU AI Act / NIST RMF)     │
└─────────────────────────────────────────────────────────┘
```

> **Conceptual anchor:** This is the same shift as going from `python train.py` on your laptop to submitting a Kubernetes `TrainingJob`. The evaluation logic is identical; what changes is who orchestrates it, where results live, and what audit trail exists.

---

## Local vs. Cluster — Side by Side

| Dimension | Sections 01–03 (local) | Section 04 (cluster) |
|-----------|----------------------|----------------------|
| Server | `eval-hub-server` on port 18080 | EvalHub operator on RHOAI |
| Job execution | Host subprocess on your laptop | Kubernetes `LMEvalJob` pod |
| Results storage | In-memory SQLite (lost on restart) | Persistent EvalHub storage |
| Auth required | No | Yes (SA token via `setup.sh`) |
| Visible in UI | No | Yes — RHOAI Dashboard |
| Audit trail | Log files | Kubernetes CR history |
| **CLI command** | **Identical** | **Identical** |

The only change: `evalhub config set base_url <cluster-url>` — which `setup.sh` does for you.

---

## Learning Objectives

- Switch the `evalhub` CLI from local to cluster in a single command.
- Submit an `LMEvalJob` and watch it execute in the cluster.
- Register your IRR benchmark from Section 03 as a cluster-side benchmark.
- Export governance artifacts that satisfy EU AI Act and NIST AI RMF documentation requirements.

---

## Setup

```bash
cd 04-kubernetes
bash setup.sh
source ../.workshop-env
```

`setup.sh` does three things:
1. Switches `evalhub config set base_url` to the cluster endpoint
2. Creates the `openrouter-credentials` secret in the cluster
3. Applies the RBAC grants that let `workshop-sa` call EvalHub APIs

Open the EvalHub UI in your browser — URL is printed by `setup.sh`.

---

## Part A — Browse the Cluster Collections (3 min)

```bash
evalhub collections list
evalhub providers list
evalhub providers describe lm_evaluation_harness
```

These are the *same commands* you'd run against the local server. The output is the cluster's built-in collections: `safety-and-fairness-v1`, `toxicity-and-ethical-principles`.

---

## Part B — Submit a Cluster Evaluation (6 min)

```bash
evalhub eval run \
  --name "cluster-bbq-$(date +%s)" \
  --provider lm_evaluation_harness \
  --benchmark bbq_generate \
  --model-url "${MODEL_ENDPOINT}" \
  --model-name "${MODEL_NAME}" \
  --param limit=5
```

Watch it execute:

```bash
oc get lmevaljob -n workshop-eval -w
```

When complete, compare cluster results to Section 02 local results:

```bash
evalhub eval results <cluster-job-id>
```

> **So what?** The scores should be identical or very close to Section 02. The difference: these results are now in persistent storage, tied to a Kubernetes CR, and visible to every team member who has access to the cluster. The local run was ephemeral; this one is auditable.

---

## Part C — Register Your IRR Benchmark (5 min)

Section 03 produced `irr_report.json`. Now register it on the cluster:

```bash
python3 ../03-irr-local/scripts/register_benchmark.py \
  --report ../03-irr-local/irr_report.json \
  --name "workshop-irr-safety-v1"
```

Expected:

```
Alpha = 0.8118 — OK to register.
Benchmark registered: workshop-irr-safety-v1
Verify with: evalhub benchmarks describe workshop-irr-safety-v1
```

Verify in the RHOAI Dashboard: **Evaluations → Benchmarks → workshop-irr-safety-v1**.

The benchmark entry includes `irr_metadata` — any team member can see the reliability evidence without needing the original CSV.

> **🔁 Reuse pattern for consultants:** This is the workflow for onboarding a client's custom benchmark into EvalHub. Collect annotations from client SMEs → compute IRR → register if α ≥ 0.67. The benchmark then becomes a shared organizational asset that any eval job can reference.

---

## Part D — Export Governance Artifacts (5 min)

```bash
EXPORT_DIR="governance-export-$(date +%Y%m%d)"
mkdir -p "${EXPORT_DIR}"

# Cluster evaluation results
evalhub eval results <cluster-job-id> --format json > \
  "${EXPORT_DIR}/cluster-eval-results.json" && echo "✓ cluster-eval-results.json"

# IRR reliability evidence
cp ../03-irr-local/irr_report.json "${EXPORT_DIR}/" && echo "✓ irr_report.json"

# Kubernetes CR (the policy as code)
oc get lmevaljob -n workshop-eval -o yaml | \
  grep -v "resourceVersion\|uid\|creationTimestamp\|managedFields" \
  > "${EXPORT_DIR}/lmevaljob-cr.yaml" && echo "✓ lmevaljob-cr.yaml"

# Garak vulnerability report from Section 02
cp ../02-local-evaluation/results/garak-report.report.jsonl \
  "${EXPORT_DIR}/" 2>/dev/null && echo "✓ garak-report.jsonl"

echo ""
echo "Governance artifacts in: ${EXPORT_DIR}/"
ls -lh "${EXPORT_DIR}/"
```

### What each artifact satisfies

| Artifact | EU AI Act | NIST AI RMF |
|---------|-----------|-------------|
| `cluster-eval-results.json` | Art. 9 — Risk management | MEASURE 2.5 |
| `lmevaljob-cr.yaml` | Art. 9 + Art. 13 — Transparency | GOVERN 1.1 |
| `irr_report.json` | Art. 10 — Data governance | MAP 2.3 |
| `garak-report.jsonl` | Art. 9 — Adversarial risk | MEASURE 2.6 |

> **So what?** When an auditor asks "how do you demonstrate that your AI system's risk was assessed before deployment?" — this export directory is the answer. The LMEvalJob CR is version-controlled (it's a Kubernetes object with a history). The IRR report shows the benchmark was validated before use. The cluster eval results show a quantified score against a defined threshold. The garak report shows adversarial coverage.

---

## Part E — View in RHOAI Dashboard (3 min)

```bash
echo "Dashboard: https://$(oc get route rhods-dashboard \
  -n redhat-ods-applications -o jsonpath='{.spec.host}' 2>/dev/null)"
```

Navigate to **AI & ML → Evaluations** (or search "EvalHub"). You should see:
- Your cluster evaluation jobs with status and scores
- The `workshop-irr-safety-v1` benchmark under Benchmarks

This is what a team lead or MLOps engineer sees without needing CLI access.

> **🔁 Reuse pattern for ML engineers:** The `evalhub eval run` command is what you'd add to a CI/CD pipeline. On every model update: run the command, check the exit code (0 = all benchmarks passed, 1 = one or more failed), gate the deployment on the result. The `lmevaljob-cr.yaml` is the policy file that goes in your GitOps repo alongside the model deployment manifest.

---

## Checkpoint ✓

```bash
# Cluster eval completed
oc get lmevaljob -n workshop-eval --no-headers | grep -c "Succeeded"

# IRR benchmark registered
evalhub benchmarks describe workshop-irr-safety-v1 2>/dev/null | head -5

# Governance export exists
ls governance-export-*/cluster-eval-results.json 2>/dev/null && echo "Export: OK"
```

---

## What You've Built

Over the last 80 minutes you have:

1. **Evaluated a model locally** — bias scores, ethics accuracy, adversarial vulnerabilities
2. **Validated a custom benchmark** — IRR metrics that prove the labels are trustworthy
3. **Moved to the cluster** — same results, now persistent, auditable, and visible in the UI
4. **Registered a benchmark** — reproducible, discoverable by other teams
5. **Exported governance artifacts** — mapped to EU AI Act and NIST AI RMF requirements

These patterns are production-grade. The CLI commands, the YAML files, the provider adapters, the IRR workflow — all of it is directly reusable.

---

## Troubleshooting

**`evalhub eval run` returns 401** — Token expired. Re-run `bash setup.sh` to refresh.

**LMEvalJob stuck in Scheduled** — Check: `oc describe lmevaljob -n workshop-eval`. Alert the facilitator.

**`register_benchmark.py` returns 409 Conflict** — Already registered. Run `bash reset.sh` then retry.

**`governance-export` directory empty** — The cluster eval may have failed. Check: `oc get lmevaljob -n workshop-eval -o jsonpath='{.items[0].status.reason}'`.

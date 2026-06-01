# Section 04 Lab — Kubernetes: EvalHub, Custom Benchmarks & Governance

**Duration**: 22 minutes
**Prerequisites**: Sections 01–03 complete, `oc` logged in to cluster

---

## Learning Objectives

- Submit a `LMEvalJob` CR and monitor it via `oc` CLI.
- Read scored results directly from the LMEvalJob status (the governance artifact).
- Store your IRR benchmark metadata as a Kubernetes ConfigMap for team visibility.
- Export evaluation results mapped to EU AI Act Articles and NIST AI RMF.
- Access the EvalHub UI via the RHOAI Dashboard.

---

## Architecture

EvalHub on RHOAI 0.3.x exposes its API at `/api/v1/evaluations/*`:
- Collections & providers → `evalhub collections list` / `evalhub providers list`
- Evaluations → `LMEvalJob` CRs via `oc apply -f` or `evalhub eval run`
- Results → `LMEvalJob.status.results` JSON + `evalhub eval results`
- UI → RHOAI Dashboard (Evaluations section)

---

## Setup

```bash
cd 04-kubernetes
bash setup.sh
source ../.workshop-env
```

---

## Part A — Explore EvalHub Collections & Submit Evaluation (6 min)

### Browse available collections and providers

```bash
evalhub collections list
evalhub providers list
evalhub collections describe safety-and-fairness-v1
```

### Submit an evaluation via evalhub CLI

```bash
evalhub eval run \
  --name icad2026-cluster-eval \
  --provider lm_evaluation_harness \
  --benchmark bbq_generate \
  --benchmark mmlu_business_ethics_generative \
  --model-url "${MODEL_ENDPOINT}/chat/completions" \
  --model-name "${MODEL_NAME}" \
  --param limit=5 \
  --param apply_chat_template=true
```

### Or apply directly as a Kubernetes CR

```bash
oc apply -f configs/eval-run-live.yaml
oc get lmevaljob icad2026-cluster-eval -n workshop-eval -w
```

### Read results via evalhub CLI

```bash
evalhub eval status
evalhub eval results icad2026-cluster-eval
```

Or directly from the Kubernetes CR:

```bash
oc get lmevaljob icad2026-cluster-eval -n workshop-eval \
  -o jsonpath='{.status.results}' 2>/dev/null | python3 -c "
import sys, json, math
d = json.loads(sys.stdin.read())
print('\n=== CLUSTER EVALUATION RESULTS ===\n')
for task, metrics in d.get('results', {}).items():
    print(f'Task: {task}')
    for k, v in metrics.items():
        if isinstance(v, float) and not math.isnan(v) and not k.endswith('stderr'):
            print(f'  {k.split(\",\")[0]}: {v:.4f}')
    print()
"
```

Expected output:
```
=== CLUSTER EVALUATION RESULTS ===

Task: bbq_generate
  acc: 0.2000
  accuracy_amb: 0.0000
  accuracy_disamb: 0.5000
  amb_bias_score: 0.3333

Task: mmlu_business_ethics_generative
  exact_match: 0.0000
```

**Compare with Section 02**: These cluster results should match the local lm-eval run.
The cluster adds: persistent storage, team visibility, auditable CR history.

---

## Part B — Store IRR Benchmark on the Cluster (5 min)

Register the IRR benchmark metadata as a Kubernetes ConfigMap so the team can access it:

```bash
# Read the IRR report and create a ConfigMap
python3 - <<'EOF'
import json, subprocess, sys

report = json.load(open('../03-irr-local/irr_report.json'))
alpha = report['krippendorff_alpha']['value']
items = report['benchmark_items_count']
labels = {i['label']: 0 for i in report['benchmark_items']}
for item in report['benchmark_items']:
    labels[item['label']] += 1

# Build ConfigMap YAML
cm = f"""apiVersion: v1
kind: ConfigMap
metadata:
  name: icad2026-irr-benchmark
  namespace: workshop-eval
  labels:
    workshop: icad2026
    benchmark-type: custom-irr
  annotations:
    alpha: "{alpha:.4f}"
    recommendation: "{report['recommendation']}"
    items: "{items}"
    label-distribution: "{json.dumps(labels)}"
data:
  irr_report.json: |
"""
for line in json.dumps(report, indent=2).split('\n'):
    cm += f"    {line}\n"

with open('/tmp/irr-benchmark-cm.yaml', 'w') as f:
    f.write(cm)
print("ConfigMap written to /tmp/irr-benchmark-cm.yaml")
print(f"Alpha: {alpha:.4f} | Items: {items} | Distribution: {labels}")
EOF

oc apply -f /tmp/irr-benchmark-cm.yaml
echo "IRR benchmark ConfigMap registered:"
oc get configmap icad2026-irr-benchmark -n workshop-eval \
  -o jsonpath='{.metadata.annotations}' | python3 -m json.tool
```

---

## Part C — Governance Artifact Export (6 min)

```bash
# Create export directory
EXPORT_DIR="governance-export-$(date +%Y%m%d)"
mkdir -p "${EXPORT_DIR}"

# 1. Cluster evaluation results (the key governance artifact)
oc get lmevaljob icad2026-cluster-eval -n workshop-eval \
  -o jsonpath='{.status.results}' > "${EXPORT_DIR}/cluster-eval-results.json"
echo "✓ Cluster results exported"

# 2. IRR benchmark spec
cp ../03-irr-local/irr_report.json "${EXPORT_DIR}/irr_report.json"
echo "✓ IRR report exported"

# 3. LMEvalJob CR (the policy as code)
oc get lmevaljob icad2026-cluster-eval -n workshop-eval -o yaml \
  | grep -v "resourceVersion\|uid\|creationTimestamp\|managedFields" \
  > "${EXPORT_DIR}/lmevaljob-cr.yaml"
echo "✓ LMEvalJob CR exported"

# 4. Garak report from Section 02
cp ../02-local-evaluation/results/garak-report.report.jsonl \
  "${EXPORT_DIR}/garak-report.jsonl" 2>/dev/null && echo "✓ Garak report exported"

echo ""
echo "Governance artifacts in: ${EXPORT_DIR}/"
ls -lh "${EXPORT_DIR}/"
```

### Map Artifacts to Regulatory Frameworks

```bash
cat ../resources/governance-checklist.md | grep -A3 "cluster-eval\|lmevaljob\|irr_report\|EU AI Act"
```

| Artifact | EU AI Act Article | NIST AI RMF Function |
|---------|-----------------|---------------------|
| `cluster-eval-results.json` | Art. 9 — Risk management | MEASURE 2.5 |
| `lmevaljob-cr.yaml` | Art. 9 + Art. 13 — Transparency | GOVERN 1.1 |
| `irr_report.json` | Art. 10 — Data governance | MAP 2.3 |
| `garak-report.jsonl` | Art. 9 — Adversarial risk | MEASURE 2.6 |

---

## Part D — View in RHOAI Dashboard (5 min)

The EvalHub UI is integrated into the RHOAI Dashboard:

```bash
# Get the dashboard URL
oc get route rhods-dashboard -n redhat-ods-applications \
  -o jsonpath='{.spec.host}' 2>/dev/null && echo ""
```

Open the printed URL in your browser. Navigate to:
**AI & ML → Evaluations** (or search for "EvalHub" in the nav)

You should see:
- `icad2026-cluster-eval` with status Complete
- Benchmark scores per task
- Run metadata including model name and timestamp

---

## Checkpoint

```bash
# LMEvalJob must show Succeeded
oc get lmevaljob icad2026-cluster-eval -n workshop-eval \
  -o jsonpath='{.status.reason}' | grep -q "Succeeded" && echo "Cluster eval: OK"

# IRR ConfigMap must exist
oc get configmap icad2026-irr-benchmark -n workshop-eval \
  -o jsonpath='{.metadata.annotations.alpha}' && echo " (alpha)"

# Governance export must have 3+ files
ls governance-export-*/  | wc -l | grep -qE "^[3-9]" && echo "Governance export: OK"
```

---

## Troubleshooting

**LMEvalJob stuck in Scheduled**: Check `oc describe lmevaljob icad2026-cluster-eval -n workshop-eval`. Alert facilitator if pod never starts.

**`oc get lmevaljob` shows Failed**: Check logs: `oc logs icad2026-cluster-eval -n workshop-eval --all-containers | tail -20`.

**`status.results` is empty**: The job may have failed before writing results. Check `oc get lmevaljob ... -o jsonpath='{.status.message}'`.

**RHOAI Dashboard doesn't show EvalHub section**: This feature requires RHOAI 2.10+. Check the dashboard version and ask the facilitator.

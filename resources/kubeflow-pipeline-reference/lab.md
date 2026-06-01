# Section 06 Lab — KubeFlow Pipeline A/B Routing

**Duration**: 10 minutes
**Prerequisites**: `kfp` SDK installed (by setup.sh), `~/.workshop-env` sourced

---

## Learning Objectives

- Read a KFP v2 pipeline and understand its three-component architecture.
- Compile `pipeline.py` to `pipeline.yaml` using the KFP SDK.
- Upload the compiled pipeline to KubeFlow and trigger a run.
- Observe the evaluation-driven routing decision in the KFP UI.

---

## Background: Why Pipeline-Based Routing?

Without automated routing, a model upgrade requires:
1. A manual evaluation run
2. Human review of the results
3. An infrastructure ticket to change the serving endpoint
4. A deployment window

With a KFP pipeline, the entire cycle — evaluate, compare, route — runs automatically when triggered by a new model push or a scheduled CI/CD job. The safety gate is enforced by code, not by process.

---

## Prerequisites Check

```bash
source ~/.workshop-env
python3 -c "import kfp; print(f'kfp {kfp.__version__}')"
echo "KFP endpoint: ${KFP_ENDPOINT:?NOT SET}"
```

---

## Step 1 — Run Section Setup

```bash
cd 06-kubeflow-pipeline
bash setup.sh
```

Expected output:

```
[INFO]  Sourcing workshop environment...
[OK]    KFP_ENDPOINT: https://ds-pipeline-ui-workshop-eval.apps.cluster.example.com...
[OK]    kfp 2.7.0 is already installed.
[OK]    KubeFlow Pipelines API is reachable.
  Section 06 setup complete.
```

---

## Step 2 — Read the Pipeline Architecture

Open `pipeline.py` and review the three component functions:

```bash
grep -n "^def \|^@dsl" pipeline.py
```

Expected output:

```
44: @dsl.component(
48: def evaluate_model(
111: @dsl.component(base_image=EVALHUB_IMAGE)
112: def compare_scores(
151: @dsl.component(
154: def route_traffic(
225: @dsl.pipeline(
232: def safety_ab_router_pipeline(
```

The pipeline DAG:
```
evaluate_model(model_a) ─┐
                          ├─► compare_scores ─► route_traffic
evaluate_model(model_b) ─┘
```

`evaluate_model` and `evaluate_model` run **in parallel** — KFP automatically parallelizes sibling nodes with no dependency between them.

**Key design decisions:**
- If *neither* model passes the safety threshold, `route_traffic` takes a `no_change` action and writes a warning. Traffic is **not** automatically redirected to a failing model.
- The `compare_scores` component encodes the routing policy as code — change this function to implement different tie-breaking logic (e.g., prefer the smaller model at equal scores).

---

## Step 3 — Compile the Pipeline

```bash
python3 pipeline.py
```

Expected output:

```
Pipeline compiled to: pipeline.yaml
Upload with: kfp pipeline upload pipeline.yaml --pipeline-name safety-ab-router
```

Inspect the compiled YAML:

```bash
wc -l pipeline.yaml
# Expected: ~300 lines

# View the component list
python3 -c "
import yaml
with open('pipeline.yaml') as f:
    doc = yaml.safe_load(f)
components = doc.get('components', {})
print('Components:', list(components.keys()))
"
```

---

## Step 4 — Upload the Pipeline to KubeFlow

```bash
kfp pipeline upload pipeline.yaml --pipeline-name safety-ab-router
```

Expected output:

```
Pipeline safety-ab-router ID: a8f3c2d1-e4b5-6789-abcd-ef0123456789
```

Open the KFP UI in your browser to see the uploaded pipeline:

```bash
echo "Open: ${KFP_ENDPOINT}/#/pipelines"
```

Navigate to the **Pipelines** tab and click `safety-ab-router` to view the graph.

---

## Step 5 — Trigger a Pipeline Run

```bash
# The workshop provides a second model endpoint (Model B = a different checkpoint)
MODEL_B_ENDPOINT="${MODEL_ENDPOINT/granite-3-2b/granite-3-2b-v2}"

kfp run submit \
  --pipeline-name safety-ab-router \
  --experiment-name workshop-icad2026 \
  --run-name "icad-ab-run-$(date +%s)" \
  --param model_a_endpoint="${MODEL_ENDPOINT}" \
  --param model_b_endpoint="${MODEL_B_ENDPOINT}" \
  --param model_a_name="granite-3-2b" \
  --param model_b_name="granite-3-2b-v2" \
  --param safety_threshold=0.75 \
  --param evalhub_endpoint="${EVALHUB_ENDPOINT}" \
  --param evalhub_token="${EVALHUB_TOKEN}" \
  --param namespace="workshop-eval" \
  --param inference_service_name="granite-production"
```

Expected output:

```
Run icad-ab-run-1720950834 submitted.
Run ID: b9e1d2f4-a3c5-7890-bcde-f01234567890
View at: https://ds-pipeline-ui-workshop-eval.apps.cluster.example.com/#/runs/details/b9e1d2f4...
```

---

## Step 6 — Observe the Run in the KFP UI

Open the run URL printed in Step 5. In the graph view:

1. **Evaluate Model A** and **Evaluate Model B** start simultaneously (parallel).
2. When both complete, **Compare Scores & Decide** runs.
3. Based on the decision, **Route Traffic to Winner** runs and prints the routing action.

Click the **Route Traffic to Winner** node and open the **Logs** tab. You will see output like:

```
Routing 100% traffic to: model_a (https://granite-3-2b-workshop-eval.apps...)
  patched InferenceService 'granite-production' → model_a
```

Or if neither passes:

```
Decision: none wins.
Neither model passes safety threshold 0.75. Traffic unchanged.
```

---

## Step 7 — Read the Decision Artifact

Each pipeline run produces three artifacts: `eval_report` (×2) and `decision_report`. Click the **Compare Scores & Decide** node and open the **Artifacts** tab. Download `decision_report` and examine it:

```json
{
  "model_a": {"run_id": "ab-eval-a-pipeline-run", "score": 0.781, "verdict": "PASS", "passes": true},
  "model_b": {"run_id": "ab-eval-b-pipeline-run", "score": 0.743, "verdict": "PASS", "passes": true},
  "safety_threshold": 0.75,
  "winner": "model_a",
  "winning_score": 0.781,
  "reason": "Both pass threshold 0.75. Model A score (0.7810) >= Model B (0.7430)."
}
```

This JSON artifact is your governance evidence: a versioned, timestamped record of which model was selected and why.

---

## Checkpoint

```bash
# Pipeline must be uploaded
kfp pipeline list --output json | python3 -c "
import sys, json
pipes = json.load(sys.stdin).get('pipelines', [])
names = [p['name'] for p in pipes]
print('safety-ab-router:', 'FOUND' if 'safety-ab-router' in names else 'NOT FOUND')
"

# pipeline.yaml must exist
test -f pipeline.yaml && echo "pipeline.yaml: OK" || echo "pipeline.yaml: MISSING"
```

---

## Troubleshooting

**`kfp: command not found`**: Run `bash setup.sh` and then `source ~/.workshop-env`.

**Run fails immediately with `evaluate_model: ImportError`**: The component image may not have `evalhub` pre-installed. The `packages_to_install` field in `@dsl.component` should handle this at runtime. Check the pod logs with `oc logs -n workshop-eval <pod-name>`.

**KFP UI shows run as `Pending` for > 5 min**: Check that the KFP worker pods are running: `oc get pods -n workshop-eval -l app=ds-pipeline`. Alert a facilitator if any are `CrashLoopBackOff`.

**`route_traffic` fails with permission error**: The workshop service account may not have RBAC to patch InferenceServices. In a real deployment you would bind the `inference-service-patcher` ClusterRole. The pipeline prints a warning and continues — check the routing_result artifact for the no-change outcome.

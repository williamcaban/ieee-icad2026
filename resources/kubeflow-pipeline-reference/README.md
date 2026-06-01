# Section 06 — KubeFlow Pipeline A/B Routing

**Duration**: 10 minutes
**Mode**: Hands-on
**Position in agenda**: 1:30 – 1:40

---

## What You Will Do

Build and run a KubeFlow Pipelines (KFP) v2 pipeline that evaluates two model endpoints, compares their safety scores, and automatically routes production traffic to the safer model by patching an OpenShift InferenceService.

---

## Architecture

```
[evaluate_model_a] ──┐
                     ├──► [compare_scores] ──► [route_traffic]
[evaluate_model_b] ──┘
```

1. **`evaluate_model`**: Calls EvalHub API to run `safety-and-fairness-v1` against one endpoint, returns `(score, verdict)`.
2. **`compare_scores`**: Compares model A and model B scores; selects the winner (higher score + passing threshold).
3. **`route_traffic`**: Patches the production InferenceService to send 100% traffic to the winning model.

---

## Learning Objectives

- Read and understand a KFP v2 pipeline with `@dsl.component` decorators.
- Compile `pipeline.py` to `pipeline.yaml` using the KFP SDK.
- Upload the compiled pipeline to KubeFlow and trigger a run.
- Understand how evaluation-driven routing creates a safety gate in CI/CD.

---

## Self-Contained Design

`setup.sh` installs the `kfp` SDK, sources `~/.workshop-env`, and verifies that the KFP endpoint is reachable. No prior section must be complete — the pipeline evaluates models independently.

`reset.sh` deletes the uploaded pipeline and any pipeline runs from the workshop namespace.

---

## Files

| File | Purpose |
|------|---------|
| `README.md` | This file |
| `lab.md` | Step-by-step lab instructions |
| `setup.sh` | Installs kfp, sources env, verifies KFP endpoint |
| `reset.sh` | Deletes uploaded pipeline and runs |
| `pipeline.py` | KFP v2 pipeline source (compile this) |
| `route_config.yaml` | InferenceService YAML showing traffic weight field |

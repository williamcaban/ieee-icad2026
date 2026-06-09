# Section 02 — Local Safety Evaluation

**Duration**: 20 minutes
**Mode**: Hands-on — two parallel tracks
**Position in agenda**: 0:18 – 0:38

---

## What You Will Do

Run safety evaluations directly on your **laptop**, calling **OpenRouter** for
model inference. No Kubernetes access required.

**Track A — Static Benchmarks with lm-eval (12 min)**
Run BBQ (intersectional bias) and MMLU (ethics alignment) via the
`lm_evaluation_harness` provider through EvalHub local mode.

**Track B — Adversarial Red-Teaming with Garak (8 min)**
Run prompt injection and toxicity probes via the `garak` provider through
EvalHub local mode. Generates an HTML vulnerability report.

**Track C — LightEval Provider (optional, 4 min)**
Run TruthfulQA and WinoGender via the `lighteval` provider — demonstrating
that EvalHub orchestrates multiple frameworks through the same CLI interface.

---

## Why Local First?

Running evaluations locally is:
- **Fast to start** — no cluster provisioning needed
- **Transparent** — you see every API call and result
- **Reproducible** — the same commands work on any laptop with the `.venv`

In Section 03, you will submit the same evaluation logic to Kubernetes via
EvalHub, comparing the experience.

---

## Files

| File | Purpose |
|------|---------|
| `README.md` | This file |
| `lab.md` | Step-by-step instructions with exact commands |
| `setup.sh` | Verifies `.workshop-env` and sets up output directories |
| `reset.sh` | Removes local output files (results, garak reports) |
| `configs/lmeval-local.yaml` | lm-eval evalhub commands + fallback CLI + taxonomy mapping |
| `configs/garak-local.yaml` | Garak direct config for OpenRouter (probes, output, run settings) |
| `configs/lighteval-local.yaml` | LightEval evalhub commands + fallback CLI + taxonomy mapping |

# Section 02 — Local Safety Evaluation

**Duration**: 20 minutes
**Mode**: Hands-on — two parallel tracks
**Position in agenda**: 0:18 – 0:38

---

## What You Will Do

Run safety evaluations directly on your **laptop**, calling **OpenRouter** for
model inference. No Kubernetes access required.

**Track A — Static Benchmarks with lm-eval (12 min)**
Run `lm_eval` CLI against a free OpenRouter model to measure bias (BBQ) and
ethics alignment (MMLU). The evaluation logic runs locally; only inference
calls go to OpenRouter.

**Track B — Adversarial Red-Teaming with Garak (8 min)**
Run `garak` locally to probe the model for prompt injection and toxicity
elicitation vulnerabilities. Generates an HTML vulnerability report.

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
| `configs/lmeval-local.yaml` | lm-eval config for OpenRouter |
| `configs/garak-local.yaml` | Garak config for OpenRouter |

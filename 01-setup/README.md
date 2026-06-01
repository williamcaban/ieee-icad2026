# Section 01 — Environment Setup

**Duration**: 10 minutes
**Mode**: Hands-on
**Position in agenda**: 0:08 – 0:18

---

## What You Will Do

1. Activate the `uv` virtual environment (dependencies pre-installed by `uv sync`)
2. Set your OpenRouter API key in `.workshop-env`
3. Configure the `evalhub` CLI against the workshop cluster
4. Verify all four tools respond: `lm_eval`, `garak`, `evalhub`, `oc`

---

## Architecture: Local-First, then Kubernetes

```
Sections 01–02: Everything runs on your LAPTOP
  lm_eval ──────────► OpenRouter (cloud inference, free API)
  garak   ──────────► OpenRouter (adversarial probes)

Sections 03–04: Moves to the CLUSTER
  evalhub CLI ──────► EvalHub server (OpenShift/RHOAI)
                           │
                       LMEvalJob CRs ──► OpenRouter
```

The first two hands-on sections require no Kubernetes access.
You only need your laptop and an OpenRouter API key.

---

## Self-Contained Design

`uv sync` installs all dependencies (`lm-eval`, `garak`, `eval-hub-sdk`, `kfp`, etc.)
into `.venv` at the repo root. This section only configures credentials.

`reset.sh` clears the `.workshop-env` file and EvalHub CLI config.

---

## Files

| File | Purpose |
|------|---------|
| `README.md` | This file |
| `lab.md` | Step-by-step instructions |
| `setup.sh` | Configures env file and evalhub CLI |
| `reset.sh` | Clears env file and CLI config |

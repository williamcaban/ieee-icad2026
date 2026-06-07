# Section 01 — Environment Setup

**Duration**: 12 minutes · **Needs cluster?** No — laptop only  
**Position in agenda**: 0:10 – 0:22

---

## What You Will Do

1. Activate the `uv` virtual environment (dependencies pre-installed by `uv sync`)
2. Configure your model endpoint in `.workshop-env` (OpenRouter, Ollama, or vLLM)
3. Run `setup.sh` — starts `eval-hub-server` on `localhost:18080` and registers lm-eval and garak providers
4. Verify all tools respond: `lm_eval`, `garak`, `evalhub`

---

## Architecture

```
Your laptop (everything runs here)
  lm_eval ──────────► model endpoint (OpenRouter / Ollama / vLLM)
  garak   ──────────► model endpoint (adversarial probes)
  evalhub CLI ──────► eval-hub-server (localhost:18080)
  ```

No Kubernetes. No cluster credentials. No `oc` CLI.

---

## Files

| File | Purpose |
|------|---------|
| `README.md` | This file |
| `lab.md` | Step-by-step instructions |
| `setup.sh` | Starts eval-hub-server and registers lm-eval and garak providers |
| `reset.sh` | Clears `.workshop-env` and stops background servers |

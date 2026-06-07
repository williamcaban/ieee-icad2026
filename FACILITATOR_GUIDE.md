# Facilitator Guide — Guardrails Under Pressure

**IEEE ICAD 2026** · 105 minutes · All local — no Kubernetes cluster required  
*For workshop facilitators and teaching assistants.*

---

## Quick Reference — 105 minutes

| Start | Dur | Section | Key output |
|-------|-----|---------|------------|
| 0:00 | 10 min | **Opening presentation** | Context set; three-act arc + EvalHub + guardrails framing |
| 0:10 | 12 min | **01 — Setup** | `eval-hub-server` running; providers registered; `evalhub-mcp` installed |
| 0:22 | 14 min | **02 — Act 1 Track A** (BBQ + MMLU) | Bias scores in EvalHub; `baseline_summary.json` |
| 0:36 | 8 min | **02 — Act 1 Track B** (Garak) + **Guardrails Demo** | Adversarial probe baseline; NeMo Guardrails proxy running; guarded run compared |
| 0:44 | 10 min | **Break + Q&A** | MCP server verified; questions fielded |
| 0:54 | 18 min | **03 — Act 2: Novel Contribution** | IRR benchmark registered; `novel_results.json` |
| 1:12 | 23 min | **04 — Act 3: MCP Research Interface** | `comparison_plot.png`; `comparison_report.json` |
| 1:35 | 10 min | **Closing Discussion** | Kubernetes demo (pre-recorded); research checklist; Q&A |

> **Guardrails timing note:** The 8-minute guardrails demo is embedded in Act 1 Track B — start Garak running, then demo the guardrail proxy while Garak executes, and re-run the probe against the guarded endpoint as Garak finishes. If the room is behind, facilitate the demo as a live presenter walkthrough (3 min) rather than participant hands-on.


---

## Pre-Workshop Checklist (48 hours before)

### Environment validation

- [ ] Clone the workshop repo: `git clone https://github.com/williamcaban/ieee-icad2026.git`
- [ ] Run `uv sync && source .venv/bin/activate`
- [ ] Edit `.workshop-env` — set `MODEL_ENDPOINT`, `MODEL_NAME`, and your API key (see Model Endpoint Options below)
- [ ] Run `bash 01-setup/setup.sh` end-to-end and verify no errors
- [ ] Confirm `evalhub health` returns `{"status": "healthy"}`
- [ ] Confirm `evalhub providers list` shows `lm_evaluation_harness` and `garak`
- [ ] Test a real eval: `evalhub eval run --name "act1-bbq-baseline" --provider lm_evaluation_harness --benchmark bbq_generate --param limit=2 --wait`
- [ ] Verify `evalhub-mcp --version` works (installed by `01-setup/setup.sh`, or `brew install eval-hub/evalhub/evalhub-mcp`)
- [ ] Start `evalhub-mcp` manually and verify `curl http://localhost:3001/health` responds (see Act 3 MCP server pre-flight below)
- [ ] Run `uv run pytest tests/ -v` — all unit tests should pass; smoke tests may skip if HF offline

### Pre-recorded Kubernetes demo

The closing segment references production-scale deployment on Kubernetes (RHOAI). Since no cluster is provisioned during this workshop, prepare a short (2–3 min) screen recording:

- [ ] Submit an eval job to a live EvalHub on RHOAI: `evalhub eval run --benchmark bbq_generate ...`
- [ ] Show the RHOAI Dashboard Evaluations tab with the LMEvalJob running
- [ ] Show `evalhub eval results <job-id>` returning scores from the cluster
- [ ] Point out: same benchmark IDs, same CLI commands, same `mcp_client.py` notebook — only `base_url` changes

Upload as an unlisted video or keep the file available for offline playback.

### Slides

- [ ] Render all slides: `for f in slides/0*.md; do marp "$f"; done`  
  Or open in Marp Desktop and export to PDF/HTML for presentation.
- [ ] Verify slide 8 in `00-opening.md` (Architecture) shows no cluster references in the local diagram
- [ ] Have `resources/owasp-llm-top10-quick-ref.md` ready to share as a handout for Act 1
- [ ] Have `resources/governance-checklist.md` ready for the closing segment

---

## Model Endpoint Options

The workshop is designed for **any OpenAI-compatible chat completions endpoint**. Configure `MODEL_ENDPOINT` and `MODEL_NAME` in `.workshop-env` before the session begins.

| Provider | Notes | Example `.workshop-env` values |
|----------|-------|-------------------------------|
| **OpenRouter** (recommended for workshops) | Free tier, no local GPU, cloud inference | `MODEL_ENDPOINT=https://openrouter.ai/api/v1` · `MODEL_NAME=liquid/lfm-2.5-1.2b-instruct:free` · `OPENROUTER_API_KEY=sk-or-...` |
| **Ollama** (offline / no API key) | `ollama pull llama3.2:3b` before the session; `ollama serve` must be running | `MODEL_ENDPOINT=http://localhost:11434/v1` · `MODEL_NAME=llama3.2:3b` · `OPENAI_API_KEY=ollama` |
| **vLLM** (local or institutional) | Start vLLM server pointing at a quantised model | `MODEL_ENDPOINT=http://localhost:8000/v1` · `MODEL_NAME=<model-id>` |

**Important for Ollama:** lm_eval uses `OPENAI_API_KEY` as the Authorization header. Ollama accepts any non-empty value. Set it to `"ollama"` to avoid auth errors.

**Participant API keys:** If using OpenRouter, have participants create a free account at openrouter.ai/keys before the workshop. The free tier allows 20 req/min — sufficient for `limit=5` evaluations with pacing.

---

## Opening Presentation (10 min)

Slides: `slides/00-opening.md`

### Delivery notes by slide

**Slides 1–2 (Title, Quote):** Set tone. 30–60 seconds each.

**Slide 3 — Production failures (3 columns):** Ask: "Has anyone seen a model behave differently in production than during evaluation?" Wait for one or two responses before moving on.

**Slide 4–5 — HELM stat + Regulatory scope:** Emphasise that aggregate scores hide subgroup failures, and that regulators now require reproducible evidence — not one-time snapshots.

**Slide 6 — Replicability:** Key line: "If you can't reproduce the baseline, you have no baseline — you have a claim." Give this a beat.

**Slide 7 — Researcher's dilemma:** Frame as what participants would personally need to do to publish a novel safety benchmark. This is not a tutorial — it is a research workflow they are executing.

**Slides 8–11 (EvalHub, Guardrails, Collections, Pass/Fail):** Move through these at pace — they introduce the platform. Participants will experience the concepts hands-on. Spend extra time on the Guardrails slides; they explain the workshop title.

**Slides 13–14 (Architecture + Kubernetes):** Emphasise "no cluster today." Say: "We have a pre-recorded demo of the cluster workflow for the closing segment. Today is entirely local."

**Slide 16 — Start Section 01:** Give participants 30 seconds to open a terminal before moving on.

---

## Section 01 — Setup (12 min)

Slides: `slides/01-setup-slides.md`  
Lab: `01-setup/lab.md`

### Common issues and fixes

| Issue | Likely cause | Fix |
|-------|-------------|-----|
| `lm_eval: command not found` | venv not activated | `cd <repo-root> && source .venv/bin/activate` |
| `garak: command not found` | Same | Same |
| `MODEL_ENDPOINT not set` | `.workshop-env` not edited | Edit `.workshop-env`, set endpoint and key, re-run `bash setup.sh` |
| `eval-hub-server` fails to start | Port 18080 in use | `lsof -ti:18080 \| xargs kill -9`, then re-run |
| `evalhub-mcp` not found | Homebrew not installed | `bash 04-compare/setup.sh` runs a GitHub release fallback |
| `evalhub health` times out | Server still starting | Wait 10 s and retry; check `/tmp/evalhub-local.log` |
| Ollama not responding | `ollama serve` not started | `ollama serve &` in another terminal |

---

## Act 1 — Baseline Replication (22 min)

Slides: `slides/02-local-eval-slides.md`  
Lab: `02-local-evaluation/lab.md`

### Timing guide

| Sub-section | Duration |
|-------------|----------|
| Track A — BBQ bias (`bbq_generate`, limit=5) | 7 min running + 3 min interpretation |
| Track A — MMLU ethics (`mmlu_business_ethics_generative`) | 4 min running |
| Track B — Garak adversarial probes | 6 min running + 2 min discussion |

Advanced participants can run Track A and B in parallel. Direct them to start Track B (`evalhub eval run --provider garak ...`) while Track A is running.

### Key teaching moments

**BBQ score = 0.20, amb_bias_score = 0.33:** Ask: "What does this mean for a hiring tool?" Let one person answer. Then: "This is the community-accepted benchmark. Your baseline is positioned relative to what peer literature uses — that's the point of replication."

**Garak adversarial output:** Warn participants before they run it. The model will produce harmful text — this is expected, intentional, and is exactly the point of adversarial evaluation. The probe is peer-reviewed and reproducible.

**"Why these benchmarks?"** — BBQ (Parrish et al. 2022), MMLU (Hendrycks et al. 2021), and Garak (Derczynski et al. 2024) are each cited in peer-reviewed work. Running them against your model gives you a baseline position relative to the existing literature.

### Rate limiting (OpenRouter free tier)

If participants see `429 Too Many Requests`:
- Reduce limit: add `--param limit=3`
- The free tier resets every 60 seconds; wait and retry
- If the whole room hits limits simultaneously, stagger starts by 30 seconds

### Recovery

| Problem | Recovery |
|---------|---------|
| `eval-hub-server` stopped | `bash 01-setup/setup.sh` |
| Garak hangs | Kill the process; use `--param generations=1` |
| HuggingFace dataset download fails | Check internet; use `--param limit=1`; check `HF_DATASETS_OFFLINE` env var |
| BBQ task not found | Verify `lm-eval>=0.4` installed; `lm_eval --tasks list \| grep bbq` |

---

## Guardrails Demo — embedded in Act 1 Track B (8 min)

Slides: none (live walkthrough)  
Lab: `guardrails/lab.md`

Run this immediately after or alongside Garak Track B. The Garak evaluation takes 3–5 minutes — start the guardrail proxy while it runs.

### Timing within the 8-minute window

| Step | Duration |
|------|----------|
| Start NeMo Guardrails proxy (`bash guardrails/setup.sh`) | 2 min (includes install if needed) |
| Test PII rail with `curl` — show blocked response | 1 min |
| Re-run the same Garak probe against `$GUARDED_ENDPOINT` | 3 min |
| Compare bare vs guarded result in EvalHub | 2 min |

### Key teaching moment

> "In Act 1 we found a vulnerability. We added guardrails. Now we're running the exact same systematic probe against the guarded endpoint. This is 'Guardrails Under Pressure' — not adding guardrails and hoping, but *evaluating* them with the same tool that found the problem."

### If behind on time

Collapse to a 3-minute facilitator demo: start the proxy, run one `curl` PII test live, show the blocked response. Participants can run `bash guardrails/setup.sh` independently and follow `guardrails/lab.md` during the break.

### Recovery

| Problem | Recovery |
|---------|---------|
| `nemoguardrails` install slow | Pre-install: `uv pip install "nemoguardrails>=0.9"` before the session |
| Port 18090 in use | `bash guardrails/reset.sh` then re-run `bash guardrails/setup.sh` |
| Garak probe still passes through guardrail | Check `GUARDED_ENDPOINT` is set to `:18090`, not `:18080` |

---

## Break (10 min)

During the break:
- [ ] Verify `evalhub health` — server still healthy
- [ ] Verify `evalhub-mcp` is available for Act 3: `evalhub-mcp --version`
- [ ] Field any architecture or concept questions
- [ ] Confirm participants who fell behind have at least finished Track A BBQ scores

---

## Act 2 — Novel Contribution (18 min)

Slides: `slides/03-irr-slides.md`  
Lab: `03-irr-local/lab.md`

### Timing guide

| Step | Duration |
|------|----------|
| Inspect annotation dataset | 2 min |
| Run `compute_irr.py` + read output | 4 min |
| Register benchmark (no `--dry-run`) | 3 min |
| Run novel benchmark via `evalhub eval run` | 6 min |
| Checkpoint + discussion | 3 min |

### Key teaching moments

**The α value (0.81):** Walk through the output line by line with the group.
- α = 0.81: "This benchmark meets the quality bar. We register it."
- κ (Annotator 2 vs 3) = 0.38: "These two annotators see the label boundary differently. In a real annotation pipeline, you would run a calibration session before annotating more data."

**The research contribution framing:** Say explicitly: "You just proposed that α ≥ 0.67 is the registration threshold. That is a methodological contribution. Publishing that threshold, with the evidence, is what makes the benchmark citable — not just the score."

**Registration without `--dry-run`:** This is the critical change from the previous session format. The benchmark must be registered — not just previewed — so Act 3 can query it via MCP.

```bash
# Critical: no --dry-run
python3 scripts/register_benchmark.py

# Verify registration succeeded
evalhub benchmarks list    # should show icad2026-irr-safety
```

### Recovery

| Problem | Recovery |
|---------|---------|
| `irr_report.json` missing | Run `python3 scripts/compute_irr.py` first |
| `register_benchmark.py` fails | Check `evalhub health`; verify JSON is valid |
| Novel benchmark run fails | Verify benchmark registered: `evalhub benchmarks list` |
| α below 0.67 | Step 4 (optional): modify one CSV row to observe exclusion, then `bash reset.sh` |

---

## Act 3 — MCP Research Interface (23 min)

Slides: `slides/04-mcp-slides.md`  
Lab: `04-compare/lab.md`

### Timing guide

| Step | Duration |
|------|----------|
| Setup + verify MCP server | 3 min |
| Open notebook or script; walk through `mcp_client.py` | 3 min |
| Cell 1: configure approaches | 2 min |
| Cells 2–4: connect, submit, poll | 8 min |
| Cells 5–8: extract, table, plot, export | 5 min |
| Discussion | 2 min |

### The `mcp_client.py` walk-through

Before participants start, put `mcp_client.py` on the projector:

> "This is the entire MCP client. Fifty lines. No SDK, no async library, no framework. It is `requests` and JSON-RPC 2.0. You could have written this yourself — and after today, you can adapt it to any EvalHub instance."

This is the central claim of Act 3: MCP is just HTTP + JSON. Researchers who understand HTTP understand MCP.

### Notebook vs. standalone script

| | Notebook (`compare_approaches.ipynb`) | Script (`compare_approaches.py`) |
|-|---------------------------------------|----------------------------------|
| Best for | Interactive exploration, per-cell inspection | Participants without Jupyter; CI/CD |
| Output | Same files (`comparison_plot.png`, `comparison_report.json`) | Same files |
| How to run | Open in JupyterLab or VS Code; run all cells | `python3 compare_approaches.py` |

Both are provided. Participants choose whichever fits their workflow.

### MCP server pre-flight

Before Act 3 starts, verify `evalhub-mcp` is available:

```bash
evalhub-mcp --version
# If not installed: brew install eval-hub/evalhub/evalhub-mcp
```

Start it pointing at the local eval-hub-server:

```bash
# Create local config and start (from repo root)
mkdir -p ~/.evalhub
cat > ~/.evalhub/mcp-local.yaml <<EOF
base_url: "http://localhost:18080"
token: ""
tenant: "workshop"
transport: "http"
host: "localhost"
port: 3001
EOF
evalhub-mcp --config ~/.evalhub/mcp-local.yaml &
curl http://localhost:3001/health
```

### Recovery

| Problem | Recovery |
|---------|---------|
| `evalhub-mcp` not found | `brew install eval-hub/evalhub/evalhub-mcp` or download from GitHub releases |
| MCP server not responding | Re-run the start commands above; check port 3001 is free |
| `icad2026-irr-safety` not found | Participant skipped Act 2 — run `cd 03-irr-local && python3 scripts/register_benchmark.py` |
| `matplotlib` import fails | `uv sync` in repo root |
| Score shows `None` | Check job status directly: `python3 -c "from mcp_client import EvalHubMCPClient; m=EvalHubMCPClient(); print(m.get_job_status('<job-id>'))"`|

---

## Closing Discussion (10 min)

### Agenda

1. **Pre-recorded Kubernetes demo** (3 min): show the cluster workflow — same benchmark IDs, same CLI commands, same `mcp_client.py` notebook. Emphasise that `base_url` is the only change.

2. **Research publication checklist** (3 min): walk through `resources/governance-checklist.md`. Map each workshop artifact to a claim that can appear in a methods section or supplementary material:
   - `baseline_summary.json` → "We replicated [benchmark] using [lm-eval version] against [model]"
   - `irr_report.json` → "Labels meet the α ≥ 0.67 threshold (α = [value])"
   - `comparison_report.json` + `comparison_plot.png` → "Figure N shows our novel approach vs. baseline on the same model and infrastructure"

3. **Q&A** (4 min)

### Common closing questions

**"Can I use my own model?"** Yes — any OpenAI-compatible endpoint. Change `MODEL_ENDPOINT` and `MODEL_NAME` in `.workshop-env`. No code changes.

**"Can I use my own annotation dataset?"** Yes — replace `data/annotations-sample.csv` with any CSV that has the same column structure (`text_id`, `text`, `annotator_1`, `annotator_2`, `annotator_3`). The α threshold is configurable at the top of `compute_irr.py`.

**"Can I add more annotators?"** Yes — add columns `annotator_4`, etc. The `compute_irr.py` script uses all columns that match the `annotator_*` pattern.

**"How do I run this at scale against my institution's cluster?"** The pre-recorded demo covers this. The key: `evalhub config set base_url <cluster-url>` switches the CLI from local to cluster. The `mcp_client.py` notebook changes one line: `EvalHubMCPClient(url="<cluster-url>")`.

**"Is the MCP server stable?"** The binary (`evalhub-mcp`) is stable. For production, run it as a container and configure your MCP client (Claude Code, VS Code, Cursor) to point at it.

---

## Participant Take-Aways

Every participant leaves with:

- **Working code they ran today** — notebooks, scripts, and configs in the workshop repo
- `compare_approaches.ipynb` / `compare_approaches.py` — reusable MCP comparison notebook
- `mcp_client.py` — 50-line MCP client adaptable to any EvalHub instance
- `compute_irr.py` — IRR analysis tool for their own annotation datasets
- `comparison_report.json` + `comparison_plot.png` — their actual results
- `resources/governance-checklist.md` — mapping workshop artifacts to regulatory evidence

**Repo:** `github.com/williamcaban/ieee-icad2026` — clone, adapt, run against your own models.

# Section 00 — Opening Presentation Guide

**Duration**: 8 minutes · **Mode**: Presenter-led · **Slides**: `slides/00-opening.md`

Render slides: `marp slides/00-opening.md --output slides/00-opening.html`

---

## Delivery Notes

The opening sets up *why* the work matters before participants touch the keyboard. Keep it honest: the tools are real, the vulnerabilities are real, the regulatory requirements are real.

Do not rush Slides 1–2 (problem framing). Participants who understand the problem engage more during the lab.

---

## Slide-by-Slide Script

### Slide 1 — Title (30 seconds)

> "This is a hands-on workshop. Every section has a lab. You'll run real evaluations against a real model — the outputs are live, not precomputed. Everything you produce today maps to something you'd do in a production deployment."

Set the tone: this is practical, not theoretical.

---

### Slide 2 — Three Failure Modes (90 seconds)

Walk through the three production failure modes:

**Bias that hides in aggregate scores.** A model scores 72% on a fairness benchmark. Looks fine. But on the specific demographic slice your users represent — 54%. Standard benchmarks oversample majority groups. You don't know until you look at subgroup scores.

**Attacks that standard benchmarks don't cover.** OWASP LLM Top 10 defines 10 threat categories. Most safety suites cover 3-4 of them. Garak covers all 10 plus 80+ sub-probes.

**Evaluation that happens once.** A score at model release means nothing at month 6. You need an automated gate that evaluates on every update and blocks deployments that regress.

---

### Slide 3 — The Statistic (30 seconds)

> "11 out of 30 frontier models in the 2024 Stanford HELM study showed measurable demographic bias on at least one WinoGender subset — even though their aggregate fairness scores looked acceptable."

Pause. Let this land.

> "This is why subgroup evaluation matters. And it's why Section 02 uses BBQ — a benchmark specifically designed to surface subgroup failures."

---

### Slide 4 — What You'll Build (60 seconds)

Walk through the four sections briefly. Emphasise:
- Sections 01–03 run entirely on the laptop. No cluster access needed.
- Section 04 uses the same `evalhub` CLI — only the backend changes.
- Every output from today maps to a compliance artifact.

---

### Slide 5 — The Tool Stack (60 seconds)

Use the "think of it as" column. Participants who know ML but not security will anchor on:
- lm-eval = pytest for models ✓
- garak = fuzzing for prompts ✓
- eval-hub-server = MLflow for safety evals ✓

If anyone asks about specific tools, defer to the relevant section's lab.md.

---

### Slide 6 — Architecture (90 seconds)

Draw attention to the key insight: **the CLI is the same in both phases.** The only change between local and cluster is `evalhub config set base_url`.

This is not a demo tool that you'd throw away in production. It's the production pattern, run locally first to reduce the barrier.

If you have a whiteboard, sketch the two-phase diagram:

```
Laptop phase (01-03):  evalhub CLI → localhost:18080 → subprocess → OpenRouter
Cluster phase (04):    evalhub CLI → RHOAI cluster  → LMEvalJob pod → OpenRouter
                                        ↑
                              Same commands. Different backend.
```

---

### Slide 7 — Safety Frameworks (60 seconds)

Keep this fast. Participants will use the quick-ref cards in `resources/`.

Key point: these frameworks are not bureaucracy — they're the vocabulary that lets different teams (ML, security, legal, compliance) talk about the same risks without talking past each other.

> "When you map a garak finding to OWASP LLM01 and CWE-77, a security engineer who has never heard of garak immediately understands what you found."

---

### Slide 8 — Ground Rules (30 seconds)

Read them. Emphasise `reset.sh` — removing the fear of breaking things is essential for hands-on learning.

> "If something doesn't work — run `bash reset.sh`, then `bash setup.sh`. That gets you back to a clean state in under a minute."

---

### Slide 9 — Start Section 01

> "Open your terminal, `cd` to the workshop repo, `source .venv/bin/activate`, then `cd 01-setup && bash setup.sh`. Read the output — it tells you exactly what's happening. We'll reconvene in 10 minutes."

---

## Pre-Workshop Checklist (Facilitator)

Before the event:
- [ ] Run `bash setup/platform-setup.sh` on the cluster (creates namespace, deploys EvalHub)
- [ ] Verify `evalhub health` against the cluster returns healthy
- [ ] Confirm `workshop-eval` namespace exists and `workshop-sa` has RBAC
- [ ] Test `evalhub eval run` end-to-end against the cluster (Section 04 pattern)
- [ ] Have the RHOAI Dashboard URL ready to paste
- [ ] Confirm OpenRouter free tier is not rate-limited (test with `liquid/lfm-2.5-1.2b-instruct:free`)
- [ ] Share `.workshop-env` template with cluster endpoint pre-filled (removes Step 3 from Section 01 for participants)

## Common Opening Questions

**"What model are we using?"** — `liquid/lfm-2.5-1.2b-instruct:free` via OpenRouter. Small, fast, and exhibits real bias and injection vulnerabilities — which makes the findings in Section 02 meaningful rather than trivial.

**"Does EvalHub work with any model?"** — Any endpoint that speaks the OpenAI chat completions API. vLLM, Ollama, LiteLLM, the major cloud providers — all work without code changes.

**"Do I need to know Kubernetes?"** — For Sections 01-03, no. Section 04 introduces two `oc` commands, both of which are in the lab.md with expected outputs.

**"Is garak production-ready?"** — Yes. 0.15+ is used in production red-teaming at several enterprises and AI safety organisations. It covers systematic automated probe coverage, not a replacement for a full manual red-team engagement.

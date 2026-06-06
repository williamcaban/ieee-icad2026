# Guardrails Demo — Putting Guardrails Under Pressure

> **Where you are:** `[ Act 1: Baseline ]` → `[ ● Guardrails Demo ]` → `[ Act 2: Novel ]`

**Duration**: ~8 minutes · **Runs after**: Act 1 Garak probes · **Needs cluster?** No

---

## Why This Matters

In Act 1 you ran Garak's `promptinject.HijackHateHumans` probe and saw the bare model produce unsafe output. You now have a documented vulnerability.

The natural next question: **if you add guardrails, do they actually hold up under the same systematic evaluation?**

This is what "Guardrails Under Pressure" means — not adding guardrails and hoping for the best, but *evaluating* them with the same rigor you used to find the vulnerability.

```
Act 1 result:
  Bare model  →  promptinject probe PASSES  →  "I hate humans."

Guardrail demo:
  Guarded model  →  same probe  →  blocked by jailbreak rail  →  FAIL (good!)
```

---

## What You're Running

A **NeMo Guardrails proxy** — an OpenAI-compatible server on `localhost:18090` that sits between the evaluation tool and your model:

```
lm_eval / garak / evalhub CLI
          │
          ▼
  NeMo Guardrails (localhost:18090)
          │
    ┌─────┴──────────────────────────────┐
    │  Rail 1: PII Detection             │
    │  Rail 2: Jailbreak Detection       │
    └─────┬──────────────────────────────┘
          │ (clean requests only)
          ▼
  Real model endpoint (OpenRouter / Ollama / vLLM)
```

The Colang rules live in `guardrails/config/rails.co` — open that file and read it. It is the entire guardrail logic: ~30 lines of readable, auditable policy.

---

## Step 1 — Start the Guardrails Proxy (2 min)

```bash
cd guardrails
bash setup.sh
```

Expected output:
```
[OK]  nemoguardrails: 0.9.x
[OK]  Config written to guardrails/config/config.yml
[OK]  NeMo Guardrails proxy ready at http://localhost:18090/v1

  Guarded endpoint:  http://localhost:18090/v1
  Bare endpoint:     https://openrouter.ai/api/v1

  Rails active:
    ✦ PII Detection  — blocks messages sharing personal information
    ✦ Jailbreak Rail — blocks prompt-injection / instruction-override attempts
```

```bash
# Set the guarded endpoint for the next steps
export GUARDED_ENDPOINT="http://localhost:18090/v1"
```

---

## Step 2 — Verify the PII Rail (2 min)

Send a message containing personal information directly via curl:

```bash
curl -s http://localhost:18090/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${OPENAI_API_KEY}" \
  -d '{
    "model": "'"${MODEL_NAME}"'",
    "messages": [{"role": "user", "content": "Hi, my email is test@example.com and I need help."}]
  }' | python3 -m json.tool
```

Expected: the guardrail intercepts and returns the PII refusal — the real model is never called.

Now send a clean message:
```bash
curl -s http://localhost:18090/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${OPENAI_API_KEY}" \
  -d '{
    "model": "'"${MODEL_NAME}"'",
    "messages": [{"role": "user", "content": "What is the capital of France?"}]
  }' | python3 -c "import json,sys; r=json.load(sys.stdin); print(r['choices'][0]['message']['content'])"
```

Expected: a real response from the model ("Paris"). The guardrail passed the clean request through.

---

## Step 3 — Run Garak Against the Guarded Endpoint (3 min)

Run the same adversarial probe that succeeded against the bare model in Act 1:

```bash
evalhub eval run \
  --provider garak \
  --benchmark "promptinject.HijackHateHumans" \
  --model-url "${GUARDED_ENDPOINT}" \
  --model-name "${MODEL_NAME}" \
  --param generations=3 \
  --name "guarded-promptinject" \
  --wait
```

Compare results:

```bash
# Bare model result (from Act 1):
evalhub eval results <bare-job-id>

# Guarded model result (just ran):
evalhub eval results guarded-promptinject
```

The jailbreak rail should catch the prompt-injection attempts. **The guardrail is now under pressure from the same systematic evaluation that found the original vulnerability.**

---

## Step 4 — Read the Rails (1 min)

```bash
cat guardrails/config/rails.co
```

This is the **entire policy** — 30 lines of Colang. Two things to observe:

1. **Rail 1 (PII)** — uses embedding-based intent matching. The examples you see are training signals for a small intent classifier, not keyword patterns. That means "please send this to me at j.smith@corp.com" will also be caught, even though that exact phrase isn't listed.

2. **Rail 2 (Jailbreak)** — same approach. "Forget your previous instructions" will be caught even without an exact match.

This is why Colang is more robust than keyword filtering — and why it's easier to audit than a regex or a secondary LLM call.

---

## What This Produces

- Two EvalHub runs: **bare model** and **guarded model** against the same Garak probe
- In Act 3, the MCP comparison notebook can compare these two configurations
- `guardrails/config/rails.co` is the auditable policy artifact

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `nemoguardrails: command not found` | `uv pip install "nemoguardrails>=0.9"` |
| Server starts but probe still passes | Check `/tmp/guardrails-proxy.log`; verify `GUARDED_ENDPOINT` is set to `:18090` |
| `Connection refused` on port 18090 | `bash setup.sh` to restart |
| Model returns error through guardrail | Guardrail is proxying; check `OPENAI_API_KEY` and `MODEL_ENDPOINT` |

---

## Colang Reference — Extending the Rails

To add a new rail, append to `guardrails/config/rails.co` and restart:

```colang
define user ask about competitors
  "tell me about your competitors"
  "what other companies do what you do"
  "compare yourself to OpenAI"

define bot refuse competitor questions
  "I'm not set up to discuss other AI providers."

define flow check competitor topic
  user ask about competitors
  bot refuse competitor questions
```

Then restart: `bash guardrails/reset.sh && bash guardrails/setup.sh`

The rail takes effect immediately on restart — no retraining, no redeployment.

# Workshop Takeaways — What To Do Next

Practical next steps by role. Every pattern here was demonstrated in the workshop.

---

## For Researchers

**Replicate this workshop with your own model**

Every evaluation in this workshop is parameterised by `MODEL_ENDPOINT` and `MODEL_NAME`. Point these at any OpenAI-compatible endpoint — OpenRouter, Ollama, vLLM, your institution's inference server — and you have a reproducible baseline against your own model. No code changes required.

**Benchmark your own annotation dataset**

`compute_irr.py` works with any CSV that has `text_id`, `text`, and `annotator_N` columns:

```bash
# Replace the sample data with your own annotation file
cp your-annotations.csv 03-irr-local/data/annotations-sample.csv
python3 03-irr-local/scripts/compute_irr.py
```

The α threshold (0.67) and the exclusion logic are configurable at the top of the script. The output `irr_report.json` is a citable reliability artifact.

**Report IRR in your benchmark papers**

Include Krippendorff's α alongside the label distribution in any dataset card or paper that uses human-annotated labels. Reviewers increasingly require this for papers that depend on annotation quality. The `irr_report.json` format produced here is directly referenceable.

**Use the MCP notebook as a comparison template**

`04-compare/compare_approaches.py` and `compare_approaches.ipynb` are designed as reusable templates. Change `APPROACH_A` and `APPROACH_B` in Cell 1 to compare any two benchmarks — or any two model configurations (e.g., fine-tuned vs base, guarded vs unguarded). The plot and export cells stay unchanged.

**Validate guardrail effectiveness systematically**

The guardrail demo pattern — run the same Garak probe against the bare model, add guardrails, re-run — is a repeatable evaluation methodology. Adapt `guardrails/config/rails.co` to your domain and use EvalHub to produce comparable run records for both configurations.

**Contribute a benchmark to EvalHub**

Write a provider YAML with your benchmark's metadata (id, name, metrics, pass threshold). Write an adapter in `adapters/` that reads the job spec and runs your evaluation code. Submit a pull request to [eval-hub/eval-hub-contrib](https://github.com/eval-hub/eval-hub-contrib).

---

## For ML / Safety Engineers

**Add evaluation to your CI/CD pipeline**

`evalhub eval run` exits `0` if all benchmarks pass their thresholds, `1` if any fail. Wire it into your deployment pipeline:

```yaml
# GitHub Actions example
- name: Safety gate
  run: |
    evalhub eval run \
      --collection safety-and-fairness-v1 \
      --model-url ${{ env.MODEL_ENDPOINT }} \
      --model-name ${{ env.MODEL_NAME }} \
      --wait
```

**Use the local server for fast iteration**

During model development, run evaluations against `localhost:18080` before submitting to a cluster. The local server gives immediate feedback at `limit=5` without consuming shared resources.

**Extend the guardrail rails for your domain**

Open `guardrails/config/rails.co`. Add a new `define user` / `define bot` / `define flow` block for your domain-specific policy. Restart the proxy (`bash guardrails/reset.sh && bash guardrails/setup.sh`). The new rail is live immediately — no retraining.

**Build a new evaluation adapter**

Copy `adapters/lm_eval/` into a new directory. Implement `run_benchmark_job` with calls to your evaluation framework. Register a provider YAML in `config/providers/`. The `eval-hub-server` loads it on restart. This is the pattern used by lm-eval and garak in this workshop.

**Use AVID taxonomy to categorise findings**

Map Garak probe results to AVID codes when filing issues or writing reports:
- Ethics/E0101 → group fairness failures (BBQ bias)
- Security/S0201 → prompt injection (Garak LLM01)
- Security/S0403 → model output integrity failures

This makes findings interoperable with the AI vulnerability database and easier for other teams to act on.

---

## For Everyone — Three Commands to Remember

```bash
# Run a safety evaluation
evalhub eval run \
  --name "act1-bbq-baseline" \
  --provider lm_evaluation_harness \
  --benchmark bbq_generate \
  --model-url "${MODEL_ENDPOINT}" \
  --model-name "${MODEL_NAME}" \
  --wait

# Read the results
evalhub eval results <job-id>

# Check server health (local or cluster — same command)
evalhub health
```

Switch between local and cluster by changing one setting:

```bash
evalhub config set base_url http://localhost:18080         # local
evalhub config set base_url https://<your-cluster-route>  # cluster
```

---

## Useful Links

- **EvalHub documentation**: https://eval-hub.github.io/
- **EvalHub MCP server**: https://eval-hub.github.io/mcp/
- **eval-hub-contrib** (adapters and benchmarks): https://github.com/eval-hub/eval-hub-contrib
- **NeMo Guardrails**: https://github.com/NVIDIA/NeMo-Guardrails
- **OWASP LLM Top 10**: https://owasp.org/www-project-top-10-for-large-language-model-applications/
- **AVID taxonomy**: https://avidml.org/taxonomy/
- **OpenRouter free models**: https://openrouter.ai/models?q=free
- **Workshop repo**: https://github.com/williamcaban/ieee-icad2026

# Workshop Takeaways — What To Do Next

Practical next steps by role. Every pattern here was demonstrated in the workshop — no new concepts required.

---

## For ML Engineers

**Add evaluation to your CI/CD pipeline**

The `evalhub eval run` command has an exit code: `0` = all benchmarks passed their thresholds, `1` = one or more failed. Wire this into your deployment pipeline as a gate:

```yaml
# GitHub Actions example
- name: Safety gate
  run: |
    evalhub eval run \
      --collection safety-and-fairness-v1 \
      --model-url ${{ env.MODEL_ENDPOINT }} \
      --model-name ${{ env.MODEL_NAME }} \
      --wait
    # Fails the pipeline if any benchmark is below threshold
```

**Version your evaluation policy alongside your model**

The `lmevaljob-cr.yaml` file from Section 04 is a Kubernetes manifest. Check it into the same Git repository as your model deployment manifests. When a security team asks "what thresholds did you evaluate against for model version X.Y.Z?" — `git log` gives the answer.

**Use the local eval-hub-server for development**

During model iteration, run evaluations locally (Sections 01-03 pattern) before submitting to the cluster. The local server gives immediate feedback without consuming cluster resources.

**Template for a new evaluation framework**

Copy `adapters/lm_eval/` into a new directory. Replace the `run_benchmark_job` body with calls to your framework. Register the provider YAML in `config/providers/`. The `eval-hub-server` picks it up on restart.

---

## For Researchers

**Benchmark your own annotation data**

`compute_irr.py` works with any CSV that has `text_id`, `text`, and `annotator_N` columns. Replace `03-irr-local/data/annotations-sample.csv` with your own annotation file. The α computation and exclusion logic run immediately.

**Cite IRR in benchmark papers**

When publishing a new benchmark, include the Krippendorff's α in the dataset card alongside the label distribution. Reviewers increasingly expect this for any paper that depends on human annotation quality.

**Contribute a benchmark to EvalHub**

Write a provider YAML with your benchmark's metadata (id, name, metrics, pass threshold). Write an adapter in `adapters/` that reads the job spec and runs your evaluation code. Submit a pull request to [eval-hub/eval-hub-contrib](https://github.com/eval-hub/eval-hub-contrib).

**Use the AVID taxonomy to categorise your findings**

When publishing bias or safety findings, map them to AVID codes (Ethics/E0101 for group fairness, Security/S0201 for prompt injection, etc.). This makes your work interoperable with the AI vulnerability database and easier for practitioners to find.

**Track model behaviour across versions**

`evalhub eval results --format json` gives you a structured result you can store in a time series. Compare `acc` on `bbq_generate` across model versions to detect regression or improvement. The cluster's persistent storage means historical results are always accessible.

---

## For Consultants

**Build a client evaluation package**

For a client engagement, configure:
1. A custom collection YAML with the benchmarks relevant to the client's use case and their risk tolerance as thresholds
2. An IRR-validated custom benchmark from the client's domain (if standard benchmarks don't cover it)
3. A governance export (Section 04 pattern) mapped to the specific regulations the client faces

The collection YAML *is* the risk policy document. It's version-controlled, human-readable, and machine-executable.

**Map findings to client compliance frameworks**

The `resources/governance-checklist.md` shows EU AI Act and NIST AI RMF mappings. Extend this for other frameworks (ISO 42001, NIST CSF) by adding rows to the table. The artifact types remain the same; only the regulatory citations change.

**Demo the local server without infrastructure**

For a proof-of-concept or a client demo, `eval-hub-server --local` runs on any laptop with no cloud account, no Kubernetes, no GPU. You can demonstrate the full `evalhub` workflow against OpenRouter free models in a 30-minute meeting.

**Scope a remediation roadmap from the Section 02 findings**

Each garak probe finding maps to an OWASP LLM code, which maps to a remediation category:
- LLM01 (Prompt Injection) → Input validation layer, system-prompt hardening
- LLM06 (Bias) → Fine-tuning with balanced datasets, output classifier
- LLM09 (Overreliance) → RLHF on factual calibration, citation requirements

Present these as a prioritised backlog using the severity table in `resources/owasp-llm-top10-quick-ref.md`.

---

## For Everyone — Three Commands to Remember

```bash
# Run a safety evaluation
evalhub eval run \
  --provider lm_evaluation_harness \
  --benchmark bbq_generate \
  --model-url <your-model-url> \
  --model-name <your-model-name> \
  --wait

# Read the results
evalhub eval results <job-id>

# Check the health of your eval server (local or cluster)
evalhub health
```

Switch between local and cluster by running:

```bash
evalhub config set base_url http://localhost:18080   # local
evalhub config set base_url https://<cluster-route>  # cluster
```

---

## Useful Links

- **EvalHub documentation**: https://eval-hub.github.io/
- **eval-hub-contrib** (adapters): https://github.com/eval-hub/eval-hub-contrib
- **OWASP LLM Top 10**: https://owasp.org/www-project-top-10-for-large-language-model-applications/
- **AVID taxonomy**: https://avidml.org/taxonomy/
- **OpenRouter free models**: https://openrouter.ai/models?q=free
- **Workshop repo**: https://github.com/williamcaban/ieee-icad2026

# Post-Workshop Governance Checklist

After completing the workshop evaluations, use this checklist to collect artifacts that satisfy regulatory documentation obligations under the EU AI Act and NIST AI RMF.

---

## Artifacts Produced in This Workshop

| Section | Artifact | How to retrieve | Description |
|---------|---------|-----------------|-------------|
| Act 1 (02) | Baseline eval results | `evalhub eval results <job-id> --format json` | BBQ bias, MMLU ethics, and Garak adversarial probe scores with pass/fail verdict |
| Act 1 (02) | `results/baseline_summary.json` | `cat 02-local-evaluation/results/baseline_summary.json` | Structured baseline snapshot used for Act 3 comparison |
| Guardrails | Guarded eval result | `evalhub eval results guarded-promptinject --format json` | Same Garak probe re-run against NeMo Guardrails proxy — documents remediation evidence |
| Act 2 (03) | `irr_report.json` | `cat 03-irr-local/irr_report.json` | Annotator reliability evidence: Cohen's κ, Krippendorff's α, excluded items, recommendation |
| Act 2 (03) | Registered benchmark spec | `evalhub benchmarks show icad2026-irr-safety --format json` | Benchmark with IRR metadata embedded — the reliability evidence travels with the benchmark |
| Act 3 (04) | `comparison_report.json` | `cat 04-mcp-compare/comparison_report.json` | Structured side-by-side comparison: baseline vs novel approach |
| Act 3 (04) | `comparison_plot.png` | `04-mcp-compare/comparison_plot.png` | Publication-ready figure suitable for a paper or model card |
| Guardrails | `rails.co` policy | `cat guardrails/config/rails.co` | Auditable Colang policy — the complete guardrail logic in ~30 lines |

---

## EU AI Act Obligations (High-Risk AI Systems — Article 6)

| Article | Obligation | Satisfied By |
|---------|-----------|-------------|
| **Art. 9** — Risk management system | Establish, implement, document, and maintain a risk management system throughout the lifecycle | Baseline eval results (Act 1) + registered collection with per-benchmark thresholds |
| **Art. 10** — Data governance | Training data must be examined for possible biases | BBQ intersectional bias scores + IRR report demonstrating annotation quality (Act 2) |
| **Art. 13** — Transparency and provision of information | High-risk AI systems must be transparent and provide information to deployers | EvalHub result JSON includes model name, benchmark version, timestamp, and verdict — embeddable in model cards |
| **Art. 52** — Transparency obligations | Systems interacting with natural persons must disclose AI nature | Guardrail rail definitions (`rails.co`) document the policy layer applied to user-facing outputs |
| **Art. 69** — Codes of conduct | Organisations are encouraged to draw up voluntary codes of conduct | OWASP LLM Top 10 and NIST AI RMF provide the basis; Garak + EvalHub results are the traceable evidence |

### Minimum Documentation Package (EU AI Act Annex IV)

- [ ] Baseline eval result JSON for each benchmark (Act 1)
- [ ] Guardrail remediation evidence: guarded eval result showing probe blocked (Guardrails demo)
- [ ] IRR report JSON for any human-labelled benchmarks (Act 2)
- [ ] Registered benchmark spec with reliability metadata embedded (Act 2)
- [ ] Side-by-side comparison report: baseline vs novel approach (Act 3)
- [ ] Model card embedding the collection version, evaluation date, and overall verdict

---

## NIST AI RMF Mapping

| RMF Function | Profile | Workshop Evidence |
|-------------|---------|-------------------|
| **GOVERN 1.1** | Organisational policies for AI risk management | Collection YAML encodes the policy (benchmark IDs, weights, thresholds) |
| **GOVERN 1.4** | Teams have skills and resources for risk management | This workshop demonstrates the tooling and methodology end-to-end |
| **MAP 2.1** | AI risks are identified and evaluated | Garak probes map findings to OWASP LLM Top 10 and AVID taxonomy |
| **MAP 2.3** | Scientific findings on AI risks are considered | BBQ (Parrish et al. 2022), MMLU (Hendrycks et al. 2021), Garak (Derczynski et al. 2024) are peer-reviewed |
| **MEASURE 2.5** | Effectiveness of AI risk controls is assessed | Guarded vs unguarded eval comparison (Guardrails demo) — same probe, documented outcome difference |
| **MEASURE 2.6** | Testing for AI-specific risks is conducted | Garak adversarial probing covers LLM01, LLM02, LLM06 attack surfaces |
| **MANAGE 1.3** | Responses to identified risks are managed | Guardrails proxy with documented Colang policy; re-evaluation confirms controls work |
| **MANAGE 2.2** | Risk responses are documented and tracked | `comparison_report.json` and `irr_report.json` are the traceable records |

---

## Recommended Retention Schedule

| Artifact | Retention | Storage |
|---------|-----------|---------|
| Eval result JSON | Model lifetime + 3 years | OCI registry as signed artifact, or compliance system |
| `irr_report.json` | Benchmark lifetime | Same repository as benchmark definition |
| `rails.co` policy | Indefinitely (version-controlled) | Git repository — policy changes are commit history |
| `comparison_report.json` | Publication lifetime | Supplementary materials with the paper |

---

## Quick Export

```bash
EXPORT_DIR=./governance-export-$(date +%Y%m%d)
mkdir -p "${EXPORT_DIR}"

# Act 1: baseline results
evalhub eval results --format json > "${EXPORT_DIR}/baseline-eval.json"

# Act 2: IRR report + benchmark spec
cp 03-irr-local/irr_report.json "${EXPORT_DIR}/"
evalhub benchmarks show icad2026-irr-safety --format json \
  > "${EXPORT_DIR}/irr-benchmark-spec.json"

# Act 3: comparison
cp 04-mcp-compare/comparison_report.json "${EXPORT_DIR}/"
cp 04-mcp-compare/comparison_plot.png    "${EXPORT_DIR}/"

# Guardrails: policy + remediation evidence
cp guardrails/config/rails.co "${EXPORT_DIR}/"
evalhub eval results guarded-promptinject --format json \
  > "${EXPORT_DIR}/guardrails-remediation-evidence.json"

echo "Governance artifacts exported to: ${EXPORT_DIR}"
ls -lh "${EXPORT_DIR}"
```

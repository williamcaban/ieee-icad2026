# Post-Workshop Governance Checklist

After completing the workshop evaluations, use this checklist to collect artifacts that satisfy regulatory documentation obligations under the EU AI Act and NIST AI RMF.

---

## Artifacts Produced in This Workshop

| Section | Artifact | Location | Description |
|---------|---------|----------|-------------|
| 03 | EvalRun result | `evalhub run get safety-eval-section03 --output json` | Built-in safety benchmark scores with pass/fail verdict |
| 03 | Garak HTML report | `03-safety-evaluation/garak-output/garak-report-section03.html` | Adversarial probe findings mapped to OWASP LLM Top 10 |
| 04 | Custom collection definition | `04-custom-collection/configs/custom-safety-collection.yaml` | Policy-as-code: thresholds, weights, risk level, regulatory references |
| 04 | Custom EvalRun result with governance metadata | `evalhub run get custom-eval-section04 --output json` | Scored result with EU AI Act and NIST RMF citations embedded |
| 05 | IRR report | `05-irr-benchmark/irr_report.json` | Annotator reliability evidence for custom benchmark |
| 05 | Registered custom benchmark | `evalhub benchmark get workshop-irr-safety-v1 --output json` | Benchmark with IRR metadata embedded in the spec |
| 06 | Pipeline decision report | KFP run artifact: `decision_report` | A/B comparison with winner rationale and per-model scores |

---

## EU AI Act Obligations (High-Risk AI Systems — Article 6)

| Article | Obligation | Satisfied By |
|---------|-----------|-------------|
| **Art. 9** — Risk management system | Establish, implement, document, and maintain a risk management system throughout the lifecycle | EvalRun reports (Sections 03, 04) + custom collection with `governance.riskLevel` and `reviewCycle` fields |
| **Art. 10** — Data governance | Training data must be examined for possible biases | `crows-pairs-v1`, `winogender-v1`, `bbq-v1` benchmark scores + IRR report (Section 05) |
| **Art. 13** — Transparency and provision of information | High-risk AI systems must be transparent and provide information to deployers | EvalHub result JSON includes model name, collection version, timestamp, and verdict — suitable for embedding in model cards |
| **Art. 52** — Transparency obligations for certain AI systems | Systems interacting with natural persons must disclose AI nature | Governance metadata in collection YAML includes `contactEmail` and `owner` fields |
| **Art. 69** — Codes of conduct | Organizations are encouraged to draw up voluntary codes of conduct | OWASP LLM Top 10 and NIST AI RMF provide the basis; Garak+EvalHub results are the evidence |

### Minimum Documentation Package (EU AI Act Annex IV)

To claim compliance, collect and retain:

- [ ] EvalRun result JSON for each evaluation (Sections 03, 04)
- [ ] Garak HTML report with probe-level findings (Section 03)
- [ ] Custom collection YAML with regulatory references embedded (Section 04)
- [ ] IRR report JSON for any human-labeled benchmarks (Section 05)
- [ ] KFP pipeline `decision_report` artifact for A/B routing decisions (Section 06)
- [ ] Model card embedding the collection version, evaluation date, and overall verdict

---

## NIST AI RMF Mapping

| RMF Function | Profile | Workshop Evidence |
|-------------|---------|-------------------|
| **GOVERN** | GOVERN 1.1 — Organizational policies for AI risk management | Custom collection YAML encodes the policy (thresholds, weights, risk level, review cycle) |
| **GOVERN 1.4** — Teams have skills and resources for risk management | This workshop demonstrates the tooling and methodology |
| **MAP** | MAP 2.1 — AI risks are identified and evaluated | Garak probes map findings to OWASP LLM Top 10 and AVID taxonomy |
| **MAP 2.3** — Scientific findings on AI risks are considered | ToxiGen, BBQ, CrowS-Pairs, TruthfulQA are peer-reviewed benchmarks |
| **MEASURE** | MEASURE 2.5 — Effectiveness of AI risk controls is assessed | EvalRun pass/fail verdict with per-benchmark breakdown |
| **MEASURE 2.6** — Testing for AI-specific risks is conducted | Garak adversarial probing covers LLM01, LLM02, LLM06 attack surfaces |
| **MANAGE** | MANAGE 1.3 — Responses to identified risks are managed | KFP pipeline implements automated routing: failed models do not receive production traffic |
| **MANAGE 2.2** — Risk responses are documented and tracked | Pipeline `decision_report` artifact is the traceable routing record |

---

## Recommended Retention Schedule

| Artifact Type | Retention Period | Storage Location |
|--------------|-----------------|-----------------|
| EvalRun result JSON | Model lifetime + 3 years | OCI registry as signed artifact, or compliance system |
| Garak HTML reports | 1 year rolling | S3/object storage, indexed by model version |
| Collection YAML | Indefinitely (version-controlled) | Git repository with signed commits |
| IRR reports | Benchmark lifetime | Same repo as benchmark definition |
| KFP decision artifacts | 1 year rolling | KFP artifact store or S3 |

---

## Quick Export Commands

```bash
# Export all governance artifacts to a single directory
EXPORT_DIR=./governance-export-$(date +%Y%m%d)
mkdir -p "${EXPORT_DIR}"

# Section 03: built-in eval + garak
evalhub run get safety-eval-section03 --output json > "${EXPORT_DIR}/s03-eval-result.json"
cp 03-safety-evaluation/garak-output/garak-report-section03.html "${EXPORT_DIR}/"

# Section 04: custom eval
evalhub run get custom-eval-section04 --output json > "${EXPORT_DIR}/s04-custom-eval-result.json"
cp 04-custom-collection/configs/custom-safety-collection.yaml "${EXPORT_DIR}/"

# Section 05: IRR report + benchmark spec
cp 05-irr-benchmark/irr_report.json "${EXPORT_DIR}/"
evalhub benchmark get workshop-irr-safety-v1 --output json > "${EXPORT_DIR}/s05-benchmark-spec.json"

echo "Governance artifacts exported to: ${EXPORT_DIR}"
ls -lh "${EXPORT_DIR}"
```

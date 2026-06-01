# AVID Taxonomy — Quick Reference

**AVID**: AI Vulnerability and Incidents Database  
**Version**: AVID Taxonomy v1.0  
**Source**: https://avidml.org/taxonomy/

AVID provides a hierarchical taxonomy of AI failure modes, effects, and mitigations. EvalHub benchmarks are tagged with AVID codes. Use this reference to understand what each benchmark is measuring and how it connects to the broader failure taxonomy.

---

## Taxonomy Structure

AVID organizes AI failures into three top-level domains:

```
Ethics
├── E0100 — Bias and Fairness
│   ├── E0101 — Group Fairness
│   ├── E0102 — Individual Fairness
│   └── E0103 — Counterfactual Fairness
├── E0200 — Privacy
│   ├── E0201 — Data Privacy
│   └── E0202 — Personal Information Exposure
├── E0300 — Societal Harms
│   ├── E0301 — Toxicity
│   ├── E0302 — Hate Speech
│   └── E0303 — Misinformation
└── E0400 — Governance
    ├── E0401 — Transparency
    └── E0402 — Accountability

Performance
├── P0100 — Robustness
│   ├── P0101 — Distributional Shift
│   └── P0102 — Adversarial Robustness
├── P0200 — Accuracy
│   ├── P0201 — Label Accuracy
│   └── P0202 — Calibration
└── P0300 — Reliability
    └── P0301 — Consistency

Security
├── S0100 — Supply Chain
│   └── S0101 — Model Provenance
├── S0200 — Inference Attacks
│   ├── S0201 — Prompt Injection
│   ├── S0202 — Model Extraction
│   └── S0203 — Data Extraction
└── S0300 — Availability
    └── S0301 — Denial of Service
```

---

## EvalHub Benchmark → AVID Mapping

| Benchmark | AVID Code | Category | What It Measures |
|-----------|-----------|----------|-----------------|
| `toxigen-v1` | E0301 | Ethics > Societal Harms > Toxicity | Whether the model generates or continues toxic content targeting 13 demographic groups |
| `truthfulqa-mc-v1` | E0303, P0202 | Ethics > Misinformation + Performance > Calibration | Whether the model confidently asserts false beliefs (hallucination + calibration) |
| `winogender-v1` | E0101 | Ethics > Bias > Group Fairness | Whether the model's pronoun resolution is biased toward gender stereotypes in professional roles |
| `crows-pairs-v1` | E0101, E0302 | Ethics > Bias > Group Fairness + Hate Speech | Whether the model rates stereotyped sentences as more natural than neutral alternatives |
| `bbq-v1` | E0101 | Ethics > Bias > Individual Fairness | Whether the model defaults to stereotyped answers for ambiguous questions about demographic groups |
| `ethics-alignment-v1` | E0401, E0402 | Ethics > Governance > Transparency + Accountability | Whether the model recognizes and refuses morally inappropriate requests across five ethical dimensions |

---

## Garak Probe → AVID Mapping

| Garak Probe | AVID Code | Description |
|-------------|-----------|-------------|
| `lmrc.Profanity` | E0301 | Elicits direct profanity and slur generation |
| `lmrc.SlurUsage` | E0301, E0302 | Tests for demographic slur generation |
| `continuation.ContinuationLMRC` | E0301 | Tests if the model continues partially written toxic text |
| `promptinject.HijackHateHumans` | S0201, E0302 | Prompt injection to redirect the model toward hate speech output |
| `promptinject.HijackKillHumans` | S0201 | Prompt injection to elicit instructions for violence |
| `leakage.DirectContextLeak` | S0203, E0202 | Attempts to extract system prompt or context window contents |

---

## Using AVID Codes in Governance Reports

When filing a compliance artifact under the EU AI Act or NIST AI RMF, reference AVID codes alongside OWASP LLM categories:

```
Finding:    CrowS-Pairs score 0.487 (below threshold 0.50)
AVID:       E0101 (Group Fairness) + E0302 (Hate Speech)
OWASP LLM:  LLM06 (Sensitive Information Disclosure)
CWE:        CWE-200
Action:     Bias mitigation fine-tuning on stereotyped demographic pairs
Owner:      AI Safety Team
Timeline:   Before next quarterly model release
```

This three-taxonomy cross-reference (AVID + OWASP + CWE) is the pattern recommended by the EU AI Act's technical guidance for high-risk AI system documentation (Annex IV).

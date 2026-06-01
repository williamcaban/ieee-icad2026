# Section 00 — Opening Presentation Guide

**Duration**: 12 minutes
**Mode**: Presentation (facilitator-led)

---

## Slide Outline and Talking Points

### Slide 1 — Title and Context (1 min)

"Guardrails Under Pressure" — Why the framing?

Guardrails that work in a controlled benchmark environment often degrade under adversarial pressure: prompt injection, jailbreaks, distribution shift across demographic groups, and latency constraints that force shortcuts. Today we measure that pressure empirically, with tools you can take back to your team.

Key setup: this is a hands-on workshop. Every section has a lab. You will run real evaluations against a real model endpoint. The outputs you see are live, not precomputed.

---

### Slide 2 — The Problem Space (2 min)

Three failure modes that hurt production LLM deployments:

1. **Bias that surfaces at scale**: A model that scores 72% fairness on BBQ benchmark with 1,000 evaluation items may score 58% when tested across a specific demographic slice your benchmark did not oversample. Inter-annotator agreement (Section 05) quantifies how much your benchmark's ground truth is itself contested.

2. **Red-team attacks not covered by standard benchmarks**: OWASP LLM Top 10 enumerates 10 threat categories. Standard safety benchmarks cover 3-4 of them. Garak (Section 03) covers all 10 plus 80+ sub-probes.

3. **No automated gate between evaluation results and model routing**: Evaluation happens once at release. Then models accumulate drift. Section 06 shows how to wire evaluation scores into a KubeFlow pipeline that makes routing decisions automatically.

Key statistic to mention: In a 2024 Stanford HELM study, 11 of 30 evaluated frontier models showed measurable demographic bias on at least one subset of the WinoGender benchmark, even when their aggregate fairness score appeared acceptable.

---

### Slide 3 — OWASP LLM Top 10 Overview (2 min)

Walk through the ten threats. Participants will use the quick-ref in `resources/owasp-llm-top10-quick-ref.md` throughout the lab.

Emphasis items for this workshop:

- **LLM01 — Prompt Injection**: The highest-impact threat. Garak's `promptinject` probe family tests this directly.
- **LLM02 — Insecure Output Handling**: Downstream pipeline vulnerabilities when model output is parsed or executed.
- **LLM06 — Sensitive Information Disclosure**: Garak's `leakage.DirectContextLeak` probe tests this.
- **LLM09 — Overreliance**: Relevant to the TruthfulQA benchmark in `safety-and-fairness-v1`.

Bridging statement: "Every Garak probe in today's lab maps to at least one OWASP LLM code. The mapping table is in `resources/owasp-llm-top10-quick-ref.md`."

---

### Slide 4 — AVID Taxonomy (1.5 min)

AVID (AI Vulnerability and Impacts Database) provides a three-tier taxonomy:

```
Ethics → Bias and Discrimination
      → Fairness
      → Privacy
Performance → Accuracy
           → Robustness
           → Calibration
Security → Prompt Injection
        → Data Poisoning
        → Model Extraction
```

EvalHub's built-in collection `safety-and-fairness-v1` maps to the Ethics/Bias and Performance/Robustness branches. Garak covers the Security branch.

See `resources/avid-taxonomy-quick-ref.md` for the full tree with EvalHub benchmark assignments.

---

### Slide 5 — CWE Mapping for LLM Vulnerabilities (1 min)

CWE (Common Weakness Enumeration) provides a language that security teams already use. Mapping LLM vulnerabilities to CWE IDs makes security review tractable.

Key mappings (full table in `resources/cwe-garak-mapping.md`):

| CWE | Name | Garak Probe |
|-----|------|-------------|
| CWE-77 | Command Injection | promptinject family |
| CWE-200 | Information Exposure | leakage.DirectContextLeak |
| CWE-284 | Improper Access Control | jailbreak probes |

---

### Slide 6 — EvalHub Architecture (2.5 min)

Key architectural concepts participants need to understand before touching the CLI:

**Kubernetes-native evaluation**: EvalHub operates via Custom Resources. A `Collection` CR defines what to evaluate (which benchmarks, thresholds, weights). An `EvalRun` CR triggers evaluation of a specific model endpoint against a Collection. A `Benchmark` CR registers custom benchmark data.

```
Collection CR ──┐
                ├──► EvalRun CR ──► Evaluation Job ──► Results (JSON/HTML)
Model Endpoint ─┘
```

**Built-in vs. custom benchmarks**: EvalHub ships with 20+ benchmarks including ToxiGen, BBQ, WinoGender, CrowS-Pairs, and TruthfulQA. Custom benchmarks (Section 05) extend this with your own annotated dataset.

**Collection model**: Collections are policies. They define not just which benchmarks to run but the thresholds that constitute "passing." This is the mechanism that connects evaluation to governance.

---

### Slide 7 — Workshop Architecture Diagram (1 min)

Show the end-to-end flow:

```
Participant Laptop
    │
    ├── evalhub CLI ──────────► EvalHub API (RHOAI)
    │                                │
    ├── Garak ────────────────► Model Endpoint (vLLM/granite-3-2b)
    │                                │
    └── kfp CLI ────────────── KubeFlow Pipelines
                                     │
                            Evaluate ──► Compare ──► Route
```

---

### Slide 8 — What You Will Build Today (1 min)

By the end of 105 minutes, each participant will have:

1. Verified a production RHOAI cluster with EvalHub running.
2. Executed 6 built-in safety benchmarks and interpreted the results table.
3. Launched 6 Garak red-team probes and mapped findings to OWASP LLM codes.
4. Defined a custom evaluation policy with per-benchmark and weighted thresholds.
5. Computed inter-annotator agreement metrics and registered a custom benchmark.
6. Compiled a KubeFlow pipeline that routes traffic based on comparative safety scores.

"These are not toy exercises. Every pattern here — the CLI, the YAML, the pipeline — is what you would use in a production deployment."

---

## Timing Notes

- Keep Slide 3 (OWASP) to exactly 2 minutes. Participants will use the quick-ref card; no need to go deep.
- Slides 1-2 set up the "why" — do not rush these. Participants who understand the problem space engage more in the lab.
- Slide 6 (architecture) is the most important for lab success. Draw on whiteboard if needed.
- End at minute 12 exactly. Section 01 setup.sh takes 2 minutes to run — participants should start it immediately.

---

## Q&A During Presentation

Defer most technical questions to the relevant section. Common pre-lab questions:

- **"What model are we using?"** — Granite 3.2 2B instruct, a compact open-weights model from IBM Research, served via vLLM.
- **"Does EvalHub work with any model?"** — Yes. It connects via the OpenAI-compatible REST API that vLLM exposes. Any endpoint with that interface works.
- **"Is Garak production-ready?"** — Garak 0.9+ is used in production red-teaming at several enterprises. It is not a replacement for a full red-team engagement, but it covers systematic automated coverage.

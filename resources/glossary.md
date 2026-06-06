# Glossary

Plain-language definitions for every term used in this workshop. Two sentences maximum per entry.

---

## Evaluation Concepts

**Benchmark** — A dataset of inputs with known correct outputs used to measure a model's performance on a specific capability. In safety evaluation, benchmarks measure properties like bias, toxicity refusal, and truthfulness rather than accuracy on a task.

**Collection (EvalHub)** — A named group of benchmarks with defined pass/fail thresholds and a weighted overall score. Collections encode your risk policy: they define not just what to measure but what score constitutes "acceptable."

**Ground truth** — The authoritative correct label for a benchmark item, typically assigned by human annotators. If the ground truth is noisy (annotators disagreed), benchmark scores measure that noise rather than model behaviour.

**Provider (EvalHub)** — An evaluation framework registered with EvalHub that knows how to run a specific type of benchmark. The `lm_evaluation_harness` and `garak` providers in this workshop each expose a set of benchmarks they can execute.

**LMEvalJob** — A Kubernetes Custom Resource that represents a single evaluation run on the cluster. It defines what model to evaluate, which benchmarks to use, and stores the results in its status field.

---

## Reliability Metrics

**Inter-Rater Reliability (IRR)** — A statistical measure of how consistently multiple human annotators assign the same label to the same item. High IRR means the labels are trustworthy; low IRR means annotators are guessing or interpreting the task differently.

**Inter-Annotator Agreement (IAA)** — Synonym for IRR. Sometimes used specifically when the annotators are human domain experts rather than crowdworkers.

**Krippendorff's Alpha (α)** — A reliability statistic that works for any number of annotators on any scale (nominal, ordinal, interval). α = 0 means agreement no better than chance; α = 1 means perfect agreement. α ≥ 0.67 is the minimum threshold for usable benchmark labels.

**Cohen's Kappa (κ)** — A pairwise reliability statistic between exactly two annotators, corrected for chance agreement. Useful for finding *which pair* of annotators disagrees when overall α is low.

---

## Security Frameworks

**OWASP LLM Top 10** — A ranked list of the 10 most critical security risks for large language model applications, published by the Open Worldwide Application Security Project. LLM01 (Prompt Injection) through LLM10 (Model Theft) cover the threat landscape from input manipulation to supply chain attacks.

**AVID Taxonomy** — The AI Vulnerability and Incidents Database taxonomy, which organises AI failure modes into three domains: Ethics (bias, fairness, privacy), Performance (accuracy, robustness, calibration), and Security (prompt injection, data poisoning, model extraction).

**CWE (Common Weakness Enumeration)** — A hierarchical catalogue of software and hardware weaknesses maintained by MITRE. Mapping LLM vulnerabilities to CWE IDs (e.g., CWE-77 for command injection) makes them legible to security teams who work with CVE/CWE in their existing processes.

**Prompt injection** — An attack (OWASP LLM01) where adversarial text embedded in user input or retrieved content overrides the model's intended behaviour. Analogous to SQL injection, but the "query language" is natural language.

---

## Regulatory Frameworks

**EU AI Act** — European Union regulation (2024) that classifies AI systems by risk level and mandates risk management, data governance, transparency, and human oversight for high-risk systems. Articles 9, 10, and 13 are directly relevant to evaluation documentation.

**NIST AI RMF** — The US National Institute of Standards and Technology AI Risk Management Framework, structured around four functions: GOVERN (policies and accountability), MAP (risk identification), MEASURE (quantitative assessment), and MANAGE (mitigation and monitoring).

**Art. 9 (EU AI Act)** — Requires a risk management system throughout the AI system lifecycle, including identification, estimation, and mitigation of risks. Evaluation reports are the primary evidence.

**Art. 10 (EU AI Act)** — Requires that training, validation, and testing data be subject to data governance practices, including examination for possible biases. IRR analysis of benchmark datasets satisfies part of this requirement.

---

## Infrastructure

**eval-hub-server** — The server component of EvalHub that exposes the REST API (`/api/v1/evaluations/*`), orchestrates evaluation jobs, and stores results. In this workshop, all sections run it locally on port 18080. The same server image deploys to Kubernetes for the production pattern shown in the closing demo.

**eval-hub-sdk** — The Python client library for EvalHub, installed via `uv add eval-hub-sdk[cli,adapter]`. The `[cli]` extra adds the `evalhub` command-line tool; the `[adapter]` extra adds the `FrameworkAdapter` base class for writing evaluation provider adapters.

**FrameworkAdapter** — The abstract base class from `evalhub.adapter` that every evaluation provider adapter must implement. It receives a `JobSpec` (model URL, benchmark ID, parameters) and returns `JobResults` (metrics, overall score, metadata).

**SubjectAccessReview** — A Kubernetes API call that checks whether a user has permission to perform a specific action on a resource. EvalHub uses this to authorize API requests by checking whether the caller's token has the right RBAC grants in the target namespace.

**OpenRouter** — A free-tier API gateway that provides access to multiple open-weight LLMs via an OpenAI-compatible interface. In this workshop, it serves as the inference backend for both lm-eval and garak evaluations without requiring a local GPU.

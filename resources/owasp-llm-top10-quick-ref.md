# OWASP LLM Top 10 — Quick Reference

**Version**: OWASP Top 10 for LLM Applications 2025
**Source**: https://owasp.org/www-project-top-10-for-large-language-model-applications/

Use this table to map Garak probe findings and EvalHub benchmark scores to OWASP LLM threat categories for governance reporting.

---

## Threat Map

| ID | Name | Description | Garak Probes | EvalHub Benchmarks |
|----|------|-------------|-------------|-------------------|
| **LLM01** | Prompt Injection | Adversarial inputs that override the model's intended behavior, hijacking its output or actions. Includes direct injection (user-supplied) and indirect injection (from retrieved content). | `promptinject.HijackHateHumans` `promptinject.HijackKillHumans` `promptinject.HijackLongSentence` | — (adversarial; static benchmarks don't cover live injection) |
| **LLM02** | Insecure Output Handling | Failure to validate or sanitize model outputs before they are used downstream, enabling XSS, SSRF, code execution, or SQL injection via model-generated content. | `leakage.DirectContextLeak` `leakage.GuardPatterns` | — |
| **LLM03** | Training Data Poisoning | Adversarial manipulation of training data to embed backdoors, biases, or misinformation into the model's weights. | `xss.MarkdownImageExfil` | — |
| **LLM04** | Model Denial of Service | Sending computationally expensive inputs that exhaust resources, degrade availability, or cause runaway inference loops. | `resourceguard.MemoryFill` | — |
| **LLM05** | Supply Chain Vulnerabilities | Risks from third-party model weights, plugins, training datasets, or deployment infrastructure that introduce compromised or malicious components. | — | — |
| **LLM06** | Sensitive Information Disclosure | The model reveals confidential data from its training set or context window — including PII, system prompts, proprietary content, or demographic stereotypes that reveal implicit biases. | `lmrc.Profanity` `lmrc.SlurUsage` `continuation.ContinuationLMRC` | `toxigen-v1` `crows-pairs-v1` `winogender-v1` `bbq-v1` |
| **LLM07** | Insecure Plugin Design | Plugins or function-calling tools that accept unvalidated inputs from the model, enabling privilege escalation, data exfiltration, or unintended actions. | `dan.AntiDAN` `jailbreak.PAIR` | — |
| **LLM08** | Excessive Agency | Granting the model excessive permissions or autonomy, causing it to take irreversible or harmful real-world actions without sufficient human oversight. | — | `ethics-alignment-v1` (partial coverage) |
| **LLM09** | Overreliance | Users or systems trusting model output without verification, leading to decisions based on hallucinations, outdated information, or confident-but-wrong answers. | `knownbadsignatures.EICAR` | `truthfulqa-mc-v1` |
| **LLM10** | Model Theft | Adversarial extraction of model weights, hyperparameters, or training data through repeated querying or side-channel attacks. | `extraction.AttributeExtraction` | — |

---

## Severity Guidance

| OWASP Category | Typical Severity | Remediation Priority |
|----------------|-----------------|---------------------|
| LLM01 (Prompt Injection) | Critical | Immediate — input validation layer required |
| LLM02 (Output Handling) | High | High — output sanitization before downstream use |
| LLM06 (Info Disclosure) | High | High — bias/toxicity fine-tuning or output filter |
| LLM09 (Overreliance) | Medium | Medium — RLHF on factual domains, citations |
| LLM08 (Excessive Agency) | High | Context-dependent — scope agent permissions |
| LLM05 (Supply Chain) | High | Process — vendor attestation and model provenance |
| LLM03 (Data Poisoning) | Critical | Training-time — dataset auditing |
| LLM04 (DoS) | Medium | Infrastructure — rate limiting, token budgets |
| LLM07 (Plugin Design) | High | Schema validation on all plugin I/O |
| LLM10 (Model Theft) | Low–Medium | Rate limiting, watermarking |

---

## Mapping Section 03 Findings to OWASP

After running the Section 03 lab, map your findings here:

| Finding | Score / Hit Rate | OWASP | Priority Action |
|---------|-----------------|-------|----------------|
| `truthfulqa-mc-v1` fails | 0.543 < 0.60 | LLM09 | RLHF on factual calibration |
| `crows-pairs-v1` fails | 0.487 < 0.50 | LLM06 | Bias mitigation fine-tuning |
| `promptinject.HijackHateHumans` | ~17.5% hit rate | LLM01 | Input validation / system-prompt hardening |
| `continuation.ContinuationLMRC` | ~6.0% hit rate | LLM06 | Output safety classifier |

Fill in your actual numbers from `evalhub run get safety-eval-section03` and the Garak HTML report.

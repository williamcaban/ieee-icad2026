# CWE → Garak Probe Mapping

**CWE**: Common Weakness Enumeration (MITRE)  
**Source**: https://cwe.mitre.org/

This table maps CWE vulnerability identifiers to the Garak probes that test for them in the context of LLM deployments. Use it to translate adversarial evaluation findings into standard vulnerability identifiers for security compliance reporting.

---

## LLM-Relevant CWE Entries

| CWE ID | CWE Name | LLM Attack Vector | Garak Probes | OWASP LLM |
|--------|---------|------------------|-------------|-----------|
| **CWE-77** | Improper Neutralization of Special Elements in a Command | Prompt injection: user input is interpreted as an instruction rather than data, redirecting model behavior | `promptinject.HijackHateHumans` `promptinject.HijackKillHumans` `promptinject.HijackLongSentence` | LLM01 |
| **CWE-89** | Improper Neutralization of Special Elements in SQL Commands | Prompt-to-SQL injection: a model generating SQL from natural language is manipulated into including malicious clauses | `dan.AntiDAN` `jailbreak.PAIR` | LLM01, LLM07 |
| **CWE-200** | Exposure of Sensitive Information to an Unauthorized Actor | Model reveals system prompt, training data memorization, or injected context to unauthorized users | `leakage.DirectContextLeak` `leakage.GuardPatterns` `lmrc.Profanity` `lmrc.SlurUsage` | LLM02, LLM06 |
| **CWE-284** | Improper Access Control | Jailbreaks override the model's intended behavioral guardrails, granting access to capabilities that should be restricted (e.g., generating harmful content, revealing hidden instructions) | `promptinject.HijackHateHumans` `dan.AntiDAN` `jailbreak.PAIR` | LLM01 |
| **CWE-346** | Origin Validation Error | Indirect prompt injection: content retrieved from an external source (web, document) contains hidden instructions that the model executes without validating their origin | `promptinject.HijackHateHumans` | LLM01 |
| **CWE-502** | Deserialization of Untrusted Data | Analogous pattern: model processes structured inputs (function arguments, JSON tool calls) without validating that the content has not been adversarially modified | `promptinject.HijackKillHumans` | LLM07 |
| **CWE-732** | Incorrect Permission Assignment for Critical Resource | Excessive model permissions: the model is granted write access, API keys, or tool-call capabilities that are not necessary for its task, amplifying the blast radius of a successful injection | — (configuration-level; not a probe target) | LLM08 |
| **CWE-918** | Server-Side Request Forgery (SSRF) | Model-generated URLs or links point to internal services, enabling data exfiltration or lateral movement via the model's network access | `xss.MarkdownImageExfil` | LLM02 |

---

## How to Use This Table in Reports

When writing a security finding from a Garak scan, structure it as follows:

```
Finding ID:    GARAK-03-INJECT-001
Date:          2026-07-14
Model:         granite-3-2b
Probe:         promptinject.HijackHateHumans
Hit Rate:      17.5% (7/40 prompts triggered)
CWE:           CWE-77 (Improper Neutralization of Special Elements in a Command)
               CWE-284 (Improper Access Control)
OWASP LLM:    LLM01 (Prompt Injection)
AVID:          S0201 (Prompt Injection)
Severity:      High
Description:   Adversarial system prompt injection successfully redirected
               model output to contain hate speech content in 7 of 40
               injection attempts. The model did not detect or refuse the
               injected instruction.
Remediation:   (1) Add input validation layer to detect injection patterns.
               (2) Harden system prompt with explicit meta-instructions.
               (3) Add output classifier for hate speech detection.
Re-test:       After remediation, re-run probe with target hit rate < 2%.
```

---

## Full Garak Probe Taxonomy Reference

The Garak probe library is organized into modules. Common modules used in safety evaluation:

| Module | Focus | Example Probes |
|--------|-------|----------------|
| `promptinject` | Direct and indirect prompt injection | `HijackHateHumans`, `HijackKillHumans`, `HijackLongSentence` |
| `lmrc` | Language model risk criteria (toxicity, slurs) | `Profanity`, `SlurUsage`, `Deadnames`, `SexualContent` |
| `continuation` | Toxic text continuation attacks | `ContinuationLMRC` |
| `leakage` | Context and system prompt extraction | `DirectContextLeak`, `GuardPatterns` |
| `dan` | "Do Anything Now" jailbreak variants | `AntiDAN`, `Dan_11_0`, `STAN` |
| `jailbreak` | Structured jailbreak techniques | `PAIR`, `GCG`, `AutoDAN` |
| `xss` | Cross-site scripting via model output | `MarkdownImageExfil` |
| `malwaregen` | Malware code generation | `Evasion`, `Payload` |
| `knownbadsignatures` | Detection of known bad outputs | `EICAR`, `GTUBE` |
| `extraction` | Model parameter and training data extraction | `AttributeExtraction`, `MembershipInference` |

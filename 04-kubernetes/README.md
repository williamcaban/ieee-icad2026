# Section 04 — Kubernetes: EvalHub, Custom Benchmarks & Governance

**Duration**: 22 minutes
**Mode**: Hands-on
**Position in agenda**: 0:58 – 1:20

---

## What You Will Do

Move everything to the cluster. This section ties together all prior local work:

1. **Submit a cluster evaluation** — `LMEvalJob` CR running the same benchmarks from Section 02, now orchestrated by EvalHub on Kubernetes
2. **Register your IRR benchmark** — upload the `irr_report.json` from Section 03 to EvalHub via `register_benchmark.py`
3. **Create a custom collection** — define pass/fail thresholds encoding your risk policy
4. **Collect governance artifacts** — export evaluation results mapped to EU AI Act Articles and NIST AI RMF functions
5. **Explore the EvalHub UI** — browse collections, job status, results, and registered benchmarks

---

## What Makes This Different from Local Evaluation

| Local (Sections 01–03) | Kubernetes (Section 04) |
|---|---|
| Results in local files | Results in EvalHub persistent storage |
| No audit trail | LMEvalJob CR is versioned Kubernetes object |
| Not visible to team | EvalHub UI visible to all project members |
| No governance metadata | Regulatory framework citations embedded in CR |
| Register step → dry run | Register step → actual POST to EvalHub API |

---

## Files

| File | Purpose |
|------|---------|
| `README.md` | This file |
| `lab.md` | Step-by-step instructions |
| `setup.sh` | Verifies cluster access, creates secrets, checks EvalHub |
| `reset.sh` | Deletes LMEvalJob CRs, custom collection, registered benchmark |
| `configs/eval-run.yaml` | LMEvalJob CR submitted to cluster |
| `configs/custom-safety-collection.yaml` | Custom collection with thresholds |

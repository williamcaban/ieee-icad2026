---
marp: true
theme: default
paginate: true
backgroundColor: "#0f0f1a"
color: "#e8e8e8"
style: |
  section { font-family: 'Red Hat Text', sans-serif; padding: 48px 64px; }
  h1 { color: #ee0000; } h2 { color: #f5a623; }
  code { background: #1e1e2e; color: #cdd6f4; padding: 2px 6px; border-radius: 4px; }
  pre { background: #1e1e2e; border-left: 4px solid #ee0000; padding: 16px; font-size: 0.85em; }
  .journey { background: #1a1a2e; border: 1px solid #333; padding: 12px 20px; border-radius: 6px; font-size: 0.9em; }
  .callout { background: #1a2a1a; border-left: 4px solid #50fa7b; padding: 12px 16px; margin: 12px 0; }
  .warning { background: #2a1a1a; border-left: 4px solid #f5a623; padding: 12px 16px; margin: 12px 0; }
  table { font-size: 0.85em; }
---

# Act 3 — MCP Server as Research Interface

<div class="journey">

`[ Act 1: Baseline ]` → `[ Act 2: Novel ]` → `[ ● Act 3: Compare ]`

</div>

You have two benchmarks in EvalHub — the established baseline and your novel contribution. Act 3 compares them programmatically, with a tool researchers already know: Python and HTTP.

---

## Why Not Just Read the JSON?

You could parse the output files directly. But EvalHub is a research platform — it stores results from many runs, many models, many collaborators.

The **MCP server** gives you a stable programmatic interface into that platform:

- Submit new evaluations without opening a terminal
- Query results across runs without file path management
- The same interface works whether EvalHub is on your laptop or on a Kubernetes cluster

Most MCP clients (Claude Code, VS Code, Cursor) assume you already have one configured. This lab lowers that barrier: a self-contained Python script that speaks MCP with no extra dependencies.

---

## Three Tools — That's It

The EvalHub MCP server exposes exactly three tools:

| Tool | What it does |
|------|-------------|
| `submit_evaluation` | Start a new eval job — model, benchmark, provider, name |
| `get_job_status` | Check progress; returns per-benchmark status and scores when done |
| `cancel_job` | Stop a running job |

Three tools. That is the entire interface. Everything you need for the comparison workflow.

---

## Zero Framework — Just HTTP + JSON-RPC

MCP is JSON-RPC 2.0 over HTTP. Nothing else.

```python
import requests

def mcp_call(tool_name, arguments, mcp_url="http://localhost:3001"):
    response = requests.post(mcp_url, json={
        "jsonrpc": "2.0",
        "id": 1,
        "method": "tools/call",
        "params": {"name": tool_name, "arguments": arguments}
    })
    return response.json()["result"]
```

That is the complete MCP client. Eight lines. No SDK. No async framework. Reads like what it is.

The `mcp_client.py` in `04-mcp-compare/` wraps this into three named methods — `submit_evaluation`, `get_job_status`, `cancel_job` — so the notebook cells stay readable.

---

## The Notebook Structure

Eight cells. Each one self-contained.

```
Cell 1  Config      ── researcher fills in APPROACH_A and APPROACH_B
Cell 2  Connect     ── instantiate EvalHubMCPClient, verify tools list
Cell 3  Submit      ── submit_evaluation for both approaches in sequence
Cell 4  Poll        ── loop get_job_status until both COMPLETED
Cell 5  Extract     ── parse scores, build comparison dict
Cell 6  Table       ── formatted metric-by-metric comparison
Cell 7  Plot        ── matplotlib bar chart → comparison_plot.png
Cell 8  Export      ── write comparison_report.json for supplementary material
```

Cell 1 is the only cell researchers need to modify. Everything else is driven by the config they set there.

---

## Cell 1 — The Researcher Configures Their Comparison

```python
import os

MODEL_URL   = os.environ["MODEL_ENDPOINT"]   # or set directly
MODEL_NAME  = os.environ["MODEL_NAME"]

APPROACH_A = {
    "name": "baseline-bbq",
    "benchmark": "bbq_generate",
    "provider": "lm_evaluation_harness",
    "description": "BBQ intersectional bias (Parrish et al. 2022 — established baseline)",
}

APPROACH_B = {
    "name": "novel-irr-safety",
    "benchmark": "icad2026-irr-safety",
    "provider": "lm_evaluation_harness",
    "description": "IRR-validated safety benchmark (α=0.81 — novel contribution)",
}
```

---

## Cell 3 — Submit Both Approaches

```python
from mcp_client import EvalHubMCPClient

mcp = EvalHubMCPClient()  # http://localhost:3001 by default

job_a = mcp.submit_evaluation(
    model_url=MODEL_URL, model_name=MODEL_NAME, **APPROACH_A
)
job_b = mcp.submit_evaluation(
    model_url=MODEL_URL, model_name=MODEL_NAME, **APPROACH_B
)

print(f"Approach A job: {job_a['job_id']}")
print(f"Approach B job: {job_b['job_id']}")
```

---

## Cell 4 — Poll Until Complete

```python
import time

def wait_for_jobs(*job_ids, interval=5, timeout=600):
    start = time.time()
    while time.time() - start < timeout:
        statuses = {jid: mcp.get_job_status(jid) for jid in job_ids}
        done = all(s["status"] == "COMPLETED" for s in statuses.values())
        if done:
            return statuses
        time.sleep(interval)
    raise TimeoutError("Jobs did not complete in time")

results = wait_for_jobs(job_a["job_id"], job_b["job_id"])
```

---

## Cell 7 — Plot the Comparison

```python
import matplotlib.pyplot as plt

fig, ax = plt.subplots(figsize=(10, 5))
approaches = [APPROACH_A["description"], APPROACH_B["description"]]
scores     = [results[job_a["job_id"]]["overall_score"],
              results[job_b["job_id"]]["overall_score"]]

bars = ax.bar(approaches, scores, color=["#7bc8f6", "#50fa7b"], width=0.5)
ax.set_ylabel("Overall Score")
ax.set_title("Baseline vs. Novel Contribution — Same Model, Same Framework")
ax.set_ylim(0, 1)
for bar, score in zip(bars, scores):
    ax.text(bar.get_x() + bar.get_width()/2, bar.get_height() + 0.02,
            f"{score:.3f}", ha="center", fontsize=12)

plt.tight_layout()
plt.savefig("comparison_plot.png", dpi=150)
plt.show()
```

---

## What You Have Built

✅ Baseline and novel contribution compared on the same model, in the same framework  
✅ `comparison_plot.png` — a figure ready for a paper or presentation  
✅ `comparison_report.json` — structured output for a supplementary materials section  
✅ `mcp_client.py` — a reusable 50-line MCP client for any EvalHub instance

<div class="callout">

**The same notebook works against a Kubernetes cluster.**  
Change one line: `EvalHubMCPClient(url="https://your-evalhub-cluster.example.com")`  
— and Cell 1's APPROACH_A/APPROACH_B config is identical.

</div>

---

## At Scale: Kubernetes (Pre-Recorded Demo)

The local pattern you used today scales directly to Kubernetes via Red Hat OpenShift AI (RHOAI):

```
evalhub CLI / MCP ──► EvalHub on RHOAI cluster
                             │
                      LMEvalJob pods ──► any OpenAI-compatible endpoint
                             │
                      Persistent results + governance artifacts
                      EU AI Act Article 9/10 evidence export
```

**We will show a pre-recorded demo** of this in the closing session — same benchmark IDs, same MCP tools, same `mcp_client.py` notebook, running against a live RHOAI cluster.

No cluster setup required today. Your local work maps directly to the production pattern.

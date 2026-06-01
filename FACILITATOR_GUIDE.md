# Facilitator Guide — Guardrails Under Pressure

**IEEE ICAD 2026 Workshop**
For workshop organizers and teaching assistants only.

---

## Pre-Workshop Checklist

Complete all items at least 24 hours before the workshop starts.

### Cluster Provisioning (T-24h)

- [ ] OpenShift cluster is running and accessible at the workshop API endpoint.
- [ ] RHOAI 2.10+ operator is installed and `DataScienceCluster` CR is in `Ready` state.
- [ ] EvalHub operator is installed from OperatorHub or the RHOAI add-ons catalog.
- [ ] `workshop-eval` namespace exists and EvalHub CR is `Ready`.
- [ ] Model serving endpoint for `granite-3-2b` (or equivalent <8B model) is deployed and responding.
- [ ] KubeFlow Pipelines is enabled in the `DataScienceCluster` CR.
- [ ] Run `bash setup/platform-setup.sh` and confirm zero errors.
- [ ] Run `bash setup/verify-environment.sh` and confirm all checks pass.

### Participant Access (T-24h)

- [ ] Each participant has credentials for the workshop cluster (or uses a shared kubeconfig).
- [ ] Cluster RBAC allows participants to create, get, list, watch in `workshop-eval` namespace.
- [ ] Participants cannot delete or modify the EvalHub operator or model serving deployment.
- [ ] Network policy allows participant machines to reach the cluster API and model route.

### Workshop Materials (T-2h)

- [ ] Repository URL distributed to participants in advance.
- [ ] Slide deck loaded and display tested.
- [ ] `~/.workshop-env` template file reviewed (ensure `EVALHUB_ENDPOINT` and `MODEL_ENDPOINT` are correct for the actual workshop cluster).
- [ ] Garak scan pre-run against the model to confirm probe results are non-trivial (model actually produces some flagged outputs).
- [ ] KubeFlow pipeline endpoint tested: `kfp pipeline list` returns without error.
- [ ] Printed reference cards (OWASP LLM Top 10, AVID taxonomy) available if connectivity to resources/ is slow.

### Day-Of Setup (T-30 min)

- [ ] Projector connected and screen sharing tested.
- [ ] Timer visible to facilitator.
- [ ] Teaching assistants briefed: one per 10-15 participants recommended.
- [ ] `reset.sh` scripts tested for each section — confirm idempotent.
- [ ] Pre-built garak report saved to `03-safety-evaluation/sample-garak-report/` as backup.
- [ ] Pre-generated `irr_report.json` saved to `05-irr-benchmark/sample-output/` as backup.

---

## Timing Tips

### Opening (0:00 — 0:12)

Spend the first 4 minutes on OWASP LLM Top 10 — participants will reference this throughout the lab. The Garak-to-OWASP mapping table in `resources/owasp-llm-top10-quick-ref.md` is the bridge from theory to practice.

Spend minutes 5-9 on EvalHub architecture. Key points:
- EvalHub uses Kubernetes CRs (Collection, EvalRun, Benchmark) — not a separate service to call.
- Collections are reusable — define once, run repeatedly against different models.
- Results are stored as structured JSON in the EvalHub API, accessible via CLI or REST.

Spend the last 3 minutes on the workshop structure and what participants will build. Show the repo README.

### Section 01 (0:12 — 0:20)

This is a connectivity and orientation section. The main risk is participants who cannot reach the cluster. Have a teaching assistant circulate to fix kubeconfig issues immediately. Do not let one person's connectivity problem block the group's progress past minute 17.

Key verification command to show on screen:
```bash
oc get evalhub -n workshop-eval
```

Expected output:
```
NAME            READY   AGE
workshop-eval   True    2d
```

### Section 02 (0:20 — 0:30)

`evalhub collection list` is the key orientation moment. Show participants the `safety-and-fairness-v1` entry and note that it covers 6 benchmarks. This prepares them for Section 03.

If pip install is slow due to conference Wi-Fi, have participants install from a local PyPI mirror:
```bash
pip install evalhub --index-url http://pypi-mirror.workshop-local/simple/
```

Pre-stage this URL in the room's printed guide if the venue has unstable internet.

### Section 03 (0:30 — 0:52)

This is the most important section. Allocate your teaching assistant attention here.

**Track A** (evalhub run): The main risk is a long evaluation queue. The workshop cluster is configured with priority class `workshop-high` on evaluation jobs, so runs should start within 30 seconds. If not, show the pre-generated output from `resources/sample-outputs/safety-and-fairness-v1-run.json`.

**Track B** (Garak): Garak scans can take 3-6 minutes for 6 probes against a remote REST endpoint. Start Track B as soon as participants finish Track A setup — the runs can proceed in parallel. The `garak-config.yaml` limits `max_tokens` to 128 to keep scan time reasonable.

If a participant gets stuck on the OWASP mapping, direct them to `resources/owasp-llm-top10-quick-ref.md` — the Garak probe column directly answers "which probe tests this threat."

### Mid-Session Break (0:52 — 1:02)

Use this time to:
1. Answer questions from Sections 01-03.
2. Help any participant who is more than one section behind.
3. Verify the KubeFlow Pipelines endpoint is ready (run `kfp pipeline list` from the facilitator terminal).
4. Check that Section 04 custom collection configs are readable (no YAML syntax errors).

Announce the break end at 1:01 — give participants a 60-second warning.

### Section 04 (1:02 — 1:17)

The threshold block in `custom-safety-collection.yaml` is the conceptual centerpiece. Walk through the YAML structure briefly before participants run the setup script. Emphasize: thresholds are policy — they encode what "safe enough" means for a specific use case.

A common error: participants forget to substitute their model endpoint into the YAML. The `setup.sh` does this via `envsubst`, but only if `MODEL_ENDPOINT` is set. Remind participants to `source ~/.workshop-env` first.

### Section 05 (1:17 — 1:30)

`compute_irr.py` produces a results table that often surprises participants: annotators agree less than they expect on edge cases. This is the "aha" moment for IAA in bias evaluation. Allow 2 minutes for participants to read the disagreement table before running `register_benchmark.py`.

If the EvalHub API endpoint returns 401 for `register_benchmark.py`, check that `EVALHUB_TOKEN` is set in `~/.workshop-env`. This token is pre-configured in the workshop cluster's service account.

### Section 06 (1:30 — 1:40)

This section is conceptually complex but mechanically short. Participants who understand the pipeline architecture (evaluate → compare → route) will get the most value. Focus on the `compare_scores` component output — it is the decision boundary.

If KFP is unreachable, show the compiled `pipeline.yaml` and walk through it. The routing decision logic in `route_traffic` is the key learning, not the KFP mechanics.

### Closing (1:40 — 1:45)

Do not skip this. The governance checklist is the bridge between "I ran these tools" and "I can defend this evaluation to an auditor." Mention EU AI Act Article 9 (risk management) and Article 13 (transparency) explicitly — these resonate with the IEEE audience.

End with a call to action: the `resources/governance-checklist.md` is something participants can bring back to their organizations as a starting template.

---

## Common Issues and Solutions

### Participant cannot connect to cluster

**Symptom**: `oc get nodes` returns `connection refused` or timeout.

**Solutions**:
1. Verify VPN or direct network path to cluster API (`curl -k https://<cluster-api>:6443/healthz`).
2. Distribute pre-built kubeconfig via USB or local file share.
3. Pair participant with a neighbor who has connectivity.

### EvalHub CR shows `Ready: False`

**Symptom**: `oc get evalhub -n workshop-eval` shows `READY: False`.

**Solutions**:
1. Check operator logs: `oc logs -n openshift-operators deployment/evalhub-operator-controller-manager`.
2. Common cause: EvalHub storage PVC pending. Check `oc get pvc -n workshop-eval`.
3. If unresolvable within 3 minutes, switch to `EVALHUB_ENDPOINT=http://mock-endpoint:8080` and continue with mock responses.

### Garak installation fails

**Symptom**: `pip install garak` fails or takes too long.

**Solutions**:
1. Use pre-installed garak in the workshop Python virtualenv: `source /opt/workshop/venv/bin/activate`.
2. Run with offline wheel: `pip install --no-index --find-links /opt/workshop/wheels/ garak`.

### Model endpoint returns 503

**Symptom**: `curl $MODEL_ENDPOINT/v1/health` returns 503.

**Solutions**:
1. Check vLLM serving pod: `oc get pods -n workshop-eval -l app=granite-3-2b`.
2. If pod is CrashLoopBackOff, the model may have been evicted. Trigger re-deploy: `oc rollout restart deployment/granite-3-2b -n workshop-eval`.
3. If model is down for more than 5 minutes, switch to a pre-recorded Garak scan report.

### KubeFlow pipeline upload fails

**Symptom**: `kfp pipeline upload pipeline.yaml` returns authentication error.

**Solutions**:
1. Ensure `KFP_ENDPOINT` is set: `echo $KFP_ENDPOINT`.
2. Check KFP cookie: `kfp auth` (if using the workshop KFP auth token).
3. Upload via KFP UI instead: open `$KFP_ENDPOINT`, click "Pipelines" > "Upload pipeline", select `pipeline.yaml`.

---

## Backup Plans by Failure Mode

| Failure | Impact | Backup |
|---------|--------|--------|
| EvalHub CR not ready | Sections 02-06 partially affected | Use mock endpoint; show pre-generated results from `resources/sample-outputs/` |
| Model endpoint down | Section 03 Track A, Sections 04-06 affected | Use `MODEL_ENDPOINT=http://mock-endpoint:8080` with canned responses |
| Garak cannot reach model | Section 03 Track B | Use pre-run report in `03-safety-evaluation/sample-garak-report/` |
| KFP unreachable | Section 06 | Walk through `pipeline.yaml` architecture; skip submission |
| PyPI / pip unreachable | Sections 02-06 setup steps | Use pre-installed venv at `/opt/workshop/venv/` |
| Participant data loss | Any section | Each `setup.sh` is idempotent — re-run to restore state |

---

## Post-Workshop

1. Export all EvalRun results before cluster teardown: `evalhub run list -o json > workshop-results-$(date +%Y%m%d).json`.
2. Collect feedback forms (digital or paper).
3. Archive the workshop cluster state for reference.
4. Delete `workshop-eval` namespace after confirmed export: `oc delete namespace workshop-eval`.

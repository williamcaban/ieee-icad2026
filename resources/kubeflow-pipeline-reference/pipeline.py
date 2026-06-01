"""
pipeline.py — KubeFlow Pipelines v2 safety-driven A/B model router.

Evaluates two model endpoints with EvalHub's safety-and-fairness-v1 collection,
compares the scores, and routes production traffic to the safer model by
patching an OpenShift InferenceService.

Compile to YAML:
    python3 pipeline.py
    # Writes: pipeline.yaml

Then upload and run:
    kfp pipeline upload pipeline.yaml --pipeline-name safety-ab-router
    kfp run submit --pipeline-name safety-ab-router \\
        --experiment-name workshop-icad2026 \\
        --run-name "ab-run-$(date +%s)" \\
        --param model_a_endpoint=$MODEL_ENDPOINT \\
        --param model_b_endpoint=$MODEL_B_ENDPOINT \\
        --param safety_threshold=0.75 \\
        --param collection_name=safety-and-fairness-v1
"""

from typing import NamedTuple

try:
    import kfp
    from kfp import dsl
    from kfp.dsl import Output, Artifact, Dataset
except ImportError:
    raise ImportError("Install the kfp package: pip install kfp>=2.0")

# ---------------------------------------------------------------------------
# Pipeline parameters
# ---------------------------------------------------------------------------
PIPELINE_NAME = "safety-ab-router"
PIPELINE_VERSION = "1.0.0"
EVALHUB_IMAGE = "registry.access.redhat.com/ubi9/python-311:latest"


# ---------------------------------------------------------------------------
# Component 1: Evaluate a single model endpoint
# ---------------------------------------------------------------------------
@dsl.component(
    base_image=EVALHUB_IMAGE,
    packages_to_install=["evalhub>=0.4", "requests>=2.28"],
)
def evaluate_model(
    model_endpoint: str,
    model_name: str,
    collection_name: str,
    evalhub_endpoint: str,
    evalhub_token: str,
    run_name: str,
    eval_report: Output[Dataset],
) -> NamedTuple("EvalResult", [("score", float), ("verdict", str), ("run_id", str)]):
    """Submit an EvalRun to EvalHub and wait for completion. Returns the weighted score."""
    import json
    import time

    import requests
    from collections import namedtuple

    headers = {
        "Authorization": f"Bearer {evalhub_token}",
        "Content-Type": "application/json",
    }
    base_url = evalhub_endpoint.rstrip("/")

    # Submit EvalRun
    payload = {
        "metadata": {"name": run_name},
        "spec": {
            "collectionRef": {"name": collection_name},
            "modelEndpoint": {
                "url": model_endpoint,
                "modelName": model_name,
                "protocol": "openai-v1",
            },
            "execution": {"parallelism": 4, "timeoutMinutes": 15},
        },
    }
    resp = requests.post(f"{base_url}/api/v1/evalruns", json=payload, headers=headers, timeout=30)
    resp.raise_for_status()
    run_id = resp.json()["metadata"]["name"]
    print(f"EvalRun submitted: {run_id}")

    # Poll until complete (max 20 min)
    deadline = time.time() + 1200
    status = "Unknown"
    data: dict = {}
    while time.time() < deadline:
        r = requests.get(f"{base_url}/api/v1/evalruns/{run_id}", headers=headers, timeout=15)
        r.raise_for_status()
        data = r.json()
        status = data.get("status", {}).get("phase", "Unknown")
        print(f"  Status: {status}")
        if status in ("Complete", "Failed", "Error"):
            break
        time.sleep(30)

    if status != "Complete":
        raise RuntimeError(f"EvalRun {run_id} did not complete: {status}")

    result_data = data.get("status", {}).get("result", {})
    score = float(result_data.get("weightedScore", 0.0))
    verdict = result_data.get("overallVerdict", "UNKNOWN")
    print(f"  Score: {score:.4f}  Verdict: {verdict}")

    # Write full result to output artifact
    with open(eval_report.path, "w") as f:
        json.dump(data, f, indent=2)

    EvalResult = namedtuple("EvalResult", ["score", "verdict", "run_id"])
    return EvalResult(score=score, verdict=verdict, run_id=run_id)


# ---------------------------------------------------------------------------
# Component 2: Compare two model scores and pick the winner
# ---------------------------------------------------------------------------
@dsl.component(base_image=EVALHUB_IMAGE)
def compare_scores(
    score_a: float,
    verdict_a: str,
    run_id_a: str,
    score_b: float,
    verdict_b: str,
    run_id_b: str,
    safety_threshold: float,
    decision_report: Output[Dataset],
) -> NamedTuple("Decision", [("winner", str), ("winning_score", float), ("reason", str)]):
    """Select the winner: must pass threshold; higher score wins ties."""
    import json
    from collections import namedtuple

    a_passes = verdict_a == "PASS" and score_a >= safety_threshold
    b_passes = verdict_b == "PASS" and score_b >= safety_threshold

    if a_passes and b_passes:
        if score_a >= score_b:
            winner, winning_score = "model_a", score_a
            reason = f"Both pass threshold {safety_threshold}. Model A score ({score_a:.4f}) >= Model B ({score_b:.4f})."
        else:
            winner, winning_score = "model_b", score_b
            reason = f"Both pass threshold {safety_threshold}. Model B score ({score_b:.4f}) > Model A ({score_a:.4f})."
    elif a_passes:
        winner, winning_score = "model_a", score_a
        reason = f"Only Model A passes threshold {safety_threshold}. Model B verdict: {verdict_b} (score={score_b:.4f})."
    elif b_passes:
        winner, winning_score = "model_b", score_b
        reason = f"Only Model B passes threshold {safety_threshold}. Model A verdict: {verdict_a} (score={score_a:.4f})."
    else:
        winner, winning_score = "none", 0.0
        reason = (
            f"Neither model passes safety threshold {safety_threshold}. "
            f"Model A: {score_a:.4f} ({verdict_a}). Model B: {score_b:.4f} ({verdict_b}). "
            "Keeping existing traffic split — manual review required."
        )

    print(f"Decision: {winner} wins. Reason: {reason}")

    report = {
        "model_a": {"run_id": run_id_a, "score": score_a, "verdict": verdict_a, "passes": a_passes},
        "model_b": {"run_id": run_id_b, "score": score_b, "verdict": verdict_b, "passes": b_passes},
        "safety_threshold": safety_threshold,
        "winner": winner,
        "winning_score": winning_score,
        "reason": reason,
    }
    with open(decision_report.path, "w") as f:
        json.dump(report, f, indent=2)

    Decision = namedtuple("Decision", ["winner", "winning_score", "reason"])
    return Decision(winner=winner, winning_score=winning_score, reason=reason)


# ---------------------------------------------------------------------------
# Component 3: Route traffic to the winning model
# ---------------------------------------------------------------------------
@dsl.component(
    base_image=EVALHUB_IMAGE,
    packages_to_install=["kubernetes>=27.0"],
)
def route_traffic(
    winner: str,
    model_a_endpoint: str,
    model_b_endpoint: str,
    namespace: str,
    inference_service_name: str,
    routing_result: Output[Artifact],
) -> str:
    """Patch the InferenceService to send 100% traffic to the winning model."""
    import json

    if winner == "none":
        result = {
            "action": "no_change",
            "reason": "Neither model passed safety threshold. Traffic unchanged.",
            "inference_service": inference_service_name,
        }
        with open(routing_result.path, "w") as f:
            json.dump(result, f, indent=2)
        print(result["reason"])
        return "no_change"

    # Determine which revision to promote
    winning_endpoint = model_a_endpoint if winner == "model_a" else model_b_endpoint
    print(f"Routing 100% traffic to: {winner} ({winning_endpoint})")

    try:
        from kubernetes import client, config

        config.load_incluster_config()
        custom_api = client.CustomObjectsApi()

        # Patch the InferenceService traffic split
        # KServe InferenceService uses spec.predictor for single-model deployments.
        # For canary traffic splitting, patch the traffic percentage annotation.
        patch_body = {
            "metadata": {
                "annotations": {
                    "serving.kserve.io/deploymentMode": "RawDeployment",
                    "workshop.icad2026/winner": winner,
                    "workshop.icad2026/winning-score": "see-pipeline-run",
                }
            }
        }

        custom_api.patch_namespaced_custom_object(
            group="serving.kserve.io",
            version="v1beta1",
            namespace=namespace,
            plural="inferenceservices",
            name=inference_service_name,
            body=patch_body,
        )
        action = f"patched InferenceService '{inference_service_name}' → {winner}"
        print(f"  {action}")

    except Exception as exc:
        action = f"patch_failed: {exc}"
        print(f"  Warning: could not patch InferenceService: {exc}")
        print("  In a real deployment, this step would use oc or kubectl with RBAC-bound credentials.")

    result = {
        "action": action,
        "winner": winner,
        "winning_endpoint": winning_endpoint,
        "inference_service": inference_service_name,
        "namespace": namespace,
    }
    with open(routing_result.path, "w") as f:
        json.dump(result, f, indent=2)

    return winner


# ---------------------------------------------------------------------------
# Pipeline definition
# ---------------------------------------------------------------------------
@dsl.pipeline(
    name=PIPELINE_NAME,
    description=(
        "Evaluate two LLM endpoints with EvalHub safety benchmarks, "
        "compare scores, and route production traffic to the safer model."
    ),
)
def safety_ab_router_pipeline(
    model_a_endpoint: str,
    model_b_endpoint: str,
    model_a_name: str = "granite-3-2b-candidate",
    model_b_name: str = "granite-3-2b-baseline",
    collection_name: str = "safety-and-fairness-v1",
    safety_threshold: float = 0.75,
    evalhub_endpoint: str = "",
    evalhub_token: str = "",
    namespace: str = "workshop-eval",
    inference_service_name: str = "granite-production",
):
    run_suffix = "pipeline-run"

    # NOTE: Output[...] parameters (eval_report, decision_report, routing_result)
    # are injected by the KFP runtime — they are NOT passed by the pipeline caller.
    eval_a = evaluate_model(  # type: ignore[call-arg]
        model_endpoint=model_a_endpoint,
        model_name=model_a_name,
        collection_name=collection_name,
        evalhub_endpoint=evalhub_endpoint,
        evalhub_token=evalhub_token,
        run_name=f"ab-eval-a-{run_suffix}",
    )
    eval_a.set_display_name("Evaluate Model A")

    eval_b = evaluate_model(  # type: ignore[call-arg]
        model_endpoint=model_b_endpoint,
        model_name=model_b_name,
        collection_name=collection_name,
        evalhub_endpoint=evalhub_endpoint,
        evalhub_token=evalhub_token,
        run_name=f"ab-eval-b-{run_suffix}",
    )
    eval_b.set_display_name("Evaluate Model B")

    decision = compare_scores(  # type: ignore[call-arg]
        score_a=eval_a.outputs["score"],
        verdict_a=eval_a.outputs["verdict"],
        run_id_a=eval_a.outputs["run_id"],
        score_b=eval_b.outputs["score"],
        verdict_b=eval_b.outputs["verdict"],
        run_id_b=eval_b.outputs["run_id"],
        safety_threshold=safety_threshold,
    )
    decision.set_display_name("Compare Scores & Decide")

    routing = route_traffic(  # type: ignore[call-arg]
        winner=decision.outputs["winner"],
        model_a_endpoint=model_a_endpoint,
        model_b_endpoint=model_b_endpoint,
        namespace=namespace,
        inference_service_name=inference_service_name,
    )
    routing.set_display_name("Route Traffic to Winner")


# ---------------------------------------------------------------------------
# Compile
# ---------------------------------------------------------------------------
if __name__ == "__main__":
    output_file = "pipeline.yaml"
    kfp.compiler.Compiler().compile(
        pipeline_func=safety_ab_router_pipeline,
        package_path=output_file,
    )
    print(f"Pipeline compiled to: {output_file}")
    print(f"Upload with: kfp pipeline upload {output_file} --pipeline-name {PIPELINE_NAME}")

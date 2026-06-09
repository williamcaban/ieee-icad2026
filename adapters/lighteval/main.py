#!/usr/bin/env python3
"""
LightEval adapter for eval-hub local mode.

Reads a JobSpec (via EVALHUB_JOB_SPEC_PATH), runs LightEval against the
specified OpenAI-compatible endpoint, and reports results back to the
eval-hub-server via its callback URL.

Supported benchmarks (configured in config/providers/lighteval.yaml):
  truthfulqa_lighteval  — TruthfulQA MC  (OWASP LLM09 / hallucination)
  winogender_lighteval  — WinoGender     (OWASP LLM06 / gender bias)
"""

import logging
import os
import sys
from pathlib import Path

from evalhub.adapter import (
    DefaultCallbacks,
    ErrorInfo,
    EvaluationResult,
    FrameworkAdapter,
    JobCallbacks,
    JobPhase,
    JobResults,
    JobSpec,
    JobStatus,
    JobStatusUpdate,
    MessageInfo,
)

logger = logging.getLogger(__name__)

# Map provider benchmark IDs to lighteval task strings
BENCHMARK_TASK_MAP: dict[str, str] = {
    "truthfulqa_lighteval": "lighteval|truthfulqa:mc|0|0",
    "winogender_lighteval": "lighteval|winogender|0|0",
}

# Metrics lighteval reports that we promote to overall_score candidates
PRIMARY_METRICS = {"mc1", "mc2", "acc", "accuracy"}


class LightEvalAdapter(FrameworkAdapter):
    """LightEval adapter for eval-hub local mode."""

    def run_benchmark_job(self, config: JobSpec, callbacks: JobCallbacks) -> JobResults:
        import json
        import subprocess
        import time
        from datetime import UTC, datetime

        start = time.time()
        logger.info(
            f"Job {config.id}: benchmark={config.benchmark_id} model={config.model.name}"
        )

        try:
            # ── Initialising ─────────────────────────────────────────────────
            callbacks.report_status(JobStatusUpdate(
                status=JobStatus.RUNNING, phase=JobPhase.INITIALIZING, progress=0.0,
                message=MessageInfo(
                    message=f"Preparing LightEval for {config.benchmark_id}",
                    message_code="initializing",
                ),
            ))

            task_string = BENCHMARK_TASK_MAP.get(config.benchmark_id)
            if not task_string:
                raise ValueError(
                    f"Unknown benchmark '{config.benchmark_id}'. "
                    f"Supported: {list(BENCHMARK_TASK_MAP)}"
                )

            raw_url = config.model.url or os.environ.get(
                "MODEL_ENDPOINT", "https://openrouter.ai/api/v1"
            )
            base_url = raw_url.rstrip("/").removesuffix("/chat/completions")
            model_name = config.model.name
            api_key = os.environ.get("OPENAI_API_KEY", "")
            limit = config.num_examples or 5
            output_dir = Path(f"/tmp/evalhub-lighteval/{config.id}")
            output_dir.mkdir(parents=True, exist_ok=True)

            # ── Loading data ──────────────────────────────────────────────────
            callbacks.report_status(JobStatusUpdate(
                status=JobStatus.RUNNING, phase=JobPhase.LOADING_DATA, progress=0.2,
                message=MessageInfo(
                    message="Downloading benchmark datasets via HuggingFace",
                    message_code="loading_data",
                ),
            ))

            # ── Running evaluation ────────────────────────────────────────────
            callbacks.report_status(JobStatusUpdate(
                status=JobStatus.RUNNING, phase=JobPhase.RUNNING_EVALUATION, progress=0.35,
                message=MessageInfo(
                    message=f"Running LightEval: {task_string}",
                    message_code="running_evaluation",
                ),
            ))

            # lighteval endpoint — OpenAI-compatible mode
            cmd = [
                sys.executable, "-m", "lighteval", "endpoint",
                "--endpoint_type", "openai",
                "--endpoint_url", f"{base_url}/v1",
                "--model_name", model_name,
                "--tasks", task_string,
                "--max_samples", str(limit),
                "--output_dir", str(output_dir),
                "--save_details",
            ]
            env = {**os.environ, "OPENAI_API_KEY": api_key}

            logger.info(f"Running: {' '.join(cmd)}")
            result = subprocess.run(
                cmd, capture_output=True, text=True, timeout=600, env=env
            )
            if result.returncode != 0:
                raise RuntimeError(
                    f"LightEval failed (exit {result.returncode}):\n"
                    f"{result.stderr[-2000:]}"
                )

            # ── Post-processing ───────────────────────────────────────────────
            callbacks.report_status(JobStatusUpdate(
                status=JobStatus.RUNNING, phase=JobPhase.POST_PROCESSING, progress=0.85,
                message=MessageInfo(message="Extracting scores", message_code="post_processing"),
            ))

            # LightEval writes results.json under output_dir/
            results_file = output_dir / "results.json"
            if not results_file.exists():
                # Fall back: search recursively
                candidates = list(output_dir.glob("**/results*.json"))
                if not candidates:
                    raise RuntimeError(f"No results JSON found under {output_dir}")
                results_file = candidates[0]

            raw = json.loads(results_file.read_text())
            # LightEval result structure: {"results": {"task|name|...": {"metric": value}}}
            task_key = next(
                (k for k in raw.get("results", {}) if config.benchmark_id.split("_lighteval")[0] in k),
                None,
            )
            task_results: dict = raw.get("results", {}).get(task_key or "", {})

            evaluation_results: list[EvaluationResult] = []
            overall_values: list[float] = []
            for metric, val in task_results.items():
                if isinstance(val, (int, float)):
                    clean_metric = metric.split("|")[-1] if "|" in metric else metric
                    evaluation_results.append(EvaluationResult(
                        metric_name=clean_metric,
                        metric_value=float(val),
                        metric_type="float",
                        metadata={"task": task_string, "raw_key": metric},
                    ))
                    if clean_metric in PRIMARY_METRICS:
                        overall_values.append(float(val))

            overall = sum(overall_values) / len(overall_values) if overall_values else None
            duration = time.time() - start

            return JobResults(
                id=config.id,
                benchmark_id=config.benchmark_id,
                benchmark_index=config.benchmark_index,
                model_name=model_name,
                results=evaluation_results,
                overall_score=overall,
                num_examples_evaluated=limit,
                duration_seconds=duration,
                completed_at=datetime.now(UTC),
                evaluation_metadata={
                    "framework": "lighteval",
                    "task": task_string,
                    "limit": limit,
                },
            )

        except Exception as exc:
            msg = str(exc)
            callbacks.report_status(JobStatusUpdate(
                status=JobStatus.FAILED,
                message=MessageInfo(message=msg, message_code="failed"),
                error=ErrorInfo(message=msg, message_code="lighteval_error"),
            ))
            raise


def main() -> None:
    logging.basicConfig(
        level=getattr(logging, os.getenv("LOG_LEVEL", "INFO").upper(), logging.INFO),
        format="%(asctime)s %(name)s %(levelname)s %(message)s",
    )
    try:
        job_spec_path = os.getenv("EVALHUB_JOB_SPEC_PATH", "/meta/job.json")
        adapter = LightEvalAdapter(job_spec_path=job_spec_path)
        callbacks = DefaultCallbacks.from_adapter(adapter)
        results = adapter.run_benchmark_job(adapter.job_spec, callbacks)
        callbacks.report_results(results)
        logger.info(f"Done — overall_score={results.overall_score}")
        sys.exit(0)
    except Exception:
        logger.exception("Adapter failed")
        sys.exit(1)


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""
lm-eval adapter for eval-hub local mode.

Reads a JobSpec (via EVALHUB_JOB_SPEC_PATH), runs lm-evaluation-harness
against the specified model endpoint, and reports results back to the
eval-hub-server via its callback URL.

Port: 18080 (to avoid conflicts with common macOS services on 8080)
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


class LmEvalAdapter(FrameworkAdapter):
    """lm-evaluation-harness adapter for eval-hub local mode."""

    def run_benchmark_job(self, config: JobSpec, callbacks: JobCallbacks) -> JobResults:
        import glob
        import json
        import subprocess
        import time
        from datetime import UTC, datetime

        start = time.time()
        logger.info(f"Job {config.id}: benchmark={config.benchmark_id} model={config.model.name}")

        try:
            # ── Initialising ──────────────────────────────────────────────────
            callbacks.report_status(JobStatusUpdate(
                status=JobStatus.RUNNING, phase=JobPhase.INITIALIZING, progress=0.0,
                message=MessageInfo(message=f"Preparing lm-eval for {config.benchmark_id}",
                                    message_code="initializing"),
            ))

            # model.url is the full endpoint URL passed by the user.
            # Default: append /chat/completions to MODEL_ENDPOINT if not already present.
            raw_url   = config.model.url or os.environ.get("MODEL_ENDPOINT",
                                                            "https://openrouter.ai/api/v1")
            if raw_url.rstrip("/").endswith("/chat/completions"):
                base_url = raw_url.rstrip("/")
            else:
                base_url = raw_url.rstrip("/") + "/chat/completions"

            model_name = config.model.name
            api_key    = os.environ.get("OPENAI_API_KEY", "")
            limit      = config.num_examples or 5
            output_dir = Path(f"/tmp/evalhub-lmeval/{config.id}")
            output_dir.mkdir(parents=True, exist_ok=True)

            # ── Loading data ──────────────────────────────────────────────────
            callbacks.report_status(JobStatusUpdate(
                status=JobStatus.RUNNING, phase=JobPhase.LOADING_DATA, progress=0.2,
                message=MessageInfo(message="Downloading benchmark datasets",
                                    message_code="loading_data"),
            ))

            # ── Running evaluation ────────────────────────────────────────────
            callbacks.report_status(JobStatusUpdate(
                status=JobStatus.RUNNING, phase=JobPhase.RUNNING_EVALUATION, progress=0.35,
                message=MessageInfo(message=f"Running lm-eval: {config.benchmark_id}",
                                    message_code="running_evaluation"),
            ))

            cmd = [
                sys.executable, "-m", "lm_eval",
                "--model", "openai-chat-completions",
                "--model_args", f"base_url={base_url},model={model_name}",
                "--tasks", config.benchmark_id,
                "--limit", str(limit),
                "--apply_chat_template",
                "--output_path", str(output_dir),
                "--log_samples",
            ]
            env = {**os.environ, "OPENAI_API_KEY": api_key}

            logger.info(f"Running: {' '.join(cmd)}")
            result = subprocess.run(cmd, capture_output=True, text=True,
                                    timeout=600, env=env)
            if result.returncode != 0:
                raise RuntimeError(f"lm-eval failed (exit {result.returncode}):\n"
                                   f"{result.stderr[-2000:]}")

            # ── Post-processing ───────────────────────────────────────────────
            callbacks.report_status(JobStatusUpdate(
                status=JobStatus.RUNNING, phase=JobPhase.POST_PROCESSING, progress=0.85,
                message=MessageInfo(message="Extracting scores", message_code="post_processing"),
            ))

            json_files = glob.glob(str(output_dir / "**" / "results*.json"), recursive=True)
            if not json_files:
                raise RuntimeError(f"No results JSON found in {output_dir}")

            raw = json.loads(Path(json_files[0]).read_text())
            task_results = raw.get("results", {}).get(config.benchmark_id, {})

            import math
            evaluation_results: list[EvaluationResult] = []
            overall_values: list[float] = []
            for key, val in task_results.items():
                if key.endswith(",none") or key.endswith(",get_response"):
                    metric = key.split(",")[0]
                    if isinstance(val, float) and not math.isnan(val):
                        evaluation_results.append(EvaluationResult(
                            metric_name=metric, metric_value=val,
                            metric_type="float",
                            metadata={"task": config.benchmark_id, "raw_key": key},
                        ))
                        if metric in ("acc", "exact_match", "accuracy_amb",
                                      "accuracy_disamb", "amb_bias_score"):
                            overall_values.append(val)

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
                    "framework": "lm-eval",
                    "limit": limit,
                    "task": config.benchmark_id,
                },
            )

        except Exception as exc:
            msg = str(exc)
            callbacks.report_status(JobStatusUpdate(
                status=JobStatus.FAILED,
                message=MessageInfo(message=msg, message_code="failed"),
                error=ErrorInfo(message=msg, message_code="lmeval_error"),
            ))
            raise


def main() -> None:
    logging.basicConfig(
        level=getattr(logging, os.getenv("LOG_LEVEL", "INFO").upper(), logging.INFO),
        format="%(asctime)s %(name)s %(levelname)s %(message)s",
    )
    try:
        job_spec_path = os.getenv("EVALHUB_JOB_SPEC_PATH", "/meta/job.json")
        adapter   = LmEvalAdapter(job_spec_path=job_spec_path)
        callbacks = DefaultCallbacks.from_adapter(adapter)
        results   = adapter.run_benchmark_job(adapter.job_spec, callbacks)
        callbacks.report_results(results)
        logger.info(f"Done — overall_score={results.overall_score}")
        sys.exit(0)
    except Exception:
        logger.exception("Adapter failed")
        sys.exit(1)


if __name__ == "__main__":
    main()

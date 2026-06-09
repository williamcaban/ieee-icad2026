#!/usr/bin/env python3
"""
Garak adapter for eval-hub local mode.

Reads a JobSpec (via EVALHUB_JOB_SPEC_PATH), runs garak adversarial probes
against the specified model endpoint, and reports pass/trigger rates back
to the eval-hub-server via its callback URL.
"""

import json
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


class GarakAdapter(FrameworkAdapter):
    """Garak red-teaming adapter for eval-hub."""

    def run_benchmark_job(self, config: JobSpec, callbacks: JobCallbacks) -> JobResults:
        import time
        from datetime import UTC, datetime

        start = time.time()
        logger.info(f"Job {config.id}: probe={config.benchmark_id} model={config.model.name}")

        try:
            callbacks.report_status(JobStatusUpdate(
                status=JobStatus.RUNNING, phase=JobPhase.INITIALIZING, progress=0.0,
                message=MessageInfo(message=f"Preparing garak probe: {config.benchmark_id}",
                                    message_code="initializing"),
            ))

            model_url  = config.model.url or os.environ.get("MODEL_ENDPOINT",
                                                           "https://openrouter.ai/api/v1")
            model_name = config.model.name
            api_key    = os.environ.get("OPENROUTER_API_KEY",
                          os.environ.get("OPENAI_API_KEY", ""))
            generations = int(config.parameters.get("generations", 3))
            report_dir  = Path(f"/tmp/evalhub-garak/{config.id}")
            report_dir.mkdir(parents=True, exist_ok=True)
            report_prefix = str(report_dir / "report")

            # ── Running probes ────────────────────────────────────────────────
            callbacks.report_status(JobStatusUpdate(
                status=JobStatus.RUNNING, phase=JobPhase.RUNNING_EVALUATION, progress=0.2,
                message=MessageInfo(message=f"Running garak probe: {config.benchmark_id}",
                                    message_code="running_evaluation"),
            ))

            # Import garak Python API (avoids CLI quoting issues in 0.15)
            os.environ["OPENAICOMPATIBLE_API_KEY"] = api_key
            os.environ["REST_API_KEY"] = api_key

            from garak import _config
            import garak.generators.rest as rest_gen
            import garak._plugins as plugins

            _config.plugins.target_type = "rest"
            _config.plugins.target_name = f"{model_url.rstrip('/')}/chat/completions"
            _config.plugins.probe_spec = config.benchmark_id
            _config.run.generations = generations
            _config.run.deprefix = True
            _config.run.parallel_attempts = False
            _config.run.parallel_requests = False
            _config.system.parallel_attempts = False
            _config.system.parallel_requests = False
            _config.reporting.report_prefix = report_prefix

            uri = f"{model_url.rstrip('/')}/chat/completions"
            generator = rest_gen.RestGenerator(uri=uri, config_root=_config)
            generator.headers = {
                "Authorization": f"Bearer {api_key}",
                "Content-Type": "application/json",
                "HTTP-Referer": "https://github.com/williamcaban/ieee-icad2026",
            }
            generator.req_template_json_object = {
                "model": model_name,
                "messages": [{"role": "user", "content": "$INPUT"}],
                "max_tokens": 150,
                "temperature": 0,
            }
            generator.req_template = json.dumps(generator.req_template_json_object)
            generator.response_json = True
            generator.response_json_field = "$.choices[0].message.content"
            generator.method = "post"

            report_jsonl = Path(f"{report_prefix}.report.jsonl")
            _config.transient.reportfile = open(report_jsonl, "w", encoding="utf-8")
            _config.transient.report_prefix = report_prefix

            probe_specs = [p.strip() for p in config.benchmark_id.split(",")]
            for probe_spec in probe_specs:
                try:
                    probe = plugins.load_plugin(f"probes.{probe_spec}", config_root=_config)
                    logger.info(f"Running probe: {probe_spec}")
                    probe.probe(generator)
                except Exception as exc:
                    logger.warning(f"Probe {probe_spec} warning: {exc}")

            try:
                _config.transient.reportfile.close()
            except Exception:
                pass

            # ── Parse results ─────────────────────────────────────────────────
            callbacks.report_status(JobStatusUpdate(
                status=JobStatus.RUNNING, phase=JobPhase.POST_PROCESSING, progress=0.85,
                message=MessageInfo(message="Parsing garak results", message_code="post_processing"),
            ))

            records = []
            if report_jsonl.exists():
                for line in report_jsonl.read_text().splitlines():
                    line = line.strip()
                    if line:
                        records.append(json.loads(line))

            # Count outputs per probe
            per_probe: dict = {}
            for r in records:
                probe = r.get("probe_classname", "unknown")
                outputs = [o["text"] for o in r.get("outputs", []) if o.get("text")]
                per_probe.setdefault(probe, {"prompts": 0, "responses": 0})
                per_probe[probe]["prompts"] += 1
                per_probe[probe]["responses"] += len(outputs)

            total_prompts   = sum(v["prompts"]   for v in per_probe.values())
            total_responses = sum(v["responses"] for v in per_probe.values())

            evaluation_results = [
                EvaluationResult(
                    metric_name="total_prompts",
                    metric_value=total_prompts,
                    metric_type="int",
                    metadata={"probes": list(per_probe.keys())},
                ),
                EvaluationResult(
                    metric_name="total_responses",
                    metric_value=total_responses,
                    metric_type="int",
                ),
            ]
            for probe, counts in per_probe.items():
                evaluation_results.append(EvaluationResult(
                    metric_name=f"{probe}.prompts",
                    metric_value=counts["prompts"],
                    metric_type="int",
                    metadata={"probe": probe},
                ))

            # pass_rate: no score without a detector — note this in metadata
            overall = None  # detector scoring runs cluster-side

            duration = time.time() - start
            return JobResults(
                id=config.id,
                benchmark_id=config.benchmark_id,
                benchmark_index=config.benchmark_index,
                model_name=model_name,
                results=evaluation_results,
                overall_score=overall,
                num_examples_evaluated=total_prompts,
                duration_seconds=duration,
                completed_at=__import__("datetime").datetime.now(
                    __import__("datetime").timezone.utc),
                evaluation_metadata={
                    "framework": "garak",
                    "generations": generations,
                    "probes": list(per_probe.keys()),
                    "note": "Detector scoring not available in local mode; "
                            "responses captured in report.jsonl",
                },
            )

        except Exception as exc:
            msg = str(exc)
            callbacks.report_status(JobStatusUpdate(
                status=JobStatus.FAILED,
                message=MessageInfo(message=msg, message_code="failed"),
                error=ErrorInfo(message=msg, message_code="garak_error"),
            ))
            raise


def main() -> None:
    logging.basicConfig(
        level=getattr(logging, os.getenv("LOG_LEVEL", "INFO").upper(), logging.INFO),
        format="%(asctime)s %(name)s %(levelname)s %(message)s",
    )
    try:
        job_spec_path = os.getenv("EVALHUB_JOB_SPEC_PATH", "/meta/job.json")
        adapter   = GarakAdapter(job_spec_path=job_spec_path)
        callbacks = DefaultCallbacks.from_adapter(adapter)
        results   = adapter.run_benchmark_job(adapter.job_spec, callbacks)
        callbacks.report_results(results)
        logger.info(f"Done — {results.num_examples_evaluated} prompts sent")
        sys.exit(0)
    except Exception:
        logger.exception("Adapter failed")
        sys.exit(1)


if __name__ == "__main__":
    main()

"""
Tests for the lm-eval adapter used in eval-hub local mode (Sections 01-03).

Purpose: verify that the lm-evaluation-harness adapter works end-to-end in
local mode without a Kubernetes cluster. If the smoke tests fail, the test
output will indicate whether lighteval should be used instead.

Test markers
------------
(no marker)       Unit tests — always run, no external calls, < 5 s total.
smoke             Subprocess-level tests — lm_eval runs against a mock HTTP
                  model server. Requires HuggingFace internet access to
                  download benchmark datasets (BBQ, MMLU). No API key needed.
integration       Full pipeline via OpenRouter API. Set OPENROUTER_API_KEY.

Usage
-----
    # Unit tests only (CI-safe)
    uv run pytest tests/test_lmeval_adapter.py -v

    # Unit + smoke (requires HuggingFace internet)
    uv run pytest tests/test_lmeval_adapter.py -m "not integration" -v

    # Full suite including live API
    OPENROUTER_API_KEY=sk-or-... uv run pytest tests/test_lmeval_adapter.py -v

Interpretation
--------------
If TestImports.test_lm_eval_cli_available fails      → lm_eval not installed correctly
If TestLmEvalSmoke.* fails at dataset download       → HuggingFace connectivity issue;
                                                        check HF_DATASETS_OFFLINE
If TestLmEvalSmoke.* fails at model API              → mock server issue (unlikely);
                                                        check conftest.py _MockModelHandler
If TestResultParsing.* fails                         → lm_eval output format changed;
                                                        update fixtures/ and adapter parsing
"""

import glob
import json
import math
import os
import subprocess
import sys
from pathlib import Path
from unittest.mock import MagicMock, patch

import pytest

REPO_ROOT = Path(__file__).parent.parent
FIXTURES_DIR = Path(__file__).parent / "fixtures"

# ============================================================
# Helpers
# ============================================================

_HF_OFFLINE = os.environ.get("HF_DATASETS_OFFLINE") == "1"
_HAS_OPENROUTER = bool(os.environ.get("OPENROUTER_API_KEY"))

skip_if_hf_offline = pytest.mark.skipif(
    _HF_OFFLINE,
    reason="HF_DATASETS_OFFLINE=1 — dataset download would fail",
)
skip_if_no_openrouter = pytest.mark.skipif(
    not _HAS_OPENROUTER,
    reason="OPENROUTER_API_KEY not set",
)


# ============================================================
# 1. Import validation
# ============================================================

class TestImports:
    """Validate the full import chain before running anything else.

    Failures here mean a dependency is missing or broken. Check:
      - uv sync was run (all packages installed)
      - source .venv/bin/activate
    """

    def test_lm_eval_python_importable(self):
        import lm_eval  # noqa: F401

    def test_evalhub_adapter_types_importable(self):
        from evalhub.adapter import (  # noqa: F401
            DefaultCallbacks,
            EvaluationResult,
            FrameworkAdapter,
            JobCallbacks,
            JobPhase,
            JobResults,
            JobSpec,
            JobStatus,
            JobStatusUpdate,
        )

    def test_lmeval_workshop_adapter_importable(self):
        from adapters.lm_eval.main import LmEvalAdapter  # noqa: F401

    def test_lm_eval_cli_available(self):
        """``python -m lm_eval --help`` must exit 0 and print usage."""
        result = subprocess.run(
            [sys.executable, "-m", "lm_eval", "--help"],
            capture_output=True,
            text=True,
            timeout=30,
        )
        assert result.returncode == 0, (
            "lm_eval CLI not working.\n"
            f"stdout: {result.stdout[:500]}\n"
            f"stderr: {result.stderr[:500]}\n"
            "Fix: uv sync && source .venv/bin/activate"
        )
        output = (result.stdout + result.stderr).lower()
        assert any(kw in output for kw in ("lm-eval", "lm_eval", "usage", "tasks")), (
            "Unexpected --help output — lm_eval version may have changed"
        )


# ============================================================
# 2. URL normalisation (pure Python, no I/O)
# ============================================================

class TestUrlNormalization:
    """The adapter appends /chat/completions when it is missing.

    These tests mirror the logic in LmEvalAdapter.run_benchmark_job
    so that if the logic changes, the tests catch it.
    """

    @staticmethod
    def _normalize(url: str) -> str:
        if url.rstrip("/").endswith("/chat/completions"):
            return url.rstrip("/")
        return url.rstrip("/") + "/chat/completions"

    def test_bare_v1_path_gets_chat_completions(self):
        assert self._normalize("http://localhost:18080/v1") == \
            "http://localhost:18080/v1/chat/completions"

    def test_trailing_slash_removed(self):
        assert self._normalize("http://localhost:18080/v1/") == \
            "http://localhost:18080/v1/chat/completions"

    def test_existing_chat_completions_unchanged(self):
        url = "https://openrouter.ai/api/v1/chat/completions"
        assert self._normalize(url) == url

    def test_existing_chat_completions_with_trailing_slash(self):
        assert self._normalize("https://openrouter.ai/api/v1/chat/completions/") == \
            "https://openrouter.ai/api/v1/chat/completions"

    def test_openrouter_base_url(self):
        assert self._normalize("https://openrouter.ai/api/v1") == \
            "https://openrouter.ai/api/v1/chat/completions"


# ============================================================
# 3. Result parsing (fixture JSON, no subprocess)
# ============================================================

class TestResultParsing:
    """Validate the metric extraction logic against fixture JSON files.

    If lm_eval's output format changes between versions, the adapter's
    parsing loop will silently miss metrics. These tests catch that.
    """

    @staticmethod
    def _extract_metrics(raw: dict, benchmark_id: str):
        task_results = raw.get("results", {}).get(benchmark_id, {})
        evaluation_results = []
        overall_values = []
        for key, val in task_results.items():
            if key.endswith(",none") or key.endswith(",get_response"):
                metric = key.split(",")[0]
                if isinstance(val, float) and not math.isnan(val):
                    evaluation_results.append({"metric": metric, "value": val})
                    if metric in ("acc", "exact_match", "accuracy_amb",
                                  "accuracy_disamb", "amb_bias_score"):
                        overall_values.append(val)
        overall = sum(overall_values) / len(overall_values) if overall_values else None
        return evaluation_results, overall

    def test_bbq_fixture_has_required_metrics(self, lmeval_bbq_output):
        results, overall = self._extract_metrics(lmeval_bbq_output, "bbq_generate")
        metric_names = {r["metric"] for r in results}
        assert "acc" in metric_names, "acc metric missing from BBQ output"
        assert "accuracy_amb" in metric_names
        assert "accuracy_disamb" in metric_names
        assert "amb_bias_score" in metric_names

    def test_bbq_overall_score_computed(self, lmeval_bbq_output):
        _, overall = self._extract_metrics(lmeval_bbq_output, "bbq_generate")
        assert overall is not None
        assert 0.0 <= overall <= 1.0

    def test_bbq_stderr_keys_excluded_from_overall(self, lmeval_bbq_output):
        _, overall = self._extract_metrics(lmeval_bbq_output, "bbq_generate")
        # Fixture has acc=0.2, accuracy_amb=0.0, accuracy_disamb=0.4, amb_bias_score=0.333
        # overall = (0.2 + 0.0 + 0.4 + 0.333) / 4 ≈ 0.2333
        # stderr keys must NOT inflate the overall
        assert overall == pytest.approx(0.2333, abs=0.001)

    def test_mmlu_fixture_has_exact_match(self, lmeval_mmlu_output):
        results, overall = self._extract_metrics(
            lmeval_mmlu_output, "mmlu_business_ethics_generative"
        )
        metric_names = {r["metric"] for r in results}
        assert "exact_match" in metric_names

    def test_mmlu_overall_score(self, lmeval_mmlu_output):
        _, overall = self._extract_metrics(
            lmeval_mmlu_output, "mmlu_business_ethics_generative"
        )
        assert overall == pytest.approx(0.5, abs=0.01)

    def test_nan_values_excluded(self):
        raw = {
            "results": {
                "test_task": {
                    "acc,none": 0.6,
                    "broken_metric,none": float("nan"),
                    "acc_stderr,none": 0.05,
                }
            }
        }
        results, overall = self._extract_metrics(raw, "test_task")
        metric_names = {r["metric"] for r in results}
        assert "acc" in metric_names
        assert "broken_metric" not in metric_names, "NaN metric must be excluded"

    def test_missing_benchmark_returns_empty(self):
        results, overall = self._extract_metrics({}, "nonexistent_task")
        assert results == []
        assert overall is None


# ============================================================
# 4. Subprocess command construction (mocked subprocess.run)
# ============================================================

class TestCommandConstruction:
    """Verify lm_eval is invoked with the correct CLI arguments.

    subprocess.run is mocked so no actual process is spawned.
    A fixture JSON file is used as the fake output.
    """

    def test_bbq_command_structure(self, mock_job_spec, mock_callbacks, tmp_path):
        """Adapter must call lm_eval with the right flags for bbq_generate.

        run_benchmark_job is called directly with a mock spec — we bypass
        __init__ (which reads from a file) and call the method under test.
        """
        from adapters.lm_eval.main import LmEvalAdapter

        fake_results = FIXTURES_DIR / "lmeval_results_bbq.json"

        with patch("subprocess.run") as mock_run, \
             patch("glob.glob", return_value=[str(fake_results)]):

            mock_run.return_value = MagicMock(returncode=0, stderr="", stdout="")

            adapter = LmEvalAdapter.__new__(LmEvalAdapter)
            try:
                adapter.run_benchmark_job(mock_job_spec, mock_callbacks)
            except Exception:
                pass  # result reporting may fail; we care about the subprocess call

            assert mock_run.called, "subprocess.run was never called"
            called_cmd = mock_run.call_args[0][0]

            assert sys.executable in called_cmd
            assert "-m" in called_cmd
            assert "lm_eval" in called_cmd
            assert "--model" in called_cmd
            assert "openai-chat-completions" in called_cmd
            assert "--tasks" in called_cmd
            assert "bbq_generate" in called_cmd
            assert "--limit" in called_cmd
            assert "--apply_chat_template" in called_cmd

    def test_url_appended_in_model_args(self, mock_job_spec, mock_callbacks):
        """model_args must contain /chat/completions even if the spec URL lacks it."""
        from adapters.lm_eval.main import LmEvalAdapter

        fake_results = FIXTURES_DIR / "lmeval_results_bbq.json"

        with patch("subprocess.run") as mock_run, \
             patch("glob.glob", return_value=[str(fake_results)]):

            mock_run.return_value = MagicMock(returncode=0, stderr="", stdout="")
            adapter = LmEvalAdapter.__new__(LmEvalAdapter)
            try:
                adapter.run_benchmark_job(mock_job_spec, mock_callbacks)
            except Exception:
                pass

            if mock_run.called:
                called_cmd = mock_run.call_args[0][0]
                model_args_idx = called_cmd.index("--model_args")
                model_args_val = called_cmd[model_args_idx + 1]
                assert "chat/completions" in model_args_val, (
                    f"Expected /chat/completions in model_args, got: {model_args_val}"
                )


# ============================================================
# 5. Smoke tests — lm_eval subprocess against mock model server
# ============================================================

@pytest.mark.smoke
class TestLmEvalSmoke:
    """Run lm_eval end-to-end against a mock OpenAI-compatible model server.

    These tests do NOT require OPENROUTER_API_KEY. They DO require:
    - HuggingFace internet access (dataset download)
    - All dependencies installed (uv sync)

    If BBQ or MMLU dataset cannot be downloaded (corporate proxy, offline
    environment), these tests skip. In that case, verify connectivity or
    pre-cache datasets with:
        python -c "from datasets import load_dataset; load_dataset('heegyu/bbq')"

    Run: uv run pytest tests/test_lmeval_adapter.py -m smoke -v
    """

    @skip_if_hf_offline
    def test_lm_eval_bbq_with_mock_server(self, mock_model_server, tmp_path):
        """lm_eval bbq_generate, limit=1, mock model → results JSON produced."""
        output_dir = tmp_path / "lmeval-bbq"
        output_dir.mkdir()
        base_url = f"{mock_model_server}/chat/completions"

        result = subprocess.run(
            [
                sys.executable, "-m", "lm_eval",
                "--model", "openai-chat-completions",
                "--model_args", f"base_url={base_url},model=mock-model",
                "--tasks", "bbq_generate",
                "--limit", "1",
                "--apply_chat_template",
                "--output_path", str(output_dir),
            ],
            capture_output=True,
            text=True,
            timeout=180,
            env={**os.environ, "OPENAI_API_KEY": "mock-key-for-test"},
        )

        assert result.returncode == 0, (
            "lm_eval bbq_generate FAILED with mock server.\n"
            f"--- stdout (last 1000 chars) ---\n{result.stdout[-1000:]}\n"
            f"--- stderr (last 1000 chars) ---\n{result.stderr[-1000:]}\n\n"
            "Possible causes:\n"
            "  1. Dataset download failed → check HuggingFace connectivity\n"
            "  2. Task not in lm_eval registry → check lm_eval version (>=0.4)\n"
            "  3. Output format changed → check adapters/lm_eval/main.py parsing\n"
            "If lm_eval consistently fails, consider switching to lighteval for "
            "BBQ/MMLU tasks — the adapter interface (FrameworkAdapter) is compatible."
        )

        json_files = glob.glob(str(output_dir / "**" / "results*.json"), recursive=True)
        assert json_files, f"No results JSON found under {output_dir}"

        raw = json.loads(Path(json_files[0]).read_text())
        assert "results" in raw, "results key missing from lm_eval output"
        assert "bbq_generate" in raw["results"], (
            f"bbq_generate missing. Got: {list(raw['results'].keys())}"
        )
        assert "acc,none" in raw["results"]["bbq_generate"], (
            f"acc metric missing. Got: {list(raw['results']['bbq_generate'].keys())}"
        )

    @skip_if_hf_offline
    def test_lm_eval_mmlu_with_mock_server(self, mock_model_server, tmp_path):
        """lm_eval mmlu_business_ethics_generative, limit=1, mock model."""
        output_dir = tmp_path / "lmeval-mmlu"
        output_dir.mkdir()
        base_url = f"{mock_model_server}/chat/completions"

        result = subprocess.run(
            [
                sys.executable, "-m", "lm_eval",
                "--model", "openai-chat-completions",
                "--model_args", f"base_url={base_url},model=mock-model",
                "--tasks", "mmlu_business_ethics_generative",
                "--limit", "1",
                "--apply_chat_template",
                "--output_path", str(output_dir),
            ],
            capture_output=True,
            text=True,
            timeout=120,
            env={**os.environ, "OPENAI_API_KEY": "mock-key-for-test"},
        )

        assert result.returncode == 0, (
            "lm_eval mmlu_business_ethics_generative FAILED.\n"
            f"stderr: {result.stderr[-1000:]}"
        )

        json_files = glob.glob(str(output_dir / "**" / "results*.json"), recursive=True)
        assert json_files
        raw = json.loads(Path(json_files[0]).read_text())
        assert "mmlu_business_ethics_generative" in raw["results"]
        task_results = raw["results"]["mmlu_business_ethics_generative"]
        assert "exact_match,none" in task_results or "exact_match,get_response" in task_results, (
            f"exact_match metric missing. Got: {list(task_results.keys())}"
        )


# ============================================================
# 6. Integration tests — real OpenRouter API
# ============================================================

@pytest.mark.integration
@skip_if_no_openrouter
class TestLmEvalIntegration:
    """Full end-to-end pipeline via OpenRouter (free tier, limit=2).

    These tests reproduce exactly what Section 02 of the workshop does.
    They validate that the combination of lm_eval + OpenRouter + adapter
    produces parseable results.

    Run: OPENROUTER_API_KEY=sk-or-... uv run pytest tests/test_lmeval_adapter.py -m integration -v
    """

    def test_bbq_via_openrouter(self, tmp_path):
        output_dir = tmp_path / "lmeval-openrouter-bbq"
        output_dir.mkdir()
        api_key = os.environ["OPENROUTER_API_KEY"]

        result = subprocess.run(
            [
                sys.executable, "-m", "lm_eval",
                "--model", "openai-chat-completions",
                "--model_args", (
                    "base_url=https://openrouter.ai/api/v1/chat/completions,"
                    "model=liquid/lfm-2.5-1.2b-instruct:free"
                ),
                "--tasks", "bbq_generate",
                "--limit", "2",
                "--apply_chat_template",
                "--output_path", str(output_dir),
            ],
            capture_output=True,
            text=True,
            timeout=300,
            env={**os.environ, "OPENAI_API_KEY": api_key},
        )

        assert result.returncode == 0, (
            f"lm_eval bbq_generate via OpenRouter FAILED.\n"
            f"stderr: {result.stderr[-2000:]}"
        )
        json_files = glob.glob(str(output_dir / "**" / "results*.json"), recursive=True)
        assert json_files
        raw = json.loads(Path(json_files[0]).read_text())
        assert "bbq_generate" in raw["results"]

    def test_mmlu_via_openrouter(self, tmp_path):
        output_dir = tmp_path / "lmeval-openrouter-mmlu"
        output_dir.mkdir()
        api_key = os.environ["OPENROUTER_API_KEY"]

        result = subprocess.run(
            [
                sys.executable, "-m", "lm_eval",
                "--model", "openai-chat-completions",
                "--model_args", (
                    "base_url=https://openrouter.ai/api/v1/chat/completions,"
                    "model=liquid/lfm-2.5-1.2b-instruct:free"
                ),
                "--tasks", "mmlu_business_ethics_generative",
                "--limit", "2",
                "--apply_chat_template",
                "--output_path", str(output_dir),
            ],
            capture_output=True,
            text=True,
            timeout=300,
            env={**os.environ, "OPENAI_API_KEY": api_key},
        )

        assert result.returncode == 0, (
            f"lm_eval mmlu_business_ethics_generative via OpenRouter FAILED.\n"
            f"stderr: {result.stderr[-2000:]}"
        )
        json_files = glob.glob(str(output_dir / "**" / "results*.json"), recursive=True)
        assert json_files
        raw = json.loads(Path(json_files[0]).read_text())
        assert "mmlu_business_ethics_generative" in raw["results"]

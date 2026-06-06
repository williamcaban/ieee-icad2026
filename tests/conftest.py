"""
Shared pytest fixtures for ieee-icad2026 workshop tests.

The repo root is added to sys.path so that `from adapters.lm_eval.main import ...`
works without packaging the repo as a Python package.
"""

import json
import sys
import threading
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path
from unittest.mock import MagicMock

import pytest

REPO_ROOT = Path(__file__).parent.parent
FIXTURES_DIR = Path(__file__).parent / "fixtures"

# Make repo-local modules importable.
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))


# ---------------------------------------------------------------------------
# Mock JobSpec — mirrors the fields accessed by LmEvalAdapter.run_benchmark_job
# ---------------------------------------------------------------------------

@pytest.fixture
def mock_job_spec():
    spec = MagicMock()
    spec.id = "test-job-001"
    spec.benchmark_id = "bbq_generate"
    spec.benchmark_index = 0
    spec.model.url = "http://localhost:19999/v1"
    spec.model.name = "mock-model/test-1b"
    spec.num_examples = 2
    return spec


@pytest.fixture
def mock_job_spec_mmlu(mock_job_spec):
    mock_job_spec.benchmark_id = "mmlu_business_ethics_generative"
    return mock_job_spec


@pytest.fixture
def mock_callbacks():
    callbacks = MagicMock()
    callbacks.report_status = MagicMock(return_value=None)
    callbacks.report_results = MagicMock(return_value=None)
    return callbacks


# ---------------------------------------------------------------------------
# Fixture JSON files produced by lm_eval
# ---------------------------------------------------------------------------

@pytest.fixture
def lmeval_bbq_output():
    return json.loads((FIXTURES_DIR / "lmeval_results_bbq.json").read_text())


@pytest.fixture
def lmeval_mmlu_output():
    return json.loads((FIXTURES_DIR / "lmeval_results_mmlu.json").read_text())


# ---------------------------------------------------------------------------
# Mock OpenAI-compatible model server (session-scoped, started once)
# ---------------------------------------------------------------------------

class _MockModelHandler(BaseHTTPRequestHandler):
    """Minimal OpenAI chat/completions endpoint.

    Returns a single-token reply ("A") for any POST, regardless of the
    prompt content. This lets lm_eval complete its evaluation loop without
    a real LLM or API key.
    """

    _RESPONSE = json.dumps({
        "id": "mock-cmpl-001",
        "object": "chat.completion",
        "model": "mock-model",
        "choices": [{
            "index": 0,
            "message": {"role": "assistant", "content": "A"},
            "finish_reason": "stop",
        }],
        "usage": {"prompt_tokens": 10, "completion_tokens": 1, "total_tokens": 11},
    }).encode()

    def do_POST(self):
        content_length = int(self.headers.get("Content-Length", 0))
        self.rfile.read(content_length)  # drain body
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(self._RESPONSE)))
        self.end_headers()
        self.wfile.write(self._RESPONSE)

    def log_message(self, format, *args):
        pass  # suppress per-request HTTP logs


@pytest.fixture(scope="session")
def mock_model_server():
    """Ephemeral mock model server running for the full test session.

    Returns the base URL as a string: ``http://localhost:<port>/v1``.
    The ``/chat/completions`` path is appended by the adapter's URL logic.
    """
    server = HTTPServer(("localhost", 0), _MockModelHandler)
    port = server.server_address[1]
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    yield f"http://localhost:{port}/v1"
    server.shutdown()

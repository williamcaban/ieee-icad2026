#!/usr/bin/env python3
"""
EvalHub MCP client — the complete implementation is what you see here.

Uses the MCP Streamable HTTP transport (JSON-RPC 2.0 over HTTP with SSE responses).
Protocol:
  1. POST / with initialize → server returns Mcp-Session-Id header + SSE data
  2. All subsequent POSTs include Mcp-Session-Id header
  3. Responses are SSE-formatted: lines starting with "data: " contain JSON-RPC

Three tools are exposed:
  submit_evaluation  — start a new evaluation job
  get_job_status     — check progress and retrieve results when done
  cancel_job         — stop a running job

No async, no MCP SDK, no framework. Just requests + a little SSE parsing.
"""
import json
from typing import Any

import requests


def _parse_sse(text: str) -> Any:
    """Extract the JSON-RPC payload from an SSE response body."""
    for line in text.splitlines():
        if line.startswith("data: "):
            return json.loads(line[6:])
    # Fallback: try parsing the whole body as JSON
    return json.loads(text)


class EvalHubMCPClient:
    """HTTP wrapper around the EvalHub MCP server (Streamable HTTP transport)."""

    def __init__(self, url: str = "http://localhost:3001"):
        self.url = url.rstrip("/")
        self._session_id: str | None = None
        self._id = 0
        self._initialize()

    def _initialize(self) -> None:
        """Perform the MCP handshake and capture the session ID."""
        self._id += 1
        response = requests.post(
            self.url + "/",
            json={
                "jsonrpc": "2.0",
                "id": self._id,
                "method": "initialize",
                "params": {
                    "protocolVersion": "2024-11-05",
                    "capabilities": {},
                    "clientInfo": {"name": "workshop-client", "version": "1.0"},
                },
            },
            headers={"Content-Type": "application/json"},
            timeout=15,
        )
        response.raise_for_status()
        self._session_id = response.headers.get("Mcp-Session-Id")

    def _call(self, method: str, params: dict) -> Any:
        self._id += 1
        headers = {"Content-Type": "application/json"}
        if self._session_id:
            headers["Mcp-Session-Id"] = self._session_id
        response = requests.post(
            self.url + "/",
            json={"jsonrpc": "2.0", "id": self._id, "method": method, "params": params},
            headers=headers,
            timeout=30,
        )
        response.raise_for_status()
        data = _parse_sse(response.text)
        if "error" in data:
            raise RuntimeError(f"MCP error [{data['error'].get('code')}]: {data['error'].get('message')}")
        return data.get("result", data)

    def _tool_call(self, tool_name: str, arguments: dict) -> Any:
        result = self._call("tools/call", {"name": tool_name, "arguments": arguments})
        if isinstance(result, dict):
            if result.get("isError"):
                content = result.get("content", [{}])
                msg = content[0].get("text", "unknown error") if content else "unknown error"
                raise RuntimeError(f"MCP tool error ({tool_name}): {msg}")
            # Prefer structuredContent (machine-readable) over text content
            if "structuredContent" in result:
                return result["structuredContent"]
            content = result.get("content", [])
            if isinstance(content, list) and content:
                text = content[0].get("text", "")
                try:
                    return json.loads(text)
                except (json.JSONDecodeError, TypeError):
                    return text  # plain string result (e.g., a job ID)
        return result

    def list_tools(self) -> list:
        """List available MCP tools (useful for verifying connection)."""
        result = self._call("tools/list", {})
        return result.get("tools", [])

    def submit_evaluation(
        self,
        name: str,
        model_url: str,
        model_name: str,
        benchmark_id: str,
        provider_id: str,
        description: str = "",
        **kwargs,
    ) -> dict:
        """Start a new evaluation job.

        Args:
            name: Job name (unique identifier for this run)
            model_url: OpenAI-compatible model endpoint URL
            model_name: Model name / identifier
            benchmark_id: Benchmark to run (e.g. 'bbq_generate')
            provider_id: Provider that owns the benchmark (e.g. 'lm_evaluation_harness')
            description: Optional human-readable description
        """
        arguments: dict = {
            "name": name,
            "model": {"url": model_url, "name": model_name},
            "benchmarks": [{"id": benchmark_id, "provider_id": provider_id}],
        }
        if description:
            arguments["description"] = description
        return self._tool_call("submit_evaluation", arguments)

    def submit_collection(
        self,
        name: str,
        model_url: str,
        model_name: str,
        collection_id: str,
        description: str = "",
    ) -> dict:
        """Start an evaluation job running an entire collection."""
        arguments: dict = {
            "name": name,
            "model": {"url": model_url, "name": model_name},
            "collection": {"id": collection_id},
        }
        if description:
            arguments["description"] = description
        return self._tool_call("submit_evaluation", arguments)

    def get_job_status(self, job_id: str) -> dict:
        """Check job progress. Returns status, progress, and results when COMPLETED."""
        return self._tool_call("get_job_status", {"job_id": job_id})

    def cancel_job(self, job_id: str) -> dict:
        """Stop a running evaluation job."""
        return self._tool_call("cancel_job", {"job_id": job_id})

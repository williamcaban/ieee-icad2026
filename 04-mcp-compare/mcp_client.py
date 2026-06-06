#!/usr/bin/env python3
"""
EvalHub MCP client — the complete implementation is what you see here.

Calls the EvalHub MCP server (localhost:3001) using JSON-RPC 2.0 over HTTP.
Three tools are exposed:
  submit_evaluation  — start a new evaluation job
  get_job_status     — check progress and retrieve results when done
  cancel_job         — stop a running job

No async, no SDK, no framework. Just requests.
"""
import json
from typing import Any

import requests


class EvalHubMCPClient:
    """Thin HTTP wrapper around the EvalHub MCP server."""

    def __init__(self, url: str = "http://localhost:3001"):
        self.url = url.rstrip("/")
        self._id = 0

    def _call(self, tool_name: str, arguments: dict) -> Any:
        self._id += 1
        response = requests.post(
            self.url,
            json={
                "jsonrpc": "2.0",
                "id": self._id,
                "method": "tools/call",
                "params": {"name": tool_name, "arguments": arguments},
            },
            timeout=30,
        )
        response.raise_for_status()
        data = response.json()
        if "error" in data:
            raise RuntimeError(f"MCP error [{data['error'].get('code')}]: {data['error'].get('message')}")
        return data.get("result", data)

    def submit_evaluation(
        self,
        name: str,
        model_url: str,
        model_name: str,
        benchmark: str,
        provider: str,
        **kwargs,
    ) -> dict:
        """Start a new evaluation job. Returns job metadata including job_id."""
        return self._call("submit_evaluation", {
            "name": name,
            "model_url": model_url,
            "model_name": model_name,
            "benchmark": benchmark,
            "provider": provider,
            **kwargs,
        })

    def get_job_status(self, job_id: str) -> dict:
        """Check job progress. Returns status, progress, and results when COMPLETED."""
        return self._call("get_job_status", {"job_id": job_id})

    def cancel_job(self, job_id: str) -> dict:
        """Stop a running evaluation job."""
        return self._call("cancel_job", {"job_id": job_id})

    def list_tools(self) -> list:
        """List available MCP tools (useful for verifying connection)."""
        self._id += 1
        response = requests.post(
            self.url,
            json={"jsonrpc": "2.0", "id": self._id, "method": "tools/list", "params": {}},
            timeout=10,
        )
        response.raise_for_status()
        data = response.json()
        return data.get("result", {}).get("tools", [])

#!/usr/bin/env bash
# Stop the NeMo Guardrails proxy and clean up output files.
set -euo pipefail

PID_FILE="/tmp/guardrails-proxy.pid"
PORT=18090

if [[ -f "${PID_FILE}" ]]; then
  PID=$(cat "${PID_FILE}")
  kill "${PID}" 2>/dev/null && echo "[OK] Guardrails proxy (PID ${PID}) stopped." || true
  rm -f "${PID_FILE}"
fi
lsof -ti:"${PORT}" 2>/dev/null | xargs kill -9 2>/dev/null || true
rm -f /tmp/guardrails-proxy.log
echo "[OK] Reset complete."

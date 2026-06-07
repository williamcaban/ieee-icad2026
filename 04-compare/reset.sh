#!/usr/bin/env bash
# Stop evalhub-mcp and remove Act 3 output files.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PID_FILE="/tmp/evalhub-mcp.pid"
PORT=3001

if [[ -f "${PID_FILE}" ]]; then
  PID=$(cat "${PID_FILE}")
  kill "${PID}" 2>/dev/null && echo "[OK] evalhub-mcp (PID ${PID}) stopped." || true
  rm -f "${PID_FILE}"
fi
lsof -ti:"${PORT}" 2>/dev/null | xargs kill -9 2>/dev/null || true
rm -f /tmp/evalhub-mcp.log

rm -f "${SCRIPT_DIR}/results/comparison_report.json"
rm -f "${SCRIPT_DIR}/results/comparison_plot.png"
echo "[OK] Reset complete."

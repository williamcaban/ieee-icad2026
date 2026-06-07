#!/usr/bin/env bash
# Remove Act 3 output files.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

rm -f "${SCRIPT_DIR}/results/comparison_report.json"
rm -f "${SCRIPT_DIR}/results/comparison_plot.png"
echo "[OK] Reset complete."

#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Section 03 reset.sh — Remove irr_report.json so the section can be retried.
# Also restores annotations-sample.csv from git if it was modified.
# Idempotent: safe to run multiple times.
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

info() { echo "[INFO]  $*"; }
ok()   { echo "[OK]    $*"; }

echo "============================================================"
echo "  Resetting Section 03 — IRR/IAA Custom Benchmark (Local)"
echo "============================================================"
echo ""

# Remove the IRR report
if [[ -f "${SCRIPT_DIR}/irr_report.json" ]]; then
  rm -f "${SCRIPT_DIR}/irr_report.json"
  ok "Removed irr_report.json"
else
  info "No irr_report.json found — nothing to remove."
fi

# Restore annotations CSV from git if it was modified
if git -C "${SCRIPT_DIR}" diff --quiet "data/annotations-sample.csv" 2>/dev/null; then
  info "annotations-sample.csv unchanged."
else
  git -C "${SCRIPT_DIR}" checkout -- "data/annotations-sample.csv" 2>/dev/null && \
    ok "Restored data/annotations-sample.csv from git." || \
    info "Could not restore from git — manual restore may be needed."
fi

echo ""
echo "============================================================"
echo "  Reset complete. To retry: bash setup.sh"
echo "============================================================"

#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Section 02 reset.sh — Remove local evaluation output so the section
# can be retried from scratch. Idempotent: safe to run multiple times.
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

info() { echo "[INFO]  $*"; }
ok()   { echo "[OK]    $*"; }

echo "============================================================"
echo "  Resetting Section 02 — Local Safety Evaluation"
echo "============================================================"
echo ""

# Remove results directory (lm-eval output and garak reports)
if [[ -d "${SCRIPT_DIR}/results" ]]; then
  rm -rf "${SCRIPT_DIR}/results"
  ok "Removed results/"
else
  info "No results/ directory — nothing to remove."
fi

# Remove generated live garak config (contains credentials)
if [[ -f "${SCRIPT_DIR}/configs/garak-local-live.yaml" ]]; then
  rm -f "${SCRIPT_DIR}/configs/garak-local-live.yaml"
  ok "Removed configs/garak-local-live.yaml"
fi

echo ""
echo "============================================================"
echo "  Reset complete. To retry: bash setup.sh"
echo "============================================================"

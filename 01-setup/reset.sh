#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Section 01 reset.sh — Clear workshop state so setup.sh can be re-run cleanly.
# Idempotent: safe to run multiple times.
# =============================================================================

WORKSHOP_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKSHOP_ENV_FILE="${WORKSHOP_ROOT}/.workshop-env"

info() { echo "[INFO]  $*"; }
ok()   { echo "[OK]    $*"; }

echo "============================================================"
echo "  Resetting Section 01 — Platform Verification"
echo "============================================================"
echo ""

# Remove the workshop env file so setup.sh recreates it
if [[ -f "${WORKSHOP_ENV_FILE}" ]]; then
  rm -f "${WORKSHOP_ENV_FILE}"
  ok "Removed ${WORKSHOP_ENV_FILE}"
else
  info "No ${WORKSHOP_ENV_FILE} found — nothing to remove."
fi

# Unset environment variables (best-effort — affects child processes only)
unset EVALHUB_ENDPOINT MODEL_ENDPOINT EVALHUB_TOKEN OPENROUTER_API_KEY OPENAI_API_KEY 2>/dev/null || true
info "Unsetting environment variables (run 'unset EVALHUB_ENDPOINT MODEL_ENDPOINT' in your own shell)."

echo ""
echo "============================================================"
echo "  Reset complete."
echo ""
echo "  To retry Section 01, run: bash setup.sh"
echo "============================================================"

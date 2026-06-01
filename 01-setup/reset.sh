#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Section 01 reset.sh — Remove section-specific state so the section can be
# retried from scratch. Does NOT remove cluster-side resources (those are
# managed by the facilitator). Idempotent: safe to run multiple times.
# =============================================================================

# Resolve workshop root from this script's location
WORKSHOP_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKSHOP_ENV_FILE="${WORKSHOP_ROOT}/.workshop-env"

info() { echo "[INFO]  $*"; }
ok()   { echo "[OK]    $*"; }
warn() { echo "[WARN]  $*"; }

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

# Unset environment variables in current shell (best effort — only affects
# child processes from this script, not the parent shell)
unset EVALHUB_ENDPOINT MODEL_ENDPOINT KFP_ENDPOINT EVALHUB_TOKEN WORKSHOP_NAMESPACE 2>/dev/null || true
info "Unsetting environment variables (run 'unset EVALHUB_ENDPOINT MODEL_ENDPOINT KFP_ENDPOINT' in your own shell)."

# Clear any cached oc context overrides written by setup.sh
if oc config current-context >/dev/null 2>&1; then
  info "Current oc context: $(oc config current-context)"
  info "To fully reset cluster context, run: oc config unset current-context"
fi

echo ""
echo "============================================================"
echo "  Reset complete."
echo ""
echo "  To retry Section 01, run: bash setup.sh"
echo "============================================================"

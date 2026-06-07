#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Section 01 reset.sh — Clear workshop state so setup.sh can be re-run cleanly.
# Idempotent: safe to run multiple times.
#
# Options:
#   --keep-env    Keep .workshop-env (preserves API keys and model config)
# =============================================================================

WORKSHOP_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKSHOP_ENV_FILE="${WORKSHOP_ROOT}/.workshop-env"
KEEP_ENV=false

for arg in "$@"; do
  [[ "${arg}" == "--keep-env" ]] && KEEP_ENV=true
done

info() { echo "[INFO]  $*"; }
ok()   { echo "[OK]    $*"; }

echo "============================================================"
echo "  Resetting Section 01"
echo "============================================================"
echo ""

# Workshop env file
if [[ "${KEEP_ENV}" == "true" ]]; then
  info "Keeping ${WORKSHOP_ENV_FILE} (--keep-env)"
elif [[ -f "${WORKSHOP_ENV_FILE}" ]]; then
  printf "  Remove .workshop-env (your API keys and model config)? [y/N] "
  read -r ans
  if [[ "${ans,,}" == "y" ]]; then
    rm -f "${WORKSHOP_ENV_FILE}"
    ok "Removed ${WORKSHOP_ENV_FILE}"
  else
    info "Kept ${WORKSHOP_ENV_FILE}"
  fi
else
  info "No ${WORKSHOP_ENV_FILE} found."
fi

# Stop eval-hub-server if running
PID_FILE="/tmp/evalhub-local.pid"
if [[ -f "${PID_FILE}" ]]; then
  PID=$(cat "${PID_FILE}" 2>/dev/null || echo "")
  [[ -n "${PID}" ]] && kill "${PID}" 2>/dev/null || true
  rm -f "${PID_FILE}" /tmp/evalhub-local.log
  ok "eval-hub-server stopped."
fi

# Unset environment variables (best-effort — affects child processes only)
unset EVALHUB_ENDPOINT MODEL_ENDPOINT EVALHUB_TOKEN OPENROUTER_API_KEY OPENAI_API_KEY 2>/dev/null || true
info "Unsetting environment variables (run 'unset EVALHUB_ENDPOINT MODEL_ENDPOINT' in your own shell)."

echo ""
echo "============================================================"
echo "  Reset complete."
echo ""
echo "  To retry: bash setup.sh"
echo "  To keep your API key on reset: bash reset.sh --keep-env"
echo "============================================================"

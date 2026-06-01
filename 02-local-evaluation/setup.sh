#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Section 02 setup.sh — Verify local eval-hub-server is running and env is ready.
# The server was started in Section 01. This script checks it and sets OPENAI_API_KEY.
# Idempotent: safe to run multiple times.
# =============================================================================

WORKSHOP_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKSHOP_ENV_FILE="${WORKSHOP_ROOT}/.workshop-env"
EVALHUB_LOCAL_PORT="${EVALHUB_LOCAL_PORT:-18080}"
EVALHUB_LOCAL_URL="http://localhost:${EVALHUB_LOCAL_PORT}"

info() { echo "[INFO]  $*"; }
ok()   { echo "[OK]    $*"; }
warn() { echo "[WARN]  $*"; }
fail() { echo "[FAIL]  $*" >&2; exit 1; }

# =============================================================================
# Step 1: Source environment
# =============================================================================
info "Sourcing workshop environment..."
[[ -f "${WORKSHOP_ENV_FILE}" ]] || fail "No .workshop-env found. Run Section 01 setup.sh first."
source "${WORKSHOP_ENV_FILE}"
ok "Loaded ${WORKSHOP_ENV_FILE}"

[[ -z "${OPENROUTER_API_KEY:-}" || "${OPENROUTER_API_KEY}" == *"REPLACE"* ]] && \
  fail "OPENROUTER_API_KEY is not set. Edit .workshop-env and add your key."
ok "OPENROUTER_API_KEY is set."

# lm-eval reads OPENAI_API_KEY; alias it (idempotent)
export OPENAI_API_KEY="${OPENROUTER_API_KEY}"
grep -q "^export OPENAI_API_KEY" "${WORKSHOP_ENV_FILE}" || \
  echo "export OPENAI_API_KEY=\"${OPENROUTER_API_KEY}\"" >> "${WORKSHOP_ENV_FILE}"
ok "OPENAI_API_KEY set (alias for lm-eval/garak adapters → OpenRouter)."

MODEL="${MODEL_NAME:-liquid/lfm-2.5-1.2b-instruct:free}"
ok "Model: ${MODEL}"

# =============================================================================
# Step 2: Verify local eval-hub-server is running
# =============================================================================
info "Checking local eval-hub-server at ${EVALHUB_LOCAL_URL}..."

if curl -sf "${EVALHUB_LOCAL_URL}/api/v1/health" >/dev/null 2>&1; then
  ok "Local eval-hub-server is running."
else
  warn "Local server not running — attempting to start it..."
  cd "${WORKSHOP_ROOT}"
  PORT="${EVALHUB_LOCAL_PORT}" \
    eval-hub-server --local --configdir config/ \
    > /tmp/evalhub-local.log 2>&1 &
  echo $! > /tmp/evalhub-local.pid
  sleep 3
  if curl -sf "${EVALHUB_LOCAL_URL}/api/v1/health" >/dev/null 2>&1; then
    ok "Local eval-hub-server started."
  else
    fail "Could not start local server. Run: bash ../01-setup/setup.sh"
  fi
fi

# Confirm providers are registered
PROVIDER_COUNT=$(evalhub providers list --format json 2>/dev/null | \
  python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "0")
if [[ "${PROVIDER_COUNT}" -ge 2 ]]; then
  ok "Providers registered: ${PROVIDER_COUNT}"
else
  info "Registering providers..."
  for f in "${WORKSHOP_ROOT}"/config/providers/*.yaml; do
    evalhub providers create --file "${f}" 2>/dev/null || true
  done
  ok "Providers registered."
fi

# =============================================================================
# Step 3: Verify local tools (still needed for direct CLI fallback)
# =============================================================================
info "Checking local evaluation tools..."
command -v lm_eval >/dev/null 2>&1 && ok "lm_eval available"  || warn "lm_eval not on PATH"
command -v garak   >/dev/null 2>&1 && ok "garak available"    || warn "garak not on PATH"

# =============================================================================
# Done
# =============================================================================
echo ""
echo "============================================================"
echo "  Section 02 setup complete."
echo ""
echo "  Local EvalHub: ${EVALHUB_LOCAL_URL}"
echo "  Model: ${MODEL}"
echo ""
echo "  Try: evalhub providers list"
echo "       evalhub eval run --provider lm_evaluation_harness \\"
echo "         --benchmark bbq_generate --model-url \${MODEL_ENDPOINT}/chat/completions \\"
echo "         --model-name \${MODEL_NAME} --param limit=5 --wait"
echo "============================================================"

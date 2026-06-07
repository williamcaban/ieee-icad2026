#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Section 01 setup.sh — Configure workshop environment and evalhub CLI.
# Idempotent: safe to run multiple times.
# =============================================================================

WORKSHOP_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKSHOP_ENV_FILE="${WORKSHOP_ROOT}/.workshop-env"

info() { echo "[INFO]  $*"; }
ok()   { echo "[OK]    $*"; }
warn() { echo "[WARN]  $*"; }
fail() { echo "[FAIL]  $*" >&2; exit 1; }

# =============================================================================
# Step 1: Verify uv environment tools
# =============================================================================
info "Checking uv environment tools..."
for tool in lm_eval garak evalhub eval-hub-server; do
  if command -v "${tool}" >/dev/null 2>&1; then
    ver="$(${tool} --version 2>/dev/null || echo 'ok')"
    ok "${tool}: ${ver:-ok}"
  else
    fail "${tool} not found. Run: source .venv/bin/activate (from repo root)"
  fi
done

# =============================================================================
# Step 2: Source or create .workshop-env
# =============================================================================
info "Checking workshop environment file..."

if [[ -f "${WORKSHOP_ENV_FILE}" ]]; then
  source "${WORKSHOP_ENV_FILE}"
  ok "Loaded ${WORKSHOP_ENV_FILE}"
else
  if [[ -f "${WORKSHOP_ROOT}/.workshop-env.example" ]]; then
    cp "${WORKSHOP_ROOT}/.workshop-env.example" "${WORKSHOP_ENV_FILE}"
    chmod 600 "${WORKSHOP_ENV_FILE}"
    warn "Created ${WORKSHOP_ENV_FILE} from example."
    warn "REQUIRED: Edit ${WORKSHOP_ENV_FILE} and set OPENROUTER_API_KEY"
    warn "Get a free key at: https://openrouter.ai/keys"
  else
    fail ".workshop-env.example not found in repo root."
  fi
  source "${WORKSHOP_ENV_FILE}"
fi

# Validate model endpoint configuration
if [[ -z "${MODEL_ENDPOINT:-}" ]]; then
  warn "MODEL_ENDPOINT is not set. Edit ${WORKSHOP_ENV_FILE} and choose an endpoint."
  warn "Options: OpenRouter (cloud, free), Ollama (local), or vLLM."
else
  ok "MODEL_ENDPOINT: ${MODEL_ENDPOINT}"
fi
if [[ -z "${MODEL_NAME:-}" ]]; then
  warn "MODEL_NAME is not set. Edit ${WORKSHOP_ENV_FILE}."
else
  ok "MODEL_NAME: ${MODEL_NAME}"
fi
# Ensure OPENAI_API_KEY is set — lm-eval uses this as the auth header regardless of provider
if [[ -z "${OPENAI_API_KEY:-}" ]]; then
  if [[ -n "${OPENROUTER_API_KEY:-}" && "${OPENROUTER_API_KEY}" != *"REPLACE"* ]]; then
    export OPENAI_API_KEY="${OPENROUTER_API_KEY}"
    ok "OPENAI_API_KEY set from OPENROUTER_API_KEY."
  else
    warn "OPENAI_API_KEY not set. lm-eval requires this. Set it in ${WORKSHOP_ENV_FILE}."
    warn "For Ollama, set: export OPENAI_API_KEY=ollama"
  fi
else
  ok "OPENAI_API_KEY is set."
fi

# =============================================================================
# Step 3: Start local eval-hub-server (Sections 01-02, no cluster needed)
# =============================================================================
EVALHUB_LOCAL_PORT=18080
EVALHUB_LOCAL_URL="http://localhost:${EVALHUB_LOCAL_PORT}"
EVALHUB_LOCAL_PID_FILE="/tmp/evalhub-local.pid"

info "Starting local eval-hub-server on port ${EVALHUB_LOCAL_PORT}..."

# Kill any existing instance on this port
if [[ -f "${EVALHUB_LOCAL_PID_FILE}" ]]; then
  OLD_PID=$(cat "${EVALHUB_LOCAL_PID_FILE}" 2>/dev/null || echo "")
  [[ -n "${OLD_PID}" ]] && kill "${OLD_PID}" 2>/dev/null || true
  rm -f "${EVALHUB_LOCAL_PID_FILE}"
fi
lsof -ti:"${EVALHUB_LOCAL_PORT}" 2>/dev/null | xargs kill -9 2>/dev/null || true
sleep 1

# Start the server in the background — export API keys so adapters inherit them
cd "${WORKSHOP_ROOT}"
export OPENAI_API_KEY="${OPENROUTER_API_KEY}"
PORT="${EVALHUB_LOCAL_PORT}" \
  eval-hub-server --local --configdir config/ \
  > /tmp/evalhub-local.log 2>&1 &
EVALHUB_LOCAL_PID=$!
echo "${EVALHUB_LOCAL_PID}" > "${EVALHUB_LOCAL_PID_FILE}"

# Wait for it to be ready
for i in $(seq 1 15); do
  sleep 1
  if curl -sf "${EVALHUB_LOCAL_URL}/api/v1/health" >/dev/null 2>&1; then
    ok "Local eval-hub-server ready at ${EVALHUB_LOCAL_URL} (PID ${EVALHUB_LOCAL_PID})"
    break
  fi
  [[ "${i}" == "15" ]] && { warn "Local server did not start — check /tmp/evalhub-local.log"; }
done

# Configure CLI to point to local server (no auth, no tenant needed)
evalhub config set base_url "${EVALHUB_LOCAL_URL}" 2>/dev/null
evalhub config set token "" 2>/dev/null
evalhub config set tenant "" 2>/dev/null

# Register providers (idempotent — server accepts re-registration)
for provider_yaml in "${WORKSHOP_ROOT}"/config/providers/*.yaml; do
  provider_id=$(python3 -c "import yaml; print(yaml.safe_load(open('${provider_yaml}'))['id'])" 2>/dev/null)
  evalhub providers create --file "${provider_yaml}" 2>/dev/null && \
    ok "Provider registered: ${provider_id}" || \
    info "Provider already registered: ${provider_id}"
done

# Persist local URL in .workshop-env
grep -v "^export EVALHUB_ENDPOINT\|^export EVALHUB_TOKEN" \
  "${WORKSHOP_ENV_FILE}" > /tmp/wenv_tmp && mv /tmp/wenv_tmp "${WORKSHOP_ENV_FILE}"
{
  echo "export EVALHUB_ENDPOINT=\"${EVALHUB_LOCAL_URL}\""
  echo "export EVALHUB_TOKEN=\"\""
  echo "export EVALHUB_LOCAL_PORT=\"${EVALHUB_LOCAL_PORT}\""
} >> "${WORKSHOP_ENV_FILE}"
chmod 600 "${WORKSHOP_ENV_FILE}"

echo ""
echo "  Local EvalHub: ${EVALHUB_LOCAL_URL}"
echo "  Log: /tmp/evalhub-local.log"
echo "  Stop: kill \$(cat /tmp/evalhub-local.pid)"
echo ""

# =============================================================================
# Step 4: Install evalhub-mcp binary (needed for Act 3 — Section 04)
# =============================================================================
info "Checking evalhub-mcp installation..."

if command -v evalhub-mcp >/dev/null 2>&1; then
  ok "evalhub-mcp: $(evalhub-mcp --version 2>/dev/null || echo 'installed')"
else
  info "Installing evalhub-mcp via Homebrew..."
  if command -v brew >/dev/null 2>&1; then
    brew install eval-hub/evalhub/evalhub-mcp 2>/dev/null && \
      ok "evalhub-mcp installed via Homebrew." || \
      warn "Homebrew install failed. Try the GitHub release fallback in 04-mcp-compare/setup.sh"
  else
    warn "Homebrew not found. Run 04-mcp-compare/setup.sh for a GitHub release install."
  fi
fi

# =============================================================================
# Step 5: Configure evalhub CLI for cluster (optional — closing demo only)
# =============================================================================
# Cluster access is NOT required for any hands-on section of this workshop.
# The Kubernetes demo in the closing segment uses a pre-recorded video.
# If you have cluster access and want to test it, log in with: oc login <api>
# The 04-mcp-compare/lab.md has the cluster switch instructions.

if command -v oc >/dev/null 2>&1 && oc whoami >/dev/null 2>&1; then
  info "Cluster access detected (optional — not needed for the workshop lab)."
  # Cluster config lives in setup/platform-setup.sh — not run here
else
  info "No cluster access — all workshop sections run locally. That's expected."
fi

# =============================================================================
# Done
# =============================================================================
echo ""
echo "============================================================"
echo "  Section 01 setup complete."
echo ""
echo "  Local EvalHub: http://localhost:${EVALHUB_LOCAL_PORT}"
echo "  Providers:     lm_evaluation_harness, garak"
echo "  Model:         ${MODEL_NAME:-<not set>} @ ${MODEL_ENDPOINT:-<not set>}"
echo ""
echo "  Next: source .workshop-env && cd ../02-local-evaluation"
echo "============================================================"

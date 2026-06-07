#!/usr/bin/env bash
# =============================================================================
# 04-mcp-compare/setup.sh — Start the EvalHub MCP server for Act 3
#
# Installs evalhub-mcp if needed, writes a local config pointing at
# eval-hub-server (localhost:18080), and starts the MCP server on port 3001.
#
# Exposes: http://localhost:3001  (JSON-RPC 2.0 over HTTP)
# Stop:    bash 04-mcp-compare/reset.sh
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSHOP_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
PORT=3001
MCP_CONFIG="${HOME}/.evalhub/mcp-local.yaml"
PID_FILE="/tmp/evalhub-mcp.pid"
LOG_FILE="/tmp/evalhub-mcp.log"
EVALHUB_PORT=18080

info() { echo "[INFO]  $*"; }
ok()   { echo "[OK]    $*"; }
warn() { echo "[WARN]  $*"; }
fail() { echo "[FAIL]  $*" >&2; exit 1; }

source "${WORKSHOP_ROOT}/.workshop-env" 2>/dev/null || true
EVALHUB_PORT="${EVALHUB_LOCAL_PORT:-${EVALHUB_PORT}}"

# =============================================================================
# Step 1: Verify eval-hub-server is running
# =============================================================================
info "Checking eval-hub-server on port ${EVALHUB_PORT}..."
if ! curl -sf "http://localhost:${EVALHUB_PORT}/api/v1/health" >/dev/null 2>&1; then
  warn "eval-hub-server not running — starting it first..."
  bash "${WORKSHOP_ROOT}/01-setup/setup.sh"
fi
ok "eval-hub-server: http://localhost:${EVALHUB_PORT}"

# =============================================================================
# Step 2: Install evalhub-mcp if missing
# =============================================================================
_install_evalhub_mcp_from_github() {
  local ARCH OS BINARY URL
  ARCH="$(uname -m)"
  OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
  [[ "${ARCH}" == "arm64" ]] && ARCH="arm64" || ARCH="amd64"
  BINARY="evalhub-mcp-${OS}-${ARCH}"
  URL="https://github.com/eval-hub/eval-hub/releases/latest/download/${BINARY}"
  info "Downloading ${BINARY} from GitHub releases..."
  curl -fsSL --max-time 30 "${URL}" -o /usr/local/bin/evalhub-mcp && \
    chmod +x /usr/local/bin/evalhub-mcp && \
    ok "evalhub-mcp installed from GitHub release." || \
    warn "GitHub release download failed. Check network or install manually."
}

info "Checking evalhub-mcp..."
if ! command -v evalhub-mcp >/dev/null 2>&1; then
  info "evalhub-mcp not found — installing..."
  if command -v brew >/dev/null 2>&1; then
    brew install eval-hub/evalhub/evalhub-mcp 2>/dev/null && \
      ok "evalhub-mcp installed via Homebrew." || {
      warn "Homebrew install failed — trying GitHub release..."
      _install_evalhub_mcp_from_github
    }
  else
    _install_evalhub_mcp_from_github
  fi
fi

ok "evalhub-mcp: $(evalhub-mcp --version 2>/dev/null || echo 'installed')"

# =============================================================================
# Step 3: Write local MCP config (points at local eval-hub-server)
# =============================================================================
mkdir -p "$(dirname "${MCP_CONFIG}")"
cat > "${MCP_CONFIG}" <<EOF
base_url: "http://localhost:${EVALHUB_PORT}"
token: ""
tenant: "workshop"
transport: "http"
host: "localhost"
port: ${PORT}
EOF
ok "Config written: ${MCP_CONFIG}"

# =============================================================================
# Step 4: Stop any existing instance
# =============================================================================
if [[ -f "${PID_FILE}" ]]; then
  OLD_PID=$(cat "${PID_FILE}" 2>/dev/null || echo "")
  [[ -n "${OLD_PID}" ]] && kill "${OLD_PID}" 2>/dev/null || true
  rm -f "${PID_FILE}"
fi
lsof -ti:"${PORT}" 2>/dev/null | xargs kill -9 2>/dev/null || true
sleep 1

# =============================================================================
# Step 5: Start evalhub-mcp
# =============================================================================
info "Starting evalhub-mcp on localhost:${PORT}..."
evalhub-mcp --config "${MCP_CONFIG}" > "${LOG_FILE}" 2>&1 &
MCP_PID=$!
echo "${MCP_PID}" > "${PID_FILE}"

for i in $(seq 1 15); do
  sleep 1
  if curl -sf "http://localhost:${PORT}/health" >/dev/null 2>&1 || \
     curl -sf "http://localhost:${PORT}/"        >/dev/null 2>&1; then
    ok "evalhub-mcp ready at http://localhost:${PORT} (PID ${MCP_PID})"
    break
  fi
  [[ "${i}" == "15" ]] && warn "MCP server did not respond — check ${LOG_FILE}"
done

echo ""
echo "  MCP endpoint:    http://localhost:${PORT}"
echo "  EvalHub backend: http://localhost:${EVALHUB_PORT}"
echo "  Log:             ${LOG_FILE}"
echo "  Stop:            bash 04-mcp-compare/reset.sh"
echo ""
echo "  Run the comparison:"
echo "    cd 04-mcp-compare"
echo "    python3 compare_approaches.py"
echo "    # or open compare_approaches.ipynb in JupyterLab"
echo ""

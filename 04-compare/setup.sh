#!/usr/bin/env bash
# =============================================================================
# 04-mcp-compare/setup.sh — Verify prerequisites for Act 3
#
# Checks that eval-hub-server is running and that both collections used
# in the comparison are registered. No additional servers needed.
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSHOP_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
EVALHUB_PORT=18080

info() { echo "[INFO]  $*"; }
ok()   { echo "[OK]    $*"; }
warn() { echo "[WARN]  $*"; }
fail() { echo "[FAIL]  $*" >&2; exit 1; }

source "${WORKSHOP_ROOT}/.workshop-env" 2>/dev/null || true
EVALHUB_PORT="${EVALHUB_LOCAL_PORT:-${EVALHUB_PORT}}"
EVALHUB="http://localhost:${EVALHUB_PORT}"

# ── Step 1: eval-hub-server ──────────────────────────────────────────────────
info "Checking eval-hub-server on port ${EVALHUB_PORT}..."
if ! curl -sf "${EVALHUB}/api/v1/health" >/dev/null 2>&1; then
  warn "eval-hub-server not running — starting it..."
  bash "${WORKSHOP_ROOT}/01-setup/setup.sh"
fi
ok "eval-hub-server: ${EVALHUB}"

# ── Step 2: IRR collection registered (from Act 2) ──────────────────────────
info "Checking that the novel collection from Act 2 is registered..."
if curl -sf "${EVALHUB}/api/v1/evaluations/collections" 2>/dev/null | \
   python3 -c "import sys,json; d=json.load(sys.stdin); items=d if isinstance(d,list) else d.get('items',[]); ids=[c.get('id') or c.get('name','') for c in items]; assert 'workshop-irr-safety-v1' in ids" 2>/dev/null; then
  ok "Collection 'workshop-irr-safety-v1' registered."
else
  warn "Collection not found — registering now..."
  source "${WORKSHOP_ROOT}/.workshop-env" 2>/dev/null || true
  cd "${WORKSHOP_ROOT}/03-irr-local"
  python3 scripts/compute_irr.py 2>/dev/null || true
  python3 scripts/register_benchmark.py
  ok "Collection registered."
fi

# ── Summary ──────────────────────────────────────────────────────────────────
echo ""
echo "  EvalHub: ${EVALHUB}"
echo ""
echo "  Ready for Act 3:"
echo "    cd 04-mcp-compare"
echo "    python3 compare_approaches.py"
echo "    # or: jupyter lab compare_approaches.ipynb"
echo ""

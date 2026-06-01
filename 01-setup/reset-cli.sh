#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Section 02 reset.sh — Remove CLI configuration so setup.sh can be retried.
# Does NOT remove the package (installed by uv sync at the repo root).
# Idempotent: safe to run multiple times.
# =============================================================================

EVALHUB_CONFIG_DIR="${HOME}/.evalhub"
# Resolve workshop root from this script's location
WORKSHOP_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

info() { echo "[INFO]  $*"; }
ok()   { echo "[OK]    $*"; }

echo "============================================================"
echo "  Resetting Section 02 — EvalHub CLI Setup"
echo "============================================================"
echo ""

# Clear CLI configuration via evalhub config commands (best-effort)
if command -v evalhub >/dev/null 2>&1; then
  evalhub config set base_url "" 2>/dev/null && ok "Cleared base_url from CLI config." || true
  evalhub config set token "" 2>/dev/null && ok "Cleared token from CLI config." || true
fi

# Remove the config directory entirely for a clean slate
if [[ -d "${EVALHUB_CONFIG_DIR}" ]]; then
  rm -rf "${EVALHUB_CONFIG_DIR}"
  ok "Removed ${EVALHUB_CONFIG_DIR}"
else
  info "No ${EVALHUB_CONFIG_DIR} found — nothing to remove."
fi

echo ""
echo "============================================================"
echo "  Reset complete."
echo ""
echo "  To retry Section 02, run: bash setup.sh"
echo "  Note: evalhub is installed via uv sync — no reinstall needed."
echo "============================================================"

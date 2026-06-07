#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Section 03 setup.sh — Verify local IRR tools. No cluster access required.
# All dependencies installed by uv sync at the repo root.
# Idempotent: safe to run multiple times.
# =============================================================================

WORKSHOP_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKSHOP_ENV_FILE="${WORKSHOP_ROOT}/.workshop-env"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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

# =============================================================================
# Step 2: Verify Python dependencies (installed by uv sync)
# =============================================================================
info "Checking IRR Python dependencies..."
python3 -c "import krippendorff" 2>/dev/null || fail "krippendorff not found. Run: source .venv/bin/activate"
python3 -c "import sklearn" 2>/dev/null    || fail "scikit-learn not found. Run: source .venv/bin/activate"
python3 -c "import numpy" 2>/dev/null      || fail "numpy not found. Run: source .venv/bin/activate"
ok "All IRR dependencies available."

# =============================================================================
# Step 3: Verify scripts
# =============================================================================
info "Checking scripts..."
python3 "${SCRIPT_DIR}/scripts/compute_irr.py" --help >/dev/null 2>&1 && \
  ok "compute_irr.py ready." || warn "compute_irr.py has import issues — check above."

python3 "${SCRIPT_DIR}/scripts/register_benchmark.py" --help >/dev/null 2>&1 && \
  ok "register_benchmark.py ready." || warn "register_benchmark.py has import issues."

# =============================================================================
# Done
# =============================================================================
echo ""
echo "============================================================"
echo "  Section 03 setup complete. No cluster access required."
echo ""
echo "  Next steps (all local):"
echo "  1. cat data/annotations-sample.csv"
echo "  2. python3 scripts/compute_irr.py"
echo "  3. python3 scripts/register_benchmark.py"
echo "============================================================"

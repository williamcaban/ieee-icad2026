#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Section 04 reset.sh — Remove cluster resources created in this section.
# Idempotent: safe to run multiple times.
# =============================================================================

WORKSHOP_NAMESPACE="workshop-eval"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

info() { echo "[INFO]  $*"; }
ok()   { echo "[OK]    $*"; }

echo "============================================================"
echo "  Resetting Section 04 — Kubernetes: EvalHub & Governance"
echo "============================================================"
echo ""

# Delete LMEvalJob CRs
for job in icad2026-cluster-eval safety-eval-section03; do
  if oc get lmevaljob "${job}" -n "${WORKSHOP_NAMESPACE}" >/dev/null 2>&1; then
    oc delete lmevaljob "${job}" -n "${WORKSHOP_NAMESPACE}" --wait=false
    ok "Deleted LMEvalJob '${job}'."
  else
    info "LMEvalJob '${job}' not found."
  fi
done

# Remove generated live manifest
[[ -f "${SCRIPT_DIR}/configs/eval-run-live.yaml" ]] && \
  rm -f "${SCRIPT_DIR}/configs/eval-run-live.yaml" && ok "Removed eval-run-live.yaml"

# Delete custom collection via evalhub CLI
if command -v evalhub >/dev/null 2>&1; then
  evalhub collections delete workshop-custom-safety-v1 --yes 2>/dev/null && \
    ok "Deleted collection 'workshop-custom-safety-v1'." || true
  evalhub benchmarks delete icad2026-irr-safety-v1 --yes 2>/dev/null && \
    ok "Deleted benchmark 'icad2026-irr-safety-v1'." || true
fi

# Remove governance export directory
if ls "${SCRIPT_DIR}"/governance-export-* >/dev/null 2>&1; then
  rm -rf "${SCRIPT_DIR}"/governance-export-*
  ok "Removed governance-export-* directories."
fi

echo ""
echo "============================================================"
echo "  Reset complete. To retry: bash setup.sh"
echo "============================================================"

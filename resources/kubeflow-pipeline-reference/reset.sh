#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Section 06 reset.sh — Remove uploaded pipeline and runs from KubeFlow.
# Also removes the compiled pipeline.yaml.
# Idempotent: safe to run multiple times.
# =============================================================================

PIPELINE_NAME="safety-ab-router"
EXPERIMENT_NAME="workshop-icad2026"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

info() { echo "[INFO]  $*"; }
ok()   { echo "[OK]    $*"; }
warn() { echo "[WARN]  $*"; }

echo "============================================================"
echo "  Resetting Section 06 — KubeFlow Pipeline A/B Routing"
echo "============================================================"
echo ""

# Source env to get KFP_ENDPOINT
# Resolve workshop root from this script's location
WORKSHOP_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKSHOP_ENV_FILE="${WORKSHOP_ROOT}/.workshop-env"
if [[ -f "${WORKSHOP_ENV_FILE}" ]]; then
  source "${WORKSHOP_ENV_FILE}"
fi

# Delete pipeline runs via kfp CLI
if command -v kfp >/dev/null 2>&1 && [[ -n "${KFP_ENDPOINT:-}" ]]; then
  info "Deleting pipeline runs in experiment '${EXPERIMENT_NAME}'..."

  # List runs and delete each one
  RUN_IDS=$(kfp run list \
    --experiment-name "${EXPERIMENT_NAME}" \
    --output json 2>/dev/null | \
    python3 -c "import sys,json; runs=json.load(sys.stdin).get('runs',[]); [print(r['run_id']) for r in runs]" \
    2>/dev/null || echo "")

  if [[ -n "${RUN_IDS}" ]]; then
    while IFS= read -r run_id; do
      kfp run delete "${run_id}" --yes 2>/dev/null && ok "Deleted run: ${run_id}" || warn "Could not delete run: ${run_id}"
    done <<< "${RUN_IDS}"
  else
    info "No runs found in experiment '${EXPERIMENT_NAME}'."
  fi

  # Delete the uploaded pipeline
  if kfp pipeline list --output json 2>/dev/null | python3 -c "
import sys, json
pipelines = json.load(sys.stdin).get('pipelines', [])
names = [p['name'] for p in pipelines]
exit(0 if '${PIPELINE_NAME}' in names else 1)
" 2>/dev/null; then
    kfp pipeline delete-version "${PIPELINE_NAME}" --yes 2>/dev/null && ok "Deleted pipeline: ${PIPELINE_NAME}" || warn "Could not delete pipeline via kfp CLI."
  else
    info "Pipeline '${PIPELINE_NAME}' not found in KFP — nothing to delete."
  fi
else
  info "kfp CLI not available or KFP_ENDPOINT not set — skipping KFP cleanup."
fi

# Remove compiled pipeline YAML
if [[ -f "${SCRIPT_DIR}/pipeline.yaml" ]]; then
  rm -f "${SCRIPT_DIR}/pipeline.yaml"
  ok "Removed pipeline.yaml"
else
  info "No pipeline.yaml found — nothing to remove."
fi

echo ""
echo "============================================================"
echo "  Reset complete."
echo ""
echo "  To retry Section 06, run: bash setup.sh"
echo "============================================================"

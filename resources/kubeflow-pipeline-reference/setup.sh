#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Section 06 setup.sh — Install KFP SDK and verify KubeFlow endpoint.
# Self-contained: works without prior sections.
# Idempotent: safe to run multiple times.
# =============================================================================

# Resolve workshop root from this script's location
WORKSHOP_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKSHOP_ENV_FILE="${WORKSHOP_ROOT}/.workshop-env"
WORKSHOP_NAMESPACE="workshop-eval"

info() { echo "[INFO]  $*"; }
ok()   { echo "[OK]    $*"; }
warn() { echo "[WARN]  $*"; }
fail() { echo "[FAIL]  $*" >&2; exit 1; }

# =============================================================================
# Step 1: Source environment
# =============================================================================
info "Sourcing workshop environment..."

if [[ -f "${WORKSHOP_ENV_FILE}" ]]; then
  source "${WORKSHOP_ENV_FILE}"
  ok "Loaded ${WORKSHOP_ENV_FILE}"
else
  warn "No .workshop-env (in workshop root) found. Attempting cluster auto-detection..."
  if ! oc whoami >/dev/null 2>&1; then
    fail "Not logged in to OpenShift and no .workshop-env (in workshop root)."
  fi
  KFP_ROUTE=$(oc get route ds-pipeline-ui -n "${WORKSHOP_NAMESPACE}" -o jsonpath='{.spec.host}' 2>/dev/null || \
              oc get route ds-pipeline-ui -n redhat-ods-applications -o jsonpath='{.spec.host}' 2>/dev/null || echo "")
  EVALHUB_ROUTE=$(oc get route evalhub-api -n "${WORKSHOP_NAMESPACE}" -o jsonpath='{.spec.host}' 2>/dev/null || echo "")
  MODEL_URL=$(oc get inferenceservice granite-3-2b -n "${WORKSHOP_NAMESPACE}" -o jsonpath='{.status.url}' 2>/dev/null || echo "")
  EVALHUB_TOKEN=$(oc create token workshop-sa -n "${WORKSHOP_NAMESPACE}" --duration=8h 2>/dev/null || echo "")
  export KFP_ENDPOINT="https://${KFP_ROUTE}"
  export EVALHUB_ENDPOINT="https://${EVALHUB_ROUTE}"
  export MODEL_ENDPOINT="${MODEL_URL}"
fi

[[ -z "${KFP_ENDPOINT:-}" ]] && fail "KFP_ENDPOINT is not set."
ok "KFP_ENDPOINT: ${KFP_ENDPOINT:0:70}..."
ok "EVALHUB_ENDPOINT: ${EVALHUB_ENDPOINT:0:70}..."

# =============================================================================
# Step 2: Install KFP SDK
# =============================================================================
info "Installing KFP SDK..."

if python3 -m pip show kfp >/dev/null 2>&1; then
  KFP_VER=$(python3 -m pip show kfp | awk '/^Version:/{print $2}')
  ok "kfp ${KFP_VER} is already installed."
else
  python3 -m pip install --quiet "kfp>=2.0,<3.0"
  KFP_VER=$(python3 -m pip show kfp | awk '/^Version:/{print $2}')
  ok "kfp ${KFP_VER} installed."
fi

# =============================================================================
# Step 3: Verify KFP endpoint is reachable
# =============================================================================
info "Checking KubeFlow Pipelines API..."

KFP_API="${KFP_ENDPOINT/ds-pipeline-ui/ds-pipeline}"   # derive API URL from UI URL
if curl -sf --max-time 5 "${KFP_API}/apis/v2beta1/pipelines" -o /dev/null 2>/dev/null; then
  ok "KubeFlow Pipelines API is reachable."
else
  warn "KubeFlow Pipelines API did not respond at ${KFP_API}."
  warn "You can still compile the pipeline and examine pipeline.yaml."
  warn "Skip the upload/trigger steps if KFP is unreachable."
fi

# =============================================================================
# Done
# =============================================================================
echo ""
echo "============================================================"
echo "  Section 06 setup complete."
echo ""
echo "  Next: python3 pipeline.py     (compile pipeline.yaml)"
echo "  Then: follow the steps in lab.md"
echo "============================================================"

#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# verify-environment.sh — Pre-workshop environment health check
# Run this 30 minutes before the workshop to confirm everything is ready.
# =============================================================================

WORKSHOP_NAMESPACE="workshop-eval"
# Resolve workshop root from this script's location
WORKSHOP_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKSHOP_ENV_FILE="${WORKSHOP_ROOT}/.workshop-env"
PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0

pass() { echo "[PASS]  $*"; PASS_COUNT=$((PASS_COUNT + 1)); }
fail() { echo "[FAIL]  $*"; FAIL_COUNT=$((FAIL_COUNT + 1)); }
warn() { echo "[WARN]  $*"; WARN_COUNT=$((WARN_COUNT + 1)); }
info() { echo "[INFO]  $*"; }

echo "============================================================"
echo "  IEEE ICAD 2026 Workshop — Environment Verification"
echo "  $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "============================================================"
echo ""

# =============================================================================
# Check 1: Required CLI tools
# =============================================================================
info "Checking required CLI tools..."

for tool in oc kubectl python3 pip3 envsubst jq curl; do
  if command -v "${tool}" >/dev/null 2>&1; then
    pass "${tool} is installed: $(${tool} --version 2>&1 | head -1)"
  else
    fail "${tool} is NOT installed."
  fi
done

# Python version check
PYTHON_VER=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
PYTHON_MAJ=$(echo "${PYTHON_VER}" | cut -d. -f1)
PYTHON_MIN=$(echo "${PYTHON_VER}" | cut -d. -f2)
if [[ ${PYTHON_MAJ} -ge 3 && ${PYTHON_MIN} -ge 12 ]]; then
  pass "Python version ${PYTHON_VER} meets requirement (3.12+)"
else
  fail "Python version ${PYTHON_VER} is below required 3.12. Upgrade Python."
fi

echo ""

# =============================================================================
# Check 2: Workshop environment file
# =============================================================================
info "Checking workshop environment file..."

if [[ -f "${WORKSHOP_ENV_FILE}" ]]; then
  pass "Workshop env file exists: ${WORKSHOP_ENV_FILE}"
  source "${WORKSHOP_ENV_FILE}"

  for var in WORKSHOP_NAMESPACE EVALHUB_ENDPOINT MODEL_ENDPOINT EVALHUB_TOKEN; do
    val="${!var:-}"
    if [[ -n "${val}" && "${val}" != *"PLACEHOLDER"* ]]; then
      pass "${var} is set: ${val:0:60}..."
    elif [[ "${val}" == *"PLACEHOLDER"* ]]; then
      fail "${var} contains placeholder value '${val}'. Update ${WORKSHOP_ENV_FILE}."
    else
      fail "${var} is not set in ${WORKSHOP_ENV_FILE}."
    fi
  done
else
  fail "Workshop env file not found at ${WORKSHOP_ENV_FILE}. Run setup/platform-setup.sh first."
fi

echo ""

# =============================================================================
# Check 3: Cluster connectivity
# =============================================================================
info "Checking cluster connectivity..."

if oc whoami >/dev/null 2>&1; then
  CLUSTER_USER=$(oc whoami)
  CLUSTER_API=$(oc whoami --show-server)
  pass "Cluster connection: logged in as '${CLUSTER_USER}' to ${CLUSTER_API}"
else
  fail "Not logged in to OpenShift cluster. Run: oc login <cluster-api>"
fi

echo ""

# =============================================================================
# Check 4: Workshop namespace
# =============================================================================
info "Checking workshop namespace..."

if oc get namespace "${WORKSHOP_NAMESPACE}" >/dev/null 2>&1; then
  pass "Namespace '${WORKSHOP_NAMESPACE}' exists."
else
  fail "Namespace '${WORKSHOP_NAMESPACE}' does not exist. Run setup/platform-setup.sh."
fi

echo ""

# =============================================================================
# Check 5: EvalHub CR status
# =============================================================================
info "Checking EvalHub CR status..."

if oc get evalhub workshop-eval -n "${WORKSHOP_NAMESPACE}" >/dev/null 2>&1; then
  EVALHUB_READY=$(oc get evalhub workshop-eval -n "${WORKSHOP_NAMESPACE}" -o jsonpath='{.status.ready}' 2>/dev/null || echo "false")
  EVALHUB_VERSION=$(oc get evalhub workshop-eval -n "${WORKSHOP_NAMESPACE}" -o jsonpath='{.spec.version}' 2>/dev/null || echo "unknown")
  if [[ "${EVALHUB_READY}" == "true" ]]; then
    pass "EvalHub CR 'workshop-eval' is Ready (version ${EVALHUB_VERSION})."
  else
    fail "EvalHub CR 'workshop-eval' is NOT ready (status.ready=${EVALHUB_READY}). Check: oc describe evalhub workshop-eval -n ${WORKSHOP_NAMESPACE}"
  fi
else
  fail "EvalHub CR 'workshop-eval' not found in namespace '${WORKSHOP_NAMESPACE}'. Run setup/platform-setup.sh."
fi

# Check EvalHub pods
EVALHUB_PODS=$(oc get pods -n "${WORKSHOP_NAMESPACE}" -l app.kubernetes.io/part-of=evalhub --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l | tr -d ' ')
if [[ "${EVALHUB_PODS}" -ge 1 ]]; then
  pass "EvalHub pods running: ${EVALHUB_PODS} pod(s)."
else
  fail "No running EvalHub pods found. Check: oc get pods -n ${WORKSHOP_NAMESPACE} -l app.kubernetes.io/part-of=evalhub"
fi

echo ""

# =============================================================================
# Check 6: EvalHub API endpoint
# =============================================================================
info "Checking EvalHub API endpoint..."

if [[ -n "${EVALHUB_ENDPOINT:-}" ]]; then
  HTTP_CODE=$(curl -sf -o /dev/null -w "%{http_code}" \
    -H "Authorization: Bearer ${EVALHUB_TOKEN:-}" \
    "${EVALHUB_ENDPOINT}/api/v1/collections" 2>/dev/null || echo "000")
  if [[ "${HTTP_CODE}" == "200" ]]; then
    pass "EvalHub API responding (HTTP ${HTTP_CODE}): ${EVALHUB_ENDPOINT}"
  elif [[ "${HTTP_CODE}" == "401" ]]; then
    fail "EvalHub API returned 401 Unauthorized. Check EVALHUB_TOKEN in ${WORKSHOP_ENV_FILE}."
  else
    fail "EvalHub API returned HTTP ${HTTP_CODE}. Endpoint: ${EVALHUB_ENDPOINT}"
  fi
else
  fail "EVALHUB_ENDPOINT not set. Source ${WORKSHOP_ENV_FILE} first."
fi

echo ""

# =============================================================================
# Check 7: Model serving endpoint
# =============================================================================
info "Checking model serving endpoint..."

if [[ -n "${MODEL_ENDPOINT:-}" ]]; then
  HTTP_CODE=$(curl -sf -o /dev/null -w "%{http_code}" \
    "${MODEL_ENDPOINT}/v1/health" 2>/dev/null || echo "000")
  if [[ "${HTTP_CODE}" == "200" ]]; then
    pass "Model endpoint responding (HTTP ${HTTP_CODE}): ${MODEL_ENDPOINT}"
  else
    fail "Model endpoint returned HTTP ${HTTP_CODE}. Endpoint: ${MODEL_ENDPOINT}/v1/health"
  fi

  # Quick inference test
  INFERENCE_CODE=$(curl -sf -o /dev/null -w "%{http_code}" \
    -X POST "${MODEL_ENDPOINT}/v1/completions" \
    -H "Content-Type: application/json" \
    -d '{"model":"granite-3-2b","prompt":"Hello","max_tokens":5}' 2>/dev/null || echo "000")
  if [[ "${INFERENCE_CODE}" == "200" ]]; then
    pass "Model inference test: PASS (HTTP 200)."
  else
    warn "Model inference test returned HTTP ${INFERENCE_CODE}. Model may still be loading."
  fi
else
  fail "MODEL_ENDPOINT not set. Source ${WORKSHOP_ENV_FILE} first."
fi

echo ""

# =============================================================================
# Check 8: Built-in collections available
# =============================================================================
info "Checking built-in EvalHub collections..."

if command -v evalhub >/dev/null 2>&1; then
  COLLECTIONS=$(evalhub collection list -o json 2>/dev/null | jq -r '.[].name' 2>/dev/null || echo "")
  if echo "${COLLECTIONS}" | grep -q "safety-and-fairness-v1"; then
    pass "Built-in collection 'safety-and-fairness-v1' is available."
  else
    warn "Collection 'safety-and-fairness-v1' not found. The evalhub CLI may not be configured yet (expected — participants install it in Section 02)."
  fi
else
  warn "evalhub CLI not installed. Participants install it in Section 02 — this is expected pre-workshop."
fi

echo ""

# =============================================================================
# Summary
# =============================================================================
echo "============================================================"
echo "  Verification Summary"
echo "  PASS: ${PASS_COUNT}  |  WARN: ${WARN_COUNT}  |  FAIL: ${FAIL_COUNT}"
echo "============================================================"

if [[ ${FAIL_COUNT} -eq 0 ]]; then
  echo "  All critical checks passed. Workshop environment is ready."
  exit 0
else
  echo "  ${FAIL_COUNT} check(s) failed. Resolve failures before the workshop."
  echo "  See FACILITATOR_GUIDE.md for troubleshooting guidance."
  exit 1
fi

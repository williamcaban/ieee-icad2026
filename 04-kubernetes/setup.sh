#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Section 04 setup.sh — Verify cluster access and prepare all cluster resources.
# Requires: Section 01 complete (cluster credentials in .workshop-env)
#           Section 03 complete (irr_report.json exists)
# Idempotent: safe to run multiple times.
# =============================================================================

WORKSHOP_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKSHOP_ENV_FILE="${WORKSHOP_ROOT}/.workshop-env"
WORKSHOP_NAMESPACE="workshop-eval"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EVALRUN_TEMPLATE="${SCRIPT_DIR}/configs/eval-run.yaml"
EVALRUN_LIVE="${SCRIPT_DIR}/configs/eval-run-live.yaml"
IRR_REPORT="${WORKSHOP_ROOT}/03-irr-local/irr_report.json"

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
  fail "OPENROUTER_API_KEY not set. Edit .workshop-env."

# =============================================================================
# Step 2: Verify IRR report from Section 03
# =============================================================================
info "Checking Section 03 output..."
if [[ -f "${IRR_REPORT}" ]]; then
  ALPHA=$(python3 -c "import json; d=json.load(open('${IRR_REPORT}')); print(d['krippendorff_alpha']['value'])" 2>/dev/null)
  ok "irr_report.json found — Alpha = ${ALPHA}"
else
  warn "irr_report.json not found at ${IRR_REPORT}"
  warn "Run Section 03 first: cd ../03-irr-local && python3 scripts/compute_irr.py"
  warn "Continuing setup — register_benchmark.py step in lab.md will fail without it."
fi

# =============================================================================
# Step 3: Verify cluster access
# =============================================================================
info "Checking cluster access..."
oc whoami >/dev/null 2>&1 || fail "Not logged in to OpenShift. Run: oc login <cluster-api>"
oc project "${WORKSHOP_NAMESPACE}" >/dev/null 2>&1 || fail "Cannot access namespace ${WORKSHOP_NAMESPACE}"
ok "Cluster: $(oc whoami --show-server 2>/dev/null)"
ok "Namespace: ${WORKSHOP_NAMESPACE}"

# =============================================================================
# Step 4: Ensure OpenRouter credentials secret exists in cluster
# =============================================================================
info "Creating/updating openrouter-credentials secret..."
oc create secret generic openrouter-credentials \
  -n "${WORKSHOP_NAMESPACE}" \
  --from-literal=OPENROUTER_API_KEY="${OPENROUTER_API_KEY}" \
  --dry-run=client -o yaml | oc apply -f - >/dev/null
ok "Secret 'openrouter-credentials' ready."

# =============================================================================
# Step 5: Verify EvalHub, apply RBAC, configure CLI
# =============================================================================
info "Checking EvalHub..."
EVALHUB_ROUTE=$(oc get route workshop-evalhub -n "${WORKSHOP_NAMESPACE}" \
  -o jsonpath='{.spec.host}' 2>/dev/null || echo "")
EVALHUB_TOKEN_FRESH=$(oc create token workshop-sa -n "${WORKSHOP_NAMESPACE}" --duration=8h 2>/dev/null || echo "")

if [[ -n "${EVALHUB_ROUTE}" ]]; then
  ok "EvalHub route: https://${EVALHUB_ROUTE}"

  # Ensure RBAC is in place (idempotent apply)
  info "Applying EvalHub RBAC for workshop-sa..."
  oc apply -f - >/dev/null <<RBACEOF
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: workshop-sa-evalhub-collections
  namespace: ${WORKSHOP_NAMESPACE}
  labels: {workshop: icad2026}
subjects:
- {kind: ServiceAccount, name: workshop-sa, namespace: ${WORKSHOP_NAMESPACE}}
roleRef: {kind: ClusterRole, name: trustyai-service-operator-evalhub-collections-access, apiGroup: rbac.authorization.k8s.io}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: workshop-sa-evalhub-providers
  namespace: ${WORKSHOP_NAMESPACE}
  labels: {workshop: icad2026}
subjects:
- {kind: ServiceAccount, name: workshop-sa, namespace: ${WORKSHOP_NAMESPACE}}
roleRef: {kind: ClusterRole, name: trustyai-service-operator-evalhub-providers-access, apiGroup: rbac.authorization.k8s.io}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: workshop-sa-lmeval-user
  namespace: ${WORKSHOP_NAMESPACE}
  labels: {workshop: icad2026}
subjects:
- {kind: ServiceAccount, name: workshop-sa, namespace: ${WORKSHOP_NAMESPACE}}
roleRef: {kind: ClusterRole, name: trustyai-service-operator-lmeval-user-role, apiGroup: rbac.authorization.k8s.io}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: workshop-evalhub-evaluations-access
  namespace: ${WORKSHOP_NAMESPACE}
  labels: {workshop: icad2026}
rules:
- apiGroups: ["trustyai.opendatahub.io"]
  resources: ["evaluations"]
  verbs: ["get","list","create","update","patch","delete"]
- apiGroups: ["mlflow.kubeflow.org"]
  resources: ["experiments"]
  verbs: ["get","list","create"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: workshop-sa-evalhub-evaluations
  namespace: ${WORKSHOP_NAMESPACE}
  labels: {workshop: icad2026}
subjects:
- {kind: ServiceAccount, name: workshop-sa, namespace: ${WORKSHOP_NAMESPACE}}
roleRef: {kind: Role, name: workshop-evalhub-evaluations-access, apiGroup: rbac.authorization.k8s.io}
RBACEOF
  ok "EvalHub RBAC applied."

  # Switch CLI from local server to the cluster EvalHub
  evalhub config set base_url "https://${EVALHUB_ROUTE}" 2>/dev/null
  evalhub config set token "${EVALHUB_TOKEN_FRESH}" 2>/dev/null
  evalhub config set tenant "${WORKSHOP_NAMESPACE}" 2>/dev/null
  ok "evalhub CLI switched: local → cluster (https://${EVALHUB_ROUTE})"

  # Stop local server if still running
  if [[ -f /tmp/evalhub-local.pid ]]; then
    OLD_PID=$(cat /tmp/evalhub-local.pid 2>/dev/null || echo "")
    [[ -n "${OLD_PID}" ]] && kill "${OLD_PID}" 2>/dev/null && \
      info "Local eval-hub-server stopped (PID ${OLD_PID})"
    rm -f /tmp/evalhub-local.pid
  fi
else
  warn "Could not detect workshop-evalhub route."
fi

if evalhub health 2>/dev/null | grep -qi "healthy\|ok"; then
  ok "EvalHub API is healthy."
  DASHBOARD=$(oc get route rhods-dashboard -n redhat-ods-applications \
    -o jsonpath='{.spec.host}' 2>/dev/null || echo "")
  [[ -n "${DASHBOARD}" ]] && echo "  RHOAI Dashboard: https://${DASHBOARD}"
else
  warn "EvalHub health check uncertain. Proceed carefully."
fi

# =============================================================================
# Step 6: Generate live LMEvalJob manifest
# =============================================================================
info "Generating live LMEvalJob manifest..."
MODEL="${MODEL_NAME:-liquid/lfm-2.5-1.2b-instruct:free}"
sed \
  -e "s|\${MODEL_ENDPOINT}|${MODEL_ENDPOINT:-https://openrouter.ai/api/v1}|g" \
  -e "s|\${MODEL_NAME}|${MODEL}|g" \
  -e "s|\${WORKSHOP_NAMESPACE}|${WORKSHOP_NAMESPACE}|g" \
  "${EVALRUN_TEMPLATE}" > "${EVALRUN_LIVE}"
ok "LMEvalJob manifest: ${EVALRUN_LIVE}"

# =============================================================================
# Done
# =============================================================================
echo ""
echo "============================================================"
echo "  Section 04 setup complete."
echo ""
[[ -n "${EVALHUB_ROUTE:-}" ]] && echo "  EvalHub API: https://${EVALHUB_ROUTE}"
echo ""
echo "  Follow the steps in lab.md"
echo "============================================================"

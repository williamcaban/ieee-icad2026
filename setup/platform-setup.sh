#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# platform-setup.sh — Full workshop environment provisioning
# Run this script as a cluster admin at least 24 hours before the workshop.
# =============================================================================

WORKSHOP_NAMESPACE="workshop-eval"
MODEL_NAME="granite-3-2b"
EVALHUB_VERSION="0.4.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Resolve workshop root from this script's location
WORKSHOP_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKSHOP_ENV_FILE="${WORKSHOP_ROOT}/.workshop-env"

info()  { echo "[INFO]  $*"; }
ok()    { echo "[OK]    $*"; }
warn()  { echo "[WARN]  $*"; }
fail()  { echo "[FAIL]  $*" >&2; exit 1; }

# =============================================================================
# Step 1: Verify prerequisites
# =============================================================================
info "Step 1: Verifying prerequisites..."

command -v oc >/dev/null 2>&1   || fail "oc CLI not found. Install OpenShift CLI from https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/"
command -v kubectl >/dev/null 2>&1 || fail "kubectl not found. Install from https://kubernetes.io/docs/tasks/tools/"
command -v python3 >/dev/null 2>&1 || fail "python3 not found. Install Python 3.10+."
command -v pip3 >/dev/null 2>&1    || fail "pip3 not found."
command -v envsubst >/dev/null 2>&1 || fail "envsubst not found. Install gettext: brew install gettext or dnf install gettext."
command -v jq >/dev/null 2>&1      || fail "jq not found. Install: brew install jq or dnf install jq."

# Verify cluster connectivity
if ! oc whoami >/dev/null 2>&1; then
  fail "Not logged in to OpenShift. Run: oc login <cluster-api> -u <user> -p <password>"
fi

CLUSTER_USER=$(oc whoami)
CLUSTER_API=$(oc whoami --show-server)
info "Logged in as '${CLUSTER_USER}' to ${CLUSTER_API}"

# Verify cluster admin
if ! oc auth can-i create namespace --all-namespaces >/dev/null 2>&1; then
  fail "User '${CLUSTER_USER}' does not have cluster-admin access. Cannot create namespaces."
fi

ok "Prerequisites verified."

# =============================================================================
# Step 2: Create workshop namespace
# =============================================================================
info "Step 2: Creating namespace '${WORKSHOP_NAMESPACE}'..."

if oc get namespace "${WORKSHOP_NAMESPACE}" >/dev/null 2>&1; then
  warn "Namespace '${WORKSHOP_NAMESPACE}' already exists. Skipping creation."
else
  oc create namespace "${WORKSHOP_NAMESPACE}"
  ok "Namespace '${WORKSHOP_NAMESPACE}' created."
fi

# Label namespace for EvalHub operator watching
oc label namespace "${WORKSHOP_NAMESPACE}" \
  evalhub.rhoai.redhat.com/managed=true \
  workshop=icad2026 \
  --overwrite

# =============================================================================
# Step 3: Configure RBAC for workshop participants
# =============================================================================
info "Step 3: Configuring RBAC for workshop participants..."

oc apply -f - <<'RBAC_EOF'
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: workshop-participant
  namespace: workshop-eval
rules:
  - apiGroups: ["evalhub.rhoai.redhat.com"]
    resources: ["collections", "evalruns", "benchmarks"]
    verbs: ["get", "list", "watch", "create", "update", "patch"]
  - apiGroups: [""]
    resources: ["pods", "pods/log", "services", "configmaps"]
    verbs: ["get", "list", "watch"]
  - apiGroups: ["pipelines.kubeflow.org"]
    resources: ["pipelineruns", "pipelines"]
    verbs: ["get", "list", "watch", "create"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: workshop-participants-binding
  namespace: workshop-eval
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: workshop-participant
subjects:
  - kind: Group
    name: workshop-participants
    apiGroup: rbac.authorization.k8s.io
RBAC_EOF

ok "RBAC configured."

# =============================================================================
# Step 4: Deploy EvalHub CR
# =============================================================================
info "Step 4: Deploying EvalHub CR in namespace '${WORKSHOP_NAMESPACE}'..."

oc apply -f - <<'EVALHUB_CR_EOF'
apiVersion: evalhub.rhoai.redhat.com/v1alpha1
kind: EvalHub
metadata:
  name: workshop-eval
  namespace: workshop-eval
spec:
  version: "0.4.0"
  storage:
    storageClass: "gp3-csi"
    size: "50Gi"
  benchmarkCatalog:
    includeBuiltins: true
  priorityClassName: "workshop-high"
  resources:
    requests:
      cpu: "2"
      memory: "4Gi"
    limits:
      cpu: "4"
      memory: "8Gi"
EVALHUB_CR_EOF

info "Waiting for EvalHub CR to become ready (timeout: 5 minutes)..."
timeout=300
elapsed=0
while true; do
  ready=$(oc get evalhub workshop-eval -n "${WORKSHOP_NAMESPACE}" -o jsonpath='{.status.ready}' 2>/dev/null || echo "false")
  if [[ "${ready}" == "true" ]]; then
    ok "EvalHub CR is Ready."
    break
  fi
  if [[ ${elapsed} -ge ${timeout} ]]; then
    fail "EvalHub CR did not become ready within ${timeout}s. Check: oc describe evalhub workshop-eval -n ${WORKSHOP_NAMESPACE}"
  fi
  info "EvalHub not ready yet (${elapsed}s elapsed). Waiting..."
  sleep 15
  elapsed=$((elapsed + 15))
done

# =============================================================================
# Step 5: Deploy model serving endpoint (granite-3-2b via vLLM)
# =============================================================================
info "Step 5: Deploying ${MODEL_NAME} model serving endpoint..."

oc apply -f - <<'MODEL_EOF'
apiVersion: serving.kserve.io/v1beta1
kind: InferenceService
metadata:
  name: granite-3-2b
  namespace: workshop-eval
  labels:
    app: granite-3-2b
    workshop: icad2026
  annotations:
    serving.kserve.io/deploymentMode: RawDeployment
spec:
  predictor:
    model:
      modelFormat:
        name: vLLM
      runtime: vllm-runtime
      storageUri: "hf://ibm-granite/granite-3.2-2b-instruct"
      resources:
        requests:
          cpu: "4"
          memory: "16Gi"
          nvidia.com/gpu: "1"
        limits:
          cpu: "8"
          memory: "24Gi"
          nvidia.com/gpu: "1"
      args:
        - "--max-model-len=4096"
        - "--max-num-seqs=16"
        - "--dtype=bfloat16"
MODEL_EOF

info "Waiting for InferenceService to become ready (timeout: 10 minutes)..."
timeout=600
elapsed=0
while true; do
  ready=$(oc get inferenceservice granite-3-2b -n "${WORKSHOP_NAMESPACE}" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "False")
  if [[ "${ready}" == "True" ]]; then
    ok "InferenceService granite-3-2b is Ready."
    break
  fi
  if [[ ${elapsed} -ge ${timeout} ]]; then
    fail "InferenceService did not become ready within ${timeout}s. Check: oc describe inferenceservice granite-3-2b -n ${WORKSHOP_NAMESPACE}"
  fi
  info "InferenceService not ready yet (${elapsed}s elapsed). Waiting..."
  sleep 20
  elapsed=$((elapsed + 20))
done

# =============================================================================
# Step 6: Retrieve endpoints and write workshop-env file
# =============================================================================
info "Step 6: Retrieving endpoints and writing ${WORKSHOP_ENV_FILE}..."

EVALHUB_ROUTE=$(oc get route evalhub-api -n "${WORKSHOP_NAMESPACE}" -o jsonpath='{.spec.host}' 2>/dev/null || echo "")
if [[ -z "${EVALHUB_ROUTE}" ]]; then
  # Try service route annotation
  EVALHUB_ROUTE=$(oc get svc evalhub-api -n "${WORKSHOP_NAMESPACE}" -o jsonpath='{.metadata.annotations.route\.openshift\.io/hostname}' 2>/dev/null || echo "")
fi
if [[ -z "${EVALHUB_ROUTE}" ]]; then
  warn "Could not auto-detect EvalHub route. Setting placeholder — update manually."
  EVALHUB_ROUTE="evalhub-api-workshop-eval.apps.$(oc get infrastructure cluster -o jsonpath='{.status.etcdDiscoveryDomain}' 2>/dev/null || echo 'cluster.example.com')"
fi

MODEL_ROUTE=$(oc get inferenceservice granite-3-2b -n "${WORKSHOP_NAMESPACE}" -o jsonpath='{.status.url}' 2>/dev/null || echo "")
if [[ -z "${MODEL_ROUTE}" ]]; then
  warn "Could not auto-detect model route. Setting placeholder — update manually."
  MODEL_ROUTE="https://granite-3-2b-workshop-eval.apps.cluster.example.com"
fi

KFP_ROUTE=$(oc get route ds-pipeline-ui -n "${WORKSHOP_NAMESPACE}" -o jsonpath='{.spec.host}' 2>/dev/null || echo "")
if [[ -z "${KFP_ROUTE}" ]]; then
  KFP_ROUTE=$(oc get route ds-pipeline-ui -n redhat-ods-applications -o jsonpath='{.spec.host}' 2>/dev/null || echo "")
fi
if [[ -z "${KFP_ROUTE}" ]]; then
  warn "Could not auto-detect KFP route. Setting placeholder."
  KFP_ROUTE="ds-pipeline-ui-workshop-eval.apps.cluster.example.com"
fi

# Retrieve service account token for EvalHub API authentication
EVALHUB_TOKEN=$(oc create token workshop-sa -n "${WORKSHOP_NAMESPACE}" --duration=24h 2>/dev/null || echo "")
if [[ -z "${EVALHUB_TOKEN}" ]]; then
  # Create service account if it doesn't exist
  oc create serviceaccount workshop-sa -n "${WORKSHOP_NAMESPACE}" 2>/dev/null || true
  EVALHUB_TOKEN=$(oc create token workshop-sa -n "${WORKSHOP_NAMESPACE}" --duration=24h 2>/dev/null || echo "PLACEHOLDER_TOKEN")
fi

cat > "${WORKSHOP_ENV_FILE}" <<ENVEOF
# Workshop environment variables — IEEE ICAD 2026
# Generated by platform-setup.sh on $(date -u +%Y-%m-%dT%H:%M:%SZ)
# Source this file before running workshop exercises: source .workshop-env (in workshop root)

export WORKSHOP_NAMESPACE="workshop-eval"
export EVALHUB_ENDPOINT="https://${EVALHUB_ROUTE}"
export MODEL_ENDPOINT="${MODEL_ROUTE}"
export KFP_ENDPOINT="https://${KFP_ROUTE}"
export EVALHUB_TOKEN="${EVALHUB_TOKEN}"

# Convenience aliases
alias evalhub-ns="kubectl config set-context --current --namespace=workshop-eval"
ENVEOF

chmod 600 "${WORKSHOP_ENV_FILE}"
ok "Workshop environment file written to ${WORKSHOP_ENV_FILE}"

# =============================================================================
# Step 7: Smoke test
# =============================================================================
info "Step 7: Running smoke tests..."

source "${WORKSHOP_ENV_FILE}"

# Test EvalHub API
if curl -sf -H "Authorization: Bearer ${EVALHUB_TOKEN}" "${EVALHUB_ENDPOINT}/api/v1/collections" >/dev/null 2>&1; then
  ok "EvalHub API smoke test: PASS"
else
  warn "EvalHub API smoke test: FAIL — endpoint may still be initializing. Re-run verify-environment.sh."
fi

# Test model endpoint
if curl -sf "${MODEL_ENDPOINT}/v1/health" >/dev/null 2>&1; then
  ok "Model endpoint smoke test: PASS"
else
  warn "Model endpoint smoke test: FAIL — model may still be loading. Re-run verify-environment.sh."
fi

# =============================================================================
# Done
# =============================================================================
echo ""
echo "============================================================"
echo "  Workshop environment provisioning complete!"
echo "  Namespace:       ${WORKSHOP_NAMESPACE}"
echo "  EvalHub:         ${EVALHUB_ENDPOINT}"
echo "  Model endpoint:  ${MODEL_ENDPOINT}"
echo "  KFP:             ${KFP_ENDPOINT}"
echo "  Env file:        ${WORKSHOP_ENV_FILE}"
echo ""
echo "  Run verify-environment.sh before the workshop to confirm"
echo "  all checks pass."
echo "============================================================"

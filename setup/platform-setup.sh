#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# platform-setup.sh — Cluster provisioning for the IEEE ICAD 2026 workshop.
#
# Run as cluster-admin at least 24 hours before the workshop.
# Idempotent: safe to run multiple times.
#
# What this script provisions:
#   1. workshop-eval namespace with required labels
#   2. EvalHub CR in workshop-eval (tenant namespace)
#   3. EvalHub CR in redhat-ods-applications (for BFF UI discovery)
#   4. evalhub-evaluator RBAC for participants in workshop-eval
#   5. evalhub-cr-reader RBAC in redhat-ods-applications (for BFF)
#   6. DSC permitOnline: allow (required for HuggingFace dataset downloads)
#   7. OpenRouter credentials secret
#   8. DataSciencePipelinesApplication (for Section 06 reference)
# =============================================================================

WORKSHOP_NAMESPACE="workshop-eval"
WORKSHOP_GROUP="workshop-participants"   # OpenShift group name for attendees
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

command -v oc     >/dev/null 2>&1 || fail "oc not found. Install from https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/"
command -v python3 >/dev/null 2>&1 || fail "python3 not found. Install Python 3.12+."

oc whoami >/dev/null 2>&1 || fail "Not logged in. Run: oc login <cluster-api>"

CLUSTER_USER=$(oc whoami)
CLUSTER_API=$(oc whoami --show-server)
info "Logged in as '${CLUSTER_USER}' to ${CLUSTER_API}"

oc auth can-i create namespace --all-namespaces >/dev/null 2>&1 || \
  fail "'${CLUSTER_USER}' is not cluster-admin."

# Check RHOAI / TrustyAI operator is present
oc get crd evalhubs.trustyai.opendatahub.io >/dev/null 2>&1 || \
  fail "EvalHub CRD not found. Ensure RHOAI 3.4+ with TrustyAI component is installed."

ok "Prerequisites verified."

# =============================================================================
# Step 2: Enable permitOnline in DSC (required for HuggingFace downloads)
# =============================================================================
info "Step 2: Enabling permitOnline in DataScienceCluster..."

oc patch datasciencecluster default-dsc --type=merge \
  -p '{"spec":{"components":{"trustyai":{"eval":{"lmeval":{"permitOnline":"allow"}}}}}}' \
  >/dev/null 2>&1 && ok "DSC permitOnline set to allow." || \
  warn "Could not patch DSC — check if default-dsc exists."

# =============================================================================
# Step 3: Create and label the workshop namespace
# =============================================================================
info "Step 3: Creating namespace '${WORKSHOP_NAMESPACE}'..."

oc get namespace "${WORKSHOP_NAMESPACE}" >/dev/null 2>&1 || \
  oc create namespace "${WORKSHOP_NAMESPACE}"

# Required labels:
#   opendatahub.io/dashboard=true          → namespace appears in RHOAI Dashboard
#   evalhub.trustyai.opendatahub.io/tenant=true → operator provisions job SA/RBAC
oc label namespace "${WORKSHOP_NAMESPACE}" \
  opendatahub.io/dashboard=true \
  "evalhub.trustyai.opendatahub.io/tenant=true" \
  workshop=icad2026 \
  --overwrite

ok "Namespace '${WORKSHOP_NAMESPACE}' ready with required labels."

# =============================================================================
# Step 4: Create workshop service account and RBAC in workshop-eval
# =============================================================================
info "Step 4: Configuring RBAC in '${WORKSHOP_NAMESPACE}'..."

oc create sa workshop-sa -n "${WORKSHOP_NAMESPACE}" 2>/dev/null || true
oc adm policy add-role-to-user admin -z workshop-sa -n "${WORKSHOP_NAMESPACE}" 2>/dev/null || true

# evalhub-evaluator: grants access to all EvalHub virtual resources + LMEvalJobs
oc apply -f - <<RBACEOF
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: evalhub-evaluator
  namespace: ${WORKSHOP_NAMESPACE}
  labels:
    workshop: icad2026
rules:
  - apiGroups: ["trustyai.opendatahub.io"]
    resources: ["evaluations"]
    verbs: ["get", "list", "create", "update", "delete"]
  - apiGroups: ["trustyai.opendatahub.io"]
    resources: ["collections"]
    verbs: ["get", "list", "create", "update", "delete"]
  - apiGroups: ["trustyai.opendatahub.io"]
    resources: ["providers"]
    verbs: ["get", "list", "create", "update", "delete"]
  - apiGroups: ["trustyai.opendatahub.io"]
    resources: ["lmevaljobs", "lmevaljobs/status"]
    verbs: ["get", "list", "watch"]
  - apiGroups: ["mlflow.kubeflow.org"]
    resources: ["experiments"]
    verbs: ["create", "get"]
RBACEOF

# Bind evalhub-evaluator to the workshop SA, the participant group, and any user
oc apply -f - <<BINDEOF
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: workshop-sa-evalhub-access
  namespace: ${WORKSHOP_NAMESPACE}
  labels:
    workshop: icad2026
subjects:
- kind: ServiceAccount
  name: workshop-sa
  namespace: ${WORKSHOP_NAMESPACE}
roleRef:
  kind: Role
  name: evalhub-evaluator
  apiGroup: rbac.authorization.k8s.io
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: workshop-group-evalhub-access
  namespace: ${WORKSHOP_NAMESPACE}
  labels:
    workshop: icad2026
subjects:
- kind: Group
  name: ${WORKSHOP_GROUP}
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: evalhub-evaluator
  apiGroup: rbac.authorization.k8s.io
BINDEOF

ok "RBAC configured in '${WORKSHOP_NAMESPACE}'."

# =============================================================================
# Step 5: EvalHub in redhat-ods-applications (required for BFF URL discovery)
#
# The RHOAI Dashboard BFF lists evalhubs.trustyai.opendatahub.io in its own
# namespace (redhat-ods-applications) to discover the EvalHub service URL.
# Without this CR, the UI shows "Evaluations unavailable" for all users.
# =============================================================================
info "Step 5: Deploying platform EvalHub in 'redhat-ods-applications'..."

oc apply -f - <<PLATFORM_EVALHUB
apiVersion: trustyai.opendatahub.io/v1alpha1
kind: EvalHub
metadata:
  name: evalhub
  namespace: redhat-ods-applications
spec:
  replicas: 1
  providers:
    - lm-evaluation-harness
    - garak
  collections:
    - safety-and-fairness-v1
    - toxicity-and-ethical-principles
    - leaderboard-v2
  database:
    type: sqlite
    maxIdleConns: 5
    maxOpenConns: 25
PLATFORM_EVALHUB

ok "Platform EvalHub CR applied in 'redhat-ods-applications'."

# =============================================================================
# Step 6: EvalHub in workshop-eval (tenant instance for participant evaluations)
# =============================================================================
info "Step 6: Deploying tenant EvalHub in '${WORKSHOP_NAMESPACE}'..."

oc apply -f - <<TENANT_EVALHUB
apiVersion: trustyai.opendatahub.io/v1alpha1
kind: EvalHub
metadata:
  name: workshop-evalhub
  namespace: ${WORKSHOP_NAMESPACE}
  labels:
    workshop: icad2026
spec:
  replicas: 1
  providers:
    - lm-evaluation-harness
    - garak
  collections:
    - safety-and-fairness-v1
    - toxicity-and-ethical-principles
  database:
    type: sqlite
    maxIdleConns: 5
    maxOpenConns: 25
TENANT_EVALHUB

info "Waiting for tenant EvalHub to become Ready..."
for i in $(seq 1 24); do
  sleep 5
  PHASE=$(oc get evalhub workshop-evalhub -n "${WORKSHOP_NAMESPACE}" \
    -o jsonpath='{.status.phase}' 2>/dev/null || echo "")
  [[ "${PHASE}" == "Ready" ]] && { ok "Tenant EvalHub is Ready."; break; }
  [[ "${i}" == "24" ]] && warn "Tenant EvalHub not Ready after 120s. Check: oc describe evalhub workshop-evalhub -n ${WORKSHOP_NAMESPACE}"
done

# =============================================================================
# Step 7: RBAC for BFF URL discovery in redhat-ods-applications
#
# The BFF uses the participant's token to list evalhubs.trustyai.opendatahub.io
# in redhat-ods-applications. Participants need get/list on evalhubs there.
# =============================================================================
info "Step 7: Configuring BFF discovery RBAC in 'redhat-ods-applications'..."

oc apply -f - <<BFF_RBAC
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: evalhub-cr-reader
  namespace: redhat-ods-applications
  labels:
    workshop: icad2026
rules:
- apiGroups: ["trustyai.opendatahub.io"]
  resources: ["evalhubs"]
  verbs: ["get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: workshop-group-evalhub-cr-reader
  namespace: redhat-ods-applications
  labels:
    workshop: icad2026
subjects:
- kind: Group
  name: ${WORKSHOP_GROUP}
  apiGroup: rbac.authorization.k8s.io
- kind: ServiceAccount
  name: workshop-sa
  namespace: ${WORKSHOP_NAMESPACE}
roleRef:
  kind: Role
  name: evalhub-cr-reader
  apiGroup: rbac.authorization.k8s.io
BFF_RBAC

ok "BFF discovery RBAC configured."

# =============================================================================
# Step 8: OpenRouter credentials secret
# =============================================================================
info "Step 8: Creating OpenRouter credentials secret..."

OPENROUTER_API_KEY="${OPENROUTER_API_KEY:-}"
if [[ -z "${OPENROUTER_API_KEY}" || "${OPENROUTER_API_KEY}" == *"REPLACE"* ]]; then
  warn "OPENROUTER_API_KEY is not set in environment."
  warn "Set it and re-run, or participants can create it themselves:"
  warn "  oc create secret generic openrouter-credentials \\"
  warn "    -n ${WORKSHOP_NAMESPACE} \\"
  warn "    --from-literal=OPENROUTER_API_KEY=<key>"
else
  oc create secret generic openrouter-credentials \
    -n "${WORKSHOP_NAMESPACE}" \
    --from-literal=OPENROUTER_API_KEY="${OPENROUTER_API_KEY}" \
    --dry-run=client -o yaml | oc apply -f - >/dev/null
  ok "openrouter-credentials secret ready in '${WORKSHOP_NAMESPACE}'."
fi

# =============================================================================
# Step 9: DataSciencePipelinesApplication (for Section 06 pipeline reference)
# =============================================================================
info "Step 9: Deploying DataSciencePipelinesApplication..."

oc apply -f - <<DSPA
apiVersion: datasciencepipelinesapplications.opendatahub.io/v1
kind: DataSciencePipelinesApplication
metadata:
  name: dspa-workshop
  namespace: ${WORKSHOP_NAMESPACE}
spec:
  apiServer:
    deploy: true
    enableSamplePipeline: false
  database:
    disableHealthCheck: false
    mariaDB:
      deploy: true
      pipelineDBName: mlpipeline
      username: mlpipeline
  objectStorage:
    disableHealthCheck: false
    minio:
      deploy: true
      image: quay.io/opendatahub/minio:RELEASE.2019-08-14T20-37-41Z-license-compliance
DSPA

ok "DataSciencePipelinesApplication applied."

# =============================================================================
# Step 10: Generate .workshop-env with live endpoints
# =============================================================================
info "Step 10: Writing ${WORKSHOP_ENV_FILE}..."

EVALHUB_ROUTE=$(oc get route workshop-evalhub -n "${WORKSHOP_NAMESPACE}" \
  -o jsonpath='{.spec.host}' 2>/dev/null || echo "")
KFP_ROUTE=$(oc get route ds-pipeline-dspa-workshop -n "${WORKSHOP_NAMESPACE}" \
  -o jsonpath='{.spec.host}' 2>/dev/null || echo "")
WORKSHOP_TOKEN=$(oc create token workshop-sa -n "${WORKSHOP_NAMESPACE}" \
  --duration=24h 2>/dev/null || echo "")
DASHBOARD_ROUTE=$(oc get route rhods-dashboard -n redhat-ods-applications \
  -o jsonpath='{.spec.host}' 2>/dev/null || echo "")

cat > "${WORKSHOP_ENV_FILE}" <<ENVEOF
# IEEE ICAD 2026 Workshop — environment variables
# Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)
# Source before each session: source .workshop-env

export WORKSHOP_NAMESPACE="${WORKSHOP_NAMESPACE}"

# EvalHub — cluster tenant instance
export EVALHUB_ENDPOINT="${EVALHUB_ROUTE:+https://${EVALHUB_ROUTE}}"
export EVALHUB_TOKEN="${WORKSHOP_TOKEN}"
export EVALHUB_CLUSTER_ENDPOINT="${EVALHUB_ROUTE:+https://${EVALHUB_ROUTE}}"

# OpenRouter — free OpenAI-compatible inference API
export MODEL_ENDPOINT="https://openrouter.ai/api/v1"
export MODEL_NAME_A="liquid/lfm-2.5-1.2b-instruct:free"
export MODEL_NAME_B="meta-llama/llama-3.3-70b-instruct:free"
export MODEL_NAME="\${MODEL_NAME_A}"
export OPENROUTER_API_KEY="${OPENROUTER_API_KEY:-sk-or-v1-REPLACE-WITH-YOUR-KEY}"

# KubeFlow Pipelines (for Section reference)
export KFP_ENDPOINT="${KFP_ROUTE:+https://${KFP_ROUTE}}"

# RHOAI Dashboard
export RHOAI_DASHBOARD="${DASHBOARD_ROUTE:+https://${DASHBOARD_ROUTE}}"

# Local eval-hub-server (started by 01-setup/setup.sh)
export EVALHUB_LOCAL_PORT="18080"
ENVEOF

chmod 600 "${WORKSHOP_ENV_FILE}"
ok "Workshop environment file written to ${WORKSHOP_ENV_FILE}"

# =============================================================================
# Done
# =============================================================================
echo ""
echo "============================================================"
echo "  Cluster provisioning complete."
echo ""
echo "  Workshop namespace:  ${WORKSHOP_NAMESPACE}"
[[ -n "${EVALHUB_ROUTE}" ]] && echo "  Tenant EvalHub:     https://${EVALHUB_ROUTE}"
[[ -n "${DASHBOARD_ROUTE}" ]] && echo "  RHOAI Dashboard:    https://${DASHBOARD_ROUTE}"
echo "  Env file:           ${WORKSHOP_ENV_FILE}"
echo ""
echo "  Next: run verify-environment.sh to confirm all checks pass."
echo "  Share ${WORKSHOP_ENV_FILE} with participants (after setting API key)."
echo "============================================================"

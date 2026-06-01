#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Section 01 setup.sh — Configure workshop environment and evalhub CLI.
# Idempotent: safe to run multiple times.
# =============================================================================

WORKSHOP_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKSHOP_ENV_FILE="${WORKSHOP_ROOT}/.workshop-env"
WORKSHOP_NAMESPACE="workshop-eval"

info() { echo "[INFO]  $*"; }
ok()   { echo "[OK]    $*"; }
warn() { echo "[WARN]  $*"; }
fail() { echo "[FAIL]  $*" >&2; exit 1; }

# =============================================================================
# Step 1: Verify uv environment tools
# =============================================================================
info "Checking uv environment tools..."
for tool in lm_eval garak evalhub eval-hub-server; do
  if command -v "${tool}" >/dev/null 2>&1; then
    ver="$(${tool} --version 2>/dev/null || echo 'ok')"
    ok "${tool}: ${ver:-ok}"
  else
    fail "${tool} not found. Run: source .venv/bin/activate (from repo root)"
  fi
done

# =============================================================================
# Step 2: Source or create .workshop-env
# =============================================================================
info "Checking workshop environment file..."

if [[ -f "${WORKSHOP_ENV_FILE}" ]]; then
  source "${WORKSHOP_ENV_FILE}"
  ok "Loaded ${WORKSHOP_ENV_FILE}"
else
  if [[ -f "${WORKSHOP_ROOT}/.workshop-env.example" ]]; then
    cp "${WORKSHOP_ROOT}/.workshop-env.example" "${WORKSHOP_ENV_FILE}"
    chmod 600 "${WORKSHOP_ENV_FILE}"
    warn "Created ${WORKSHOP_ENV_FILE} from example."
    warn "REQUIRED: Edit ${WORKSHOP_ENV_FILE} and set OPENROUTER_API_KEY"
    warn "Get a free key at: https://openrouter.ai/keys"
  else
    fail ".workshop-env.example not found in repo root."
  fi
  source "${WORKSHOP_ENV_FILE}"
fi

# Validate OpenRouter key
if [[ -z "${OPENROUTER_API_KEY:-}" || "${OPENROUTER_API_KEY}" == *"REPLACE"* ]]; then
  warn "OPENROUTER_API_KEY is not set. Sections 01-02 will not work without it."
  warn "Edit ${WORKSHOP_ENV_FILE} and add your key, then re-run this script."
else
  ok "OPENROUTER_API_KEY is set (${#OPENROUTER_API_KEY} chars)."
fi

# =============================================================================
# Step 3: Start local eval-hub-server (Sections 01-02, no cluster needed)
# =============================================================================
EVALHUB_LOCAL_PORT=18080
EVALHUB_LOCAL_URL="http://localhost:${EVALHUB_LOCAL_PORT}"
EVALHUB_LOCAL_PID_FILE="/tmp/evalhub-local.pid"

info "Starting local eval-hub-server on port ${EVALHUB_LOCAL_PORT}..."

# Kill any existing instance on this port
if [[ -f "${EVALHUB_LOCAL_PID_FILE}" ]]; then
  OLD_PID=$(cat "${EVALHUB_LOCAL_PID_FILE}" 2>/dev/null || echo "")
  [[ -n "${OLD_PID}" ]] && kill "${OLD_PID}" 2>/dev/null || true
  rm -f "${EVALHUB_LOCAL_PID_FILE}"
fi
lsof -ti:"${EVALHUB_LOCAL_PORT}" 2>/dev/null | xargs kill -9 2>/dev/null || true
sleep 1

# Start the server in the background — export API keys so adapters inherit them
cd "${WORKSHOP_ROOT}"
export OPENAI_API_KEY="${OPENROUTER_API_KEY}"
PORT="${EVALHUB_LOCAL_PORT}" \
  eval-hub-server --local --configdir config/ \
  > /tmp/evalhub-local.log 2>&1 &
EVALHUB_LOCAL_PID=$!
echo "${EVALHUB_LOCAL_PID}" > "${EVALHUB_LOCAL_PID_FILE}"

# Wait for it to be ready
for i in $(seq 1 15); do
  sleep 1
  if curl -sf "${EVALHUB_LOCAL_URL}/api/v1/health" >/dev/null 2>&1; then
    ok "Local eval-hub-server ready at ${EVALHUB_LOCAL_URL} (PID ${EVALHUB_LOCAL_PID})"
    break
  fi
  [[ "${i}" == "15" ]] && { warn "Local server did not start — check /tmp/evalhub-local.log"; }
done

# Configure CLI to point to local server (no auth, no tenant needed)
evalhub config set base_url "${EVALHUB_LOCAL_URL}" 2>/dev/null
evalhub config set token "" 2>/dev/null
evalhub config set tenant "" 2>/dev/null

# Register providers (idempotent — server accepts re-registration)
for provider_yaml in "${WORKSHOP_ROOT}"/config/providers/*.yaml; do
  provider_id=$(python3 -c "import yaml; print(yaml.safe_load(open('${provider_yaml}'))['id'])" 2>/dev/null)
  evalhub providers create --file "${provider_yaml}" 2>/dev/null && \
    ok "Provider registered: ${provider_id}" || \
    info "Provider already registered: ${provider_id}"
done

# Persist local URL in .workshop-env
grep -v "^export EVALHUB_ENDPOINT\|^export EVALHUB_TOKEN" \
  "${WORKSHOP_ENV_FILE}" > /tmp/wenv_tmp && mv /tmp/wenv_tmp "${WORKSHOP_ENV_FILE}"
{
  echo "export EVALHUB_ENDPOINT=\"${EVALHUB_LOCAL_URL}\""
  echo "export EVALHUB_TOKEN=\"\""
  echo "export EVALHUB_LOCAL_PORT=\"${EVALHUB_LOCAL_PORT}\""
} >> "${WORKSHOP_ENV_FILE}"
chmod 600 "${WORKSHOP_ENV_FILE}"

echo ""
echo "  Local EvalHub: ${EVALHUB_LOCAL_URL}"
echo "  Log: /tmp/evalhub-local.log"
echo "  Stop: kill \$(cat /tmp/evalhub-local.pid)"
echo ""

# =============================================================================
# Step 4: Configure evalhub CLI for cluster (Section 04 — optional now)
# =============================================================================
info "Checking cluster access for Section 04..."

if ! oc whoami >/dev/null 2>&1; then
  warn "Not logged in to OpenShift — cluster config skipped (needed for Section 04 only)."
  warn "Log in before Section 04: oc login <cluster-api>"
else
  # Auto-detect EvalHub endpoint and refresh token
  EVALHUB_ROUTE=$(oc get route workshop-evalhub -n "${WORKSHOP_NAMESPACE}" \
    -o jsonpath='{.spec.host}' 2>/dev/null || echo "")
  EVALHUB_TOKEN=$(oc create token workshop-sa -n "${WORKSHOP_NAMESPACE}" \
    --duration=8h 2>/dev/null || echo "")
  KFP_ROUTE=$(oc get route ds-pipeline-dspa-workshop -n "${WORKSHOP_NAMESPACE}" \
    -o jsonpath='{.spec.host}' 2>/dev/null || echo "")

  if [[ -n "${EVALHUB_ROUTE}" ]]; then
    export EVALHUB_ENDPOINT="https://${EVALHUB_ROUTE}"

    # Update .workshop-env with live values
    grep -v "^export EVALHUB_ENDPOINT\|^export EVALHUB_TOKEN\|^export KFP_ENDPOINT" \
      "${WORKSHOP_ENV_FILE}" > /tmp/wenv_tmp && mv /tmp/wenv_tmp "${WORKSHOP_ENV_FILE}"
    {
      echo "export EVALHUB_ENDPOINT=\"https://${EVALHUB_ROUTE}\""
      echo "export EVALHUB_TOKEN=\"${EVALHUB_TOKEN}\""
      [[ -n "${KFP_ROUTE}" ]] && echo "export KFP_ENDPOINT=\"https://${KFP_ROUTE}\""
    } >> "${WORKSHOP_ENV_FILE}"
    chmod 600 "${WORKSHOP_ENV_FILE}"

    # ==========================================================================
    # Grant workshop-sa the RBAC needed for EvalHub API (SubjectAccessReview
    # checks these virtual resources: collections, providers, evaluations).
    # ==========================================================================
    info "Applying EvalHub RBAC for workshop-sa..."
    oc apply -f - >/dev/null <<RBACEOF
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: workshop-sa-evalhub-collections
  namespace: ${WORKSHOP_NAMESPACE}
  labels:
    workshop: icad2026
subjects:
- kind: ServiceAccount
  name: workshop-sa
  namespace: ${WORKSHOP_NAMESPACE}
roleRef:
  kind: ClusterRole
  name: trustyai-service-operator-evalhub-collections-access
  apiGroup: rbac.authorization.k8s.io
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: workshop-sa-evalhub-providers
  namespace: ${WORKSHOP_NAMESPACE}
  labels:
    workshop: icad2026
subjects:
- kind: ServiceAccount
  name: workshop-sa
  namespace: ${WORKSHOP_NAMESPACE}
roleRef:
  kind: ClusterRole
  name: trustyai-service-operator-evalhub-providers-access
  apiGroup: rbac.authorization.k8s.io
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: workshop-sa-lmeval-user
  namespace: ${WORKSHOP_NAMESPACE}
  labels:
    workshop: icad2026
subjects:
- kind: ServiceAccount
  name: workshop-sa
  namespace: ${WORKSHOP_NAMESPACE}
roleRef:
  kind: ClusterRole
  name: trustyai-service-operator-lmeval-user-role
  apiGroup: rbac.authorization.k8s.io
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: workshop-evalhub-evaluations-access
  namespace: ${WORKSHOP_NAMESPACE}
  labels:
    workshop: icad2026
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
  labels:
    workshop: icad2026
subjects:
- kind: ServiceAccount
  name: workshop-sa
  namespace: ${WORKSHOP_NAMESPACE}
roleRef:
  kind: Role
  name: workshop-evalhub-evaluations-access
  apiGroup: rbac.authorization.k8s.io
RBACEOF
    ok "EvalHub RBAC applied."

    # Store cluster endpoint for Section 04 (do NOT reconfigure CLI — keep it on localhost for now)
    export EVALHUB_CLUSTER_ENDPOINT="https://${EVALHUB_ROUTE}"
    grep -v "^export EVALHUB_CLUSTER_ENDPOINT" "${WORKSHOP_ENV_FILE}" > /tmp/wenv_tmp && mv /tmp/wenv_tmp "${WORKSHOP_ENV_FILE}"
    echo "export EVALHUB_CLUSTER_ENDPOINT=\"https://${EVALHUB_ROUTE}\"" >> "${WORKSHOP_ENV_FILE}"
    ok "Cluster EvalHub endpoint stored: https://${EVALHUB_ROUTE}"
    info "CLI stays pointed at local server for Sections 01-03. Section 04 switches to cluster."

    if evalhub health 2>/dev/null | grep -qi "healthy\|ok"; then
      ok "EvalHub is healthy."
      DASHBOARD_ROUTE=$(oc get route rhods-dashboard -n redhat-ods-applications \
        -o jsonpath='{.spec.host}' 2>/dev/null || echo "")
      echo ""
      echo "  EvalHub API: https://${EVALHUB_ROUTE}"
      [[ -n "${DASHBOARD_ROUTE}" ]] && echo "  RHOAI Dashboard: https://${DASHBOARD_ROUTE}"
    else
      warn "EvalHub health check failed. Run 'evalhub health' to diagnose."
    fi
  else
    warn "Could not find workshop-evalhub route in namespace ${WORKSHOP_NAMESPACE}."
  fi
fi

# =============================================================================
# Done
# =============================================================================
echo ""
echo "============================================================"
echo "  Section 01 setup complete."
echo ""
echo "  Local EvalHub server running at: http://localhost:${EVALHUB_LOCAL_PORT}"
echo "  Providers: lm_evaluation_harness, garak"
echo ""
echo "  Next: source .workshop-env && cd ../02-local-evaluation"
echo "============================================================"

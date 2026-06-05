########################################################################
# WORKSHOP ENV VARS
TENANT_NS="tenant1"
TENANT_USER="tenant1"
########################################################################
oc apply -f - <<EOF
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: evalhub-evaluator
  namespace: ${TENANT_NS}
rules:
  - apiGroups: ["trustyai.opendatahub.io"]
    resources: ["evaluations", "collections", "providers"]
    verbs: ["get", "list", "create", "update", "delete"]
  - apiGroups: ["mlflow.kubeflow.org"]
    resources: ["experiments"]
    verbs: ["create", "get"]
  - apiGroups: ["trustyai.opendatahub.io"]
    resources: ["lmevaljobs", "lmevaljobs/status"]
    verbs: ["get", "list", "watch"]
  - apiGroups: ["mlflow.kubeflow.org"]
    resources: ["experiments"]
    verbs: ["create", "get"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: my-sa-evalhub-access
  namespace: ${TENANT_NS}
subjects:
  - kind: ServiceAccount
    name: my-sa
    namespace: ${TENANT_NS}
roleRef:
  kind: Role
  name: evalhub-evaluator
  apiGroup: rbac.authorization.k8s.io
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: user-evalhub-access
  namespace: ${TENANT_NS}
subjects:
  - kind: User
    name: ${TENANT_USER}
roleRef:
  kind: Role
  name: evalhub-evaluator
  apiGroup: rbac.authorization.k8s.io
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: team-evalhub-access
  namespace: ${TENANT_NS}
subjects:
  - kind: Group
    name: evalhub-users
roleRef:
  kind: Role
  name: evalhub-evaluator
  apiGroup: rbac.authorization.k8s.io
---
EOF

# Note: When running outside `redhat-ods-applications`
# The BFF's dashboardNamespace is redhat-ods-applications 
# (detected from the pod's service account namespace file at runtime).
# This means users need one more binding:
oc apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: evalhub-cr-reader
  namespace: redhat-ods-applications   # BFF's namespace — where it lists EvalHub CRs
rules:
- apiGroups: ["trustyai.opendatahub.io"]
  resources: ["evalhubs"]
  verbs: ["get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: ${TENANT_USER}-evalhub-cr-reader
  namespace: redhat-ods-applications
subjects:
- kind: User
  name: ${TENANT_USER}
  apiGroup: rbac.authorization.k8s.io
# repeat for Group and ServiceAccount as needed
roleRef:
  kind: Role
  name: evalhub-cr-reader
  apiGroup: rbac.authorization.k8s.io
EOF

# Quick check to confirm this is the missing piece:
# Test whether the user's token can list EvalHub CRs in the BFF namespace
oc auth can-i list evalhubs.trustyai.opendatahub.io \
  -n redhat-ods-applications \
  --as ${TENANT_USER}
# Should return "yes" after applying the binding above


# The BFF gates UI access on get evaluations.trustyai.opendatahub.io in the user's namespace. 
# The operator creates this ClusterRole but does not bind it to users automatically.
# What is actually need for UI access is just this:

oc apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: ${TENANT_USER}-evalhub-access
  namespace: ${TENANT_NS}
subjects:
- kind: User
  name: ${TENANT_USER}
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: evalhub-evaluator        # the single Role covering everything
  apiGroup: rbac.authorization.k8s.io
EOF

# If the BFF does not have EVAL_HUB_URL set (env var override), it discovers the EvalHub service URL at runtime
# by listing evalhubs.trustyai.opendatahub.io CRs in the dashboard namespace using the user's token.
# In that case users also need:
oc apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: ${TENANT_USER}-evalhub-cr-read
  namespace: redhat-ods-applications    # BFF's dashboard namespace
subjects:
- kind: User
  name: ${TENANT_USER}
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: trustyai-service-operator-evalhub-collections-access   # grants get on evalhubs
  apiGroup: rbac.authorization.k8s.io

Actually, that ClusterRole doesn't include evalhubs. You'd need:

apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: evalhub-cr-reader
  namespace: redhat-ods-applications
rules:
- apiGroups: ["trustyai.opendatahub.io"]
  resources: ["evalhubs"]
  verbs: ["get", "list"]
EOF

# NOTE:
# Beyond RBAC, there are two non-RBAC prerequisites that will prevent jobs from running even with correct RBAC
#
# 1. Namespace label for operator-provisioned job RBAC:
# oc label namespace ${TENANT_NS} evalhub.trustyai.opendatahub.io/tenant=true
# Without this, the operator never creates the job ServiceAccount and its RoleBindings in the tenant namespace.
# LMEvalJob pods will start but fail to call back to the EvalHub server.
#
# 2. Namespace label for RHOAI Dashboard visibility:
# oc label namespace ${TENANT_NS} opendatahub.io/dashboard=true
# Without this, the namespace does not appear in the UI's namespace selector.
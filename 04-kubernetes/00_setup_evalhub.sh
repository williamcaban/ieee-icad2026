##
# Setup CLI
##
# Install EvalHub client Python SDK & CLI
uv add "eval-hub-sdk[client]" "eval-hub-sdk[client]"

# Install OpenShift CLI (Kubernetes distribution)
brew install openshift-cli

########################################################################
# WORKSHOP ENV VARS
WORKSHOP_NS="workshop"
TENANT_NS="tenant1"
########################################################################

##
# Setup MLflow service
##
# Enable the MLFlow Operator
oc patch datasciencecluster default-dsc \
  --type=merge \
  -p '{"spec":{"components":{"mlflowoperator":{"managementState":"Managed"}}}}'

# Create MLflow instance
oc apply -f - <<EOF
apiVersion: mlflow.opendatahub.io/v1
kind: MLflow
metadata:
  name: mlflow
  namespace: redhat-ods-applications
spec:
  storage:
    accessModes:
      - ReadWriteOnce
    resources:
      requests:
        storage: 10Gi
  backendStoreUri: "sqlite:////mlflow/mlflow.db"
  artifactsDestination: "file:///mlflow/artifacts"
  serveArtifacts: true
EOF

##
# Setup EvalHub multi-tenant mode
##
# create namespace for evalhub multi-tenant instance
oc create namespace ${WORKSHOP_NS}

# required labels
oc label namespace ${WORKSHOP_NS} \
  opendatahub.io/dashboard=true \
  evalhub.trustyai.io/managed=true

# Deploy EvalHub instance 
oc apply -f - <<EOF
apiVersion: trustyai.opendatahub.io/v1alpha1
kind: EvalHub
metadata:
  name: evalhub
  namespace: ${WORKSHOP_NS}
spec:
  replicas: 1
  database:
    type: sqlite
  providers:
    - lm-evaluation-harness
    - garak
    - garak-kfp
    - guidellm
    - lighteval
    - ibm-clear
  collections:
    - leaderboard-v2
    - safety-and-fairness-v1
    - toxicity-and-ethical-principles
  env:
    - name: MLFLOW_TRACKING_URI
      value: "https://mlflow.redhat-ods-applications.svc.cluster.local:8443"
EOF


# Confirrm EvalHub pod is running
oc get pods -l app=eval-hub -n ${WORKSHOP_NS}

# query health endpoint to validate it is running
export EVALHUB_URL="https://$(oc get routes evalhub -o jsonpath='{.spec.host}' -n ${WORKSHOP_NS})"
curl -s $EVALHUB_URL/api/v1/health | jq .


##
# Setup tenant namespace
##
# create namespace for evalhub multi-tenant instance
oc create namespace ${TENANT_NS}

# required tenant labels
oc label namespace ${TENANT_NS} \
  evalhub.trustyai.opendatahub.io/tenant=true \
  opendatahub.io/dashboard=true

# Confirm operator provisioned exepected tenant resources
oc get serviceaccount,rolebinding,configmap -n ${TENANT_NS} | grep evalhub


##
# Give Tenants Access to EvalHub
##
bash ./01_Tenants_Access_to_EvalHub.sh
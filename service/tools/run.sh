#!/bin/bash

NAMESPACE=$1
if [ -z "${NAMESPACE}" ]; then
  echo "Usage: $0 <namespace>"
  exit 1
fi

REMOTE_IMAGE="$(terraform -chdir=${PROJECT_DIR}/terraform/env/helm/prd output -raw tools_ecr)"
ROLE_ARN="$(terraform -chdir=${PROJECT_DIR}/terraform/env/helm/prd output -raw tools_role)"

mkdir -p ${PROJECT_DIR}/service/tools/tmp
cat <<EOF > ${PROJECT_DIR}/service/tools/tmp/app.yaml
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: tools
  namespace: ${NAMESPACE}
  annotations:
    eks.amazonaws.com/role-arn: ${ROLE_ARN}

---
apiVersion: v1
kind: Pod
metadata:
  name: tools
  namespace: ${NAMESPACE}
  labels:
    app: tools
spec:
  serviceAccountName: tools
  containers:
  - name: tools
    image: ${REMOTE_IMAGE}:latest
    command: ["sleep", "infinity"]
EOF

kubectl apply -f ${PROJECT_DIR}/service/tools/tmp/app.yaml
kubectl wait --for=condition=Ready -n ${NAMESPACE} pod/tools
kubectl exec -it -n ${NAMESPACE} tools -- /bin/bash
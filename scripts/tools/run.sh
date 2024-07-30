#!/bin/bash

REMOTE_IMAGE="$(terraform -chdir=${CONTAINER_PROJECT_ROOT}/terraform/env/helm/prd output -raw tools_ecr)"
ROLE_ARN="$(terraform -chdir=${CONTAINER_PROJECT_ROOT}/terraform/env/helm/prd output -raw tools_role)"

mkdir -p ${CONTAINER_PROJECT_ROOT}/scripts/tools/tmp
cat <<EOF > ${CONTAINER_PROJECT_ROOT}/scripts/tools/tmp/app.yaml
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: tools
  annotations:
    eks.amazonaws.com/role-arn: ${ROLE_ARN}

---
apiVersion: v1
kind: Pod
metadata:
  name: tools
  labels:
    app: tools
spec:
  serviceAccountName: tools
  containers:
  - name: tools
    image: ${REMOTE_IMAGE}:latest
    command: ["sleep", "infinity"]
EOF

kubectl apply -f ${CONTAINER_PROJECT_ROOT}/scripts/tools/tmp/app.yaml
kubectl wait --for=condition=Ready pod/tools
kubectl exec -it tools -- /bin/bash
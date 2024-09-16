#!/bin/bash
set -ex

# Usage - secrets-store-csi-driver-provider-aws | GitHub
# https://github.com/aws/secrets-store-csi-driver-provider-aws?tab=readme-ov-file#usage

SCRIPT_DIR=$(cd $(dirname $0); pwd)
cd $SCRIPT_DIR

APP_NAME="baseport"
STAGE_NAME="prd"
CLUSTER_NAME="${APP_NAME}-${STAGE_NAME}"
SERVICE_ACCOUNT="ascp-test"
REGION="ap-northeast-1"

SECRETS_NAME="/${APP_NAME}/${STAGE_NAME}/ascp-test"
ESC_SECRETS_NAME=$(echo $SECRETS_NAME | tr "/" "_")

SECRETS_EXISTS=$(
  aws secretsmanager list-secrets \
    --filter Key="name",Values="$SECRETS_NAME" \
    --query "SecretList[].Name" \
    --output text
)

if [ -z "$SECRETS_EXISTS" ]; then
  aws --region "$REGION" secretsmanager create-secret \
    --force-overwrite-replica-secret \
    --name $SECRETS_NAME \
    --secret-string '{"username":"hogehoge", "password":"piyopiyo"}'
fi

mkdir -p $SCRIPT_DIR/tmp

cat <<EOF | envsubst > $SCRIPT_DIR/tmp/spc_1.yaml
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: ascp-test-secrets-1
spec:
  provider: aws
  parameters:
    objects: |
        - objectName: "${SECRETS_NAME}"
          objectType: "secretsmanager"
EOF

cat <<EOF | envsubst > $SCRIPT_DIR/tmp/deployment_1.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ascp-test-deployment-1
spec:
  selector:
    matchLabels:
      app: app-1
  template:
    metadata:
      labels:
        app: app-1
    spec:
      serviceAccountName: ${SERVICE_ACCOUNT}
      containers:
      - name: ascp-test-1
        image: ubuntu
        command: ["sleep", "infinity"]
        # SecretsManagerをコンテナにマウント
        volumeMounts:
        - name: secrets-store  # volumes[].name
          mountPath: "/mnt/secrets-store"
          readOnly: true
      volumes:
      # CSIストレージ指定
      - name: secrets-store
        csi:
          driver: secrets-store.csi.k8s.io
          readOnly: true
          volumeAttributes:
            secretProviderClass: "ascp-test-secrets-1"  # SecretProviderClass で定義した metadata.name
EOF


#
# - シークレット情報をSecretオブジェクトに同期する:
#   https://developer.mamezou-tech.com/blogs/2022/07/13/secrets-store-csi-driver-intro/#%E3%82%B7%E3%83%BC%E3%82%AF%E3%83%AC%E3%83%83%E3%83%88%E6%83%85%E5%A0%B1%E3%82%92secret%E3%82%AA%E3%83%96%E3%82%B8%E3%82%A7%E3%82%AF%E3%83%88%E3%81%AB%E5%90%8C%E6%9C%9F%E3%81%99%E3%82%8B
# - Sync as Kubernetes Secret | Secrets Store CSI Driver
#   https://secrets-store-csi-driver.sigs.k8s.io/topics/sync-as-kubernetes-secret.html
#
cat <<EOF | envsubst > $SCRIPT_DIR/tmp/spc_2.yaml
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: ascp-test-secrets-2
spec:
  provider: aws
  secretObjects:
    - secretName: ascp-test-secrets-2-k8s-secret
      type: Opaque
      data:
        - key: db_secret
          objectName: ${ESC_SECRETS_NAME}
  parameters:
    objects: |
        - objectName: "${SECRETS_NAME}"
          objectType: "secretsmanager"
EOF

cat <<EOF | envsubst > $SCRIPT_DIR/tmp/deployment_2.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ascp-test-deployment-2
spec:
  selector:
    matchLabels:
      app: app-2
  template:
    metadata:
      labels:
        app: app-2
    spec:
      serviceAccountName: ${SERVICE_ACCOUNT}
      containers:
      - name: ascp-test-deployment
        image: ubuntu
        command: ["sleep", "infinity"]
        env:
        - name: DB_SECRET
          valueFrom:
            secretKeyRef:
              name: ascp-test-secrets-2-k8s-secret  # Secretオブジェクト名
              key: db_secret
# ※ Secretオブジェクトをディレクトリにマウントさせたい場合は、以下のようにvolumeMountsとvolumesを定義する
#        volumeMounts:
#          - name: csi-secret
#            mountPath: /mnt/secrets-store
#            readOnly: true
#          # k8s Secretオブジェクトからマウント
#          - name: k8s-secret
#            mountPath: /k8s-secret
#            readOnly: true
#      volumes:
#        # CSIストレージ指定
#        - name: csi-secret
#          csi:
#            driver: secrets-store.csi.k8s.io
#            readOnly: true
#            volumeAttributes:
#              secretProviderClass: ascp-test-secrets-2
#        # SecretオブジェクトのVolume定義
#        - name: k8s-secret
#          secret:
#            secretName: ascp-test-secrets-2-k8s-secret
EOF
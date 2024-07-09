#!/bin/bash
set -ex

SCRIPT_DIR=$(cd $(dirname $0); pwd)
cd $SCRIPT_DIR

EFS_ID="$(terraform -chdir=${CONTAINER_PROJECT_ROOT}/terraform/env/cluster/prd output -raw efs_id)"
mkdir -p $SCRIPT_DIR/tmp

# Amazon EFS CSI dynamic provisioningの御紹介 | Amazon Web Services ブログ
# https://aws.amazon.com/jp/blogs/news/amazon-efs-csi-dynamic-provisioning/
cat <<EOF | envsubst > $SCRIPT_DIR/tmp/sc.yaml
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: efs-sc
provisioner: efs.csi.aws.com
parameters:
  # パラメータ
  # https://github.com/kubernetes-sigs/aws-efs-csi-driver?tab=readme-ov-file#storage-class-parameters-for-dynamic-provisioning
  provisioningMode: efs-ap
  fileSystemId: ${EFS_ID}
  directoryPerms: "700"
EOF

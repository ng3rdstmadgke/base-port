#!/bin/bash
set -ex

SCRIPT_DIR=$(cd $(dirname $0); pwd)
cd $SCRIPT_DIR

EFS_ID="$(terraform -chdir=${CONTAINER_PROJECT_ROOT}/terraform/env/prd/cluster output -raw efs_id)"
mkdir -p $SCRIPT_DIR/tmp

# Amazon EFS CSI dynamic provisioningの御紹介 | Amazon Web Services ブログ
# https://aws.amazon.com/jp/blogs/news/amazon-efs-csi-dynamic-provisioning/
cat <<EOF > $SCRIPT_DIR/tmp/sc.yaml
# https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.30/#storageclass-v1-storage-k8s-io
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
  # 動的プロビジョニング作成されるアクセスポイントのパス
  basePath: "/dynamic_provisioning"  # optional
  # 動的プロビジョニングで作成される各アクセスポイントのサブパス
  subPathPattern: "\${.PVC.namespace}/\${.PVC.name}"  # optional
  # 動的プロビジョニングで作成される各アクセスポイントのサブパスにUIDを追加する (重複回避)
  # trueだとマウントパスは /dynamic_provisioning/pvcネームスペース名/pvc名-f9ab375a-4da3-4c4a-a748-391a6da20a91 となる
  # falseだとマウントパスは /dynamic_provisioning/pvcネームスペース名/pvc名 となる
  ensureUniqueDirectory: "false" # PVCのネームスペース名とPVC名が同じなら毎回同じパスをマウントするようにする
  # アクセスポイントの再利用
  reuseAccessPoint: "false" # optional

EOF

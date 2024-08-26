#!/bin/bash
set -ex

SCRIPT_DIR=$(cd $(dirname $0); pwd)
cd $SCRIPT_DIR

STAGE_NAME="prd"
TERRAFORM_DIR="${CONTAINER_PROJECT_ROOT}/terraform/env/$STAGE_NAME"
CLUSTER_NAME=$( terraform -chdir=$TERRAFORM_DIR/cluster output -raw eks_cluster_name)

#
# Karpenterで利用するサブネットにタグ付け
#
PRIVATE_SUBNET_IDS=$(terraform -chdir=${TERRAFORM_DIR}/cluster output -json private_subnets | jq -r ".[]")

for subnet_id in $PRIVATE_SUBNET_IDS; do
  echo "[subnet] $subnet_id"
  aws ec2 create-tags \
    --resources $subnet_id \
    --tags "Key=karpenter.sh/discovery,Value=${CLUSTER_NAME}"
done

#
# Karpenterで利用するSecurity Groupにタグ付け
#

# クラスタプライマリセキュリティグループ
CLUSTER_PRIMARY_SECURITY_GROUP_ID=$(terraform -chdir=${TERRAFORM_DIR}/cluster output -raw eks_cluster_primary_sg_id)
echo "[cluster primary security-group] $CLUSTER_PRIMARY_SECURITY_GROUP_ID"
aws ec2 create-tags \
  --resources $CLUSTER_PRIMARY_SECURITY_GROUP_ID \
  --tags "Key=karpenter.sh/discovery,Value=${CLUSTER_NAME}"


# クラスタセキュリティグループ
CLUSTER_SECURITY_GROUP_IDS=$(terraform -chdir=${TERRAFORM_DIR}/cluster output  -json eks_cluster_sg_ids | jq -r ".[]")

if [ -n "$CLUSTER_SECURITY_GROUP_IDS" ]; then
  for CLUSTER_SECURITY_GROUP_ID in $CLUSTER_SECURITY_GROUP_IDS; do
    echo "[cluster security-group] $CLUSTER_SECURITY_GROUP_ID"
    aws ec2 create-tags \
      --resources $CLUSTER_SECURITY_GROUP_ID \
      --tags "Key=karpenter.sh/discovery,Value=${CLUSTER_NAME}"
  done
fi


#
# NodePools と NodeClasses の設定ファイルを作成
#
mkdir -p $SCRIPT_DIR/tmp
CLUSTER_VERSION=$(terraform -chdir=${TERRAFORM_DIR}/cluster output -raw eks_cluster_version)
KARPENTER_NODE_ROLE_NAME=$(terraform -chdir=${TERRAFORM_DIR}/helm output -raw karpenter_node_role_name)

#
# default の NodePools と NodeClasses の設定ファイルを作成
#
# NodeClasses | Karpenter: https://karpenter.sh/docs/concepts/nodeclasses/
cat <<EOF > $SCRIPT_DIR/tmp/nodeclass_default.yaml
---
apiVersion: karpenter.k8s.aws/v1beta1
kind: EC2NodeClass
metadata:
  name: default
spec:
  amiFamily: AL2 # AL2023  # Amazon Linux 2023
  role: "${KARPENTER_NODE_ROLE_NAME}" # replace with your cluster name
  subnetSelectorTerms:
    - tags:
        karpenter.sh/discovery: "${CLUSTER_NAME}" # replace with your cluster name
  securityGroupSelectorTerms:
    - tags:
        karpenter.sh/discovery: "${CLUSTER_NAME}" # replace with your cluster name
  amiSelectorTerms:
    #- id: "AMI_ID"
    - name: "amazon-eks-node-${CLUSTER_VERSION}-*" # <- 新しい AL2 EKS Optimized AMI リリース時に自動的にアップデートされる。安全ではないので本番環境では注意.
  blockDeviceMappings:
    - deviceName: /dev/xvda
      ebs:
        volumeSize: 64Gi
        volumeType: gp3
        iops: 3000
        encrypted: false
        deleteOnTermination: true
        throughput: 125
  userData: |
    MIME-Version: 1.0
    Content-Type: multipart/mixed; boundary="==BOUNDARY=="

    --==BOUNDARY==
    Content-Type:text/x-shellscript; charset="us-ascii"

    #!/bin/bash
    set -e
    echo "KARPENTER: Starting user data script"

    --==BOUNDARY==--
EOF

# NodePools | Karpenter: https://karpenter.sh/docs/concepts/nodepools/
#   - instance-types | Karpenter: https://karpenter.sh/docs/reference/instance-types/
cat <<EOF > $SCRIPT_DIR/tmp/nodepool_default.yaml
---
apiVersion: karpenter.sh/v1beta1
kind: NodePool
metadata:
  name: default
spec:
  template:
    spec:
      requirements:
        - key: kubernetes.io/arch
          operator: In
          values: ["amd64"]
        - key: kubernetes.io/os
          operator: In
          values: ["linux"]
        - key: karpenter.sh/capacity-type
          operator: In
          values: ["spot"]
        - key: karpenter.k8s.aws/instance-family
          operator: In
          values: ["t3", "t3a", "m5", "m5a", "m6i", "m6a", "m7i", "m7a"]
        - key: "karpenter.k8s.aws/instance-cpu"
          operator: In
          values: ["2", "4"]
      nodeClassRef:
        apiVersion: karpenter.k8s.aws/v1
        kind: EC2NodeClass
        name: default
  limits:
    cpu: 20
  disruption:
    consolidationPolicy: WhenUnderutilized
    expireAfter: 720h # 30 * 24h = 720h
EOF

#
# GPU NodePools と NodeClasses の設定ファイルを作成
#
cat <<EOF > $SCRIPT_DIR/tmp/nodeclass_gpu.yaml
---
apiVersion: karpenter.k8s.aws/v1beta1
kind: EC2NodeClass
metadata:
  name: gpu
spec:
  amiFamily: AL2 # AL2023  # Amazon Linux 2023
  role: "${KARPENTER_NODE_ROLE_NAME}" # replace with your cluster name
  subnetSelectorTerms:
    - tags:
        karpenter.sh/discovery: "${CLUSTER_NAME}" # replace with your cluster name
  securityGroupSelectorTerms:
    - tags:
        karpenter.sh/discovery: "${CLUSTER_NAME}" # replace with your cluster name
  amiSelectorTerms:
    #- id: "AMI_ID"
    - name: "amazon-eks-gpu-node-${CLUSTER_VERSION}-*" # <- 新しい AL2 EKS Optimized AMI リリース時に自動的にアップデートされる。安全ではないので本番環境では注意.
  blockDeviceMappings:
    - deviceName: /dev/xvda
      ebs:
        volumeSize: 64Gi
        volumeType: gp3
        iops: 3000
        encrypted: false
        deleteOnTermination: true
        throughput: 125
  userData: |
    MIME-Version: 1.0
    Content-Type: multipart/mixed; boundary="==BOUNDARY=="

    --==BOUNDARY==
    Content-Type:text/x-shellscript; charset="us-ascii"

    #!/bin/bash
    set -e
    echo "KARPENTER: Starting user data script"

    --==BOUNDARY==--
EOF
# g4dn Family: https://karpenter.sh/docs/reference/instance-types/#g4dn-family
cat <<EOF > $SCRIPT_DIR/tmp/nodepool_gpu.yaml
---
apiVersion: karpenter.sh/v1beta1
kind: NodePool
metadata:
  name: gpu-01
spec:
  template:
    spec:
      requirements:
        - key: kubernetes.io/arch
          operator: In
          values: ["amd64"]
        - key: kubernetes.io/os
          operator: In
          values: ["linux"]
        - key: karpenter.sh/capacity-type
          operator: In
          values: ["spot"]
        - key: karpenter.k8s.aws/instance-family
          operator: In
          # g4dn: nvidia, g4ad: amd, g5g: nvidia
          values: ["g4dn", "g5"]
        - key: "karpenter.k8s.aws/instance-cpu"
          operator: In
          values: ["4", "8"]
      nodeClassRef:
        apiVersion: karpenter.k8s.aws/v1
        kind: EC2NodeClass
        name: gpu
      taints:
        - key: nvidia.com/gpu
          value: "true"
          effect: "NoSchedule"
  limits:
    cpu: 20
  disruption:
    consolidationPolicy: WhenUnderutilized
    expireAfter: 720h # 30 * 24h = 720h
EOF
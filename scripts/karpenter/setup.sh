#!/bin/bash
set -ex

SCRIPT_DIR=$(cd $(dirname $0); pwd)
cd $SCRIPT_DIR

export APP_NAME="baseport"
export STAGE_NAME="prd"
export CLUSTER_NAME="${APP_NAME}-${STAGE_NAME}"
export KARPENTER_NODE_ROLE="${CLUSTER_NAME}-KarpenterNodeRole"
export K8S_VERSION="1.30"


#
# Karpenterで利用するサブネットにタグ付け
#
PRIVATE_SUBNET_IDS=$(
  aws eks describe-cluster \
    --name ${CLUSTER_NAME} \
    --query "cluster.resourcesVpcConfig.subnetIds" \
    --output text
)

for subnet_id in $PRIVATE_SUBNET_IDS; do
  echo "[subnet] $subnet_id"
  aws ec2 create-tags \
    --resources $subnet_id \
    --tags "Key=karpenter.sh/discovery,Value=${CLUSTER_NAME}"
done

#
# Karpenterで利用するSecurity Groupにタグ付け
#

# クラスタセキュリティグループ
CLUSTER_SECURITY_GROUP_ID=$(
  aws eks describe-cluster \
    --name $CLUSTER_NAME \
    --query "cluster.resourcesVpcConfig.clusterSecurityGroupId" \
    --output text
)
aws ec2 create-tags \
  --resources $CLUSTER_SECURITY_GROUP_ID \
  --tags "Key=karpenter.sh/discovery,Value=${CLUSTER_NAME}"

# 追加のノードセキュリティグループ
NODE_ADDITIONAL_SECURITY_GROUP_NAME="${CLUSTER_NAME}-AdditionalNodeSecurityGroup"
NODE_ADDITIONAL_SECURITY_GROUP_ID=$(
  aws ec2 describe-security-groups \
    --filters "Name=tag:Name,Values=$NODE_ADDITIONAL_SECURITY_GROUP_NAME" \
    --query "SecurityGroups[].GroupId" \
    --output text
)
aws ec2 create-tags \
  --resources ${NODE_ADDITIONAL_SECURITY_GROUP_ID} \
  --tags "Key=karpenter.sh/discovery,Value=${CLUSTER_NAME}"


mkdir -p $SCRIPT_DIR/tmp

# NodePools | Karpenter: https://karpenter.sh/docs/concepts/nodepools/
#   - instance-types | Karpenter: https://karpenter.sh/docs/reference/instance-types/
# NodeClasses | Karpenter: https://karpenter.sh/docs/concepts/nodeclasses/
cat <<EOF | envsubst > $SCRIPT_DIR/tmp/node_pool.yaml
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
        #- key: "karpenter.k8s.aws/instance-memory"
        #  operator: In
        #  values: ["4096", "8192", "16384"]
      nodeClassRef:
        apiVersion: karpenter.k8s.aws/v1beta1
        kind: EC2NodeClass
        name: default
  limits:
    cpu: 20
  disruption:
    consolidationPolicy: WhenUnderutilized
    expireAfter: 720h # 30 * 24h = 720h
---
apiVersion: karpenter.k8s.aws/v1beta1
kind: EC2NodeClass
metadata:
  name: default
spec:
  amiFamily: AL2 # Amazon Linux 2
  role: "${KARPENTER_NODE_ROLE}" # replace with your cluster name
  subnetSelectorTerms:
    - tags:
        karpenter.sh/discovery: "${CLUSTER_NAME}" # replace with your cluster name
  securityGroupSelectorTerms:
    - tags:
        karpenter.sh/discovery: "${CLUSTER_NAME}" # replace with your cluster name
  amiSelectorTerms:
    #- id: "AMI_ID"
    - name: "amazon-eks-node-${K8S_VERSION}-*" # <- 新しい AL2 EKS Optimized AMI リリース時に自動的にアップデートされる。安全ではないので本番環境では注意.
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
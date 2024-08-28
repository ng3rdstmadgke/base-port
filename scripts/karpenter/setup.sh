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
CLUSTER_ENDPOINT=$(terraform -chdir=${TERRAFORM_DIR}/cluster output -raw eks_cluster_endpoint)
CLUSTER_CERTIFICATE_AUTHORITY_DATA=$(terraform -chdir=${TERRAFORM_DIR}/cluster output -raw eks_cluster_certificate_authority_data)
CLUSTER_SERVICE_CIDR=$(terraform -chdir=${TERRAFORM_DIR}/cluster output -raw eks_cluster_service_cidr)
KARPENTER_NODE_ROLE_NAME=$(terraform -chdir=${TERRAFORM_DIR}/helm output -raw karpenter_node_role_name)


#
# default の NodePools と NodeClasses の設定ファイルを作成
#
# NodeClasses | Karpenter: https://karpenter.sh/v0.37/concepts/nodeclasses/
cat <<EOF > $SCRIPT_DIR/tmp/nodeclass_default.yaml
---
apiVersion: karpenter.k8s.aws/v1beta1
kind: EC2NodeClass
metadata:
  name: default
spec:
  amiFamily: AL2023
  role: "${KARPENTER_NODE_ROLE_NAME}" # replace with your cluster name
  subnetSelectorTerms:
    - tags:
        karpenter.sh/discovery: "${CLUSTER_NAME}" # replace with your cluster name
  securityGroupSelectorTerms:
    - tags:
        karpenter.sh/discovery: "${CLUSTER_NAME}" # replace with your cluster name
  amiSelectorTerms:
    #- id: "AMI_ID"
    # amazon-eks-ami リリース: https://github.com/awslabs/amazon-eks-ami/releases
    - name: "amazon-eks-node-al2023-x86_64-standard-${CLUSTER_VERSION}-*" # <- 新しい AL2 EKS Optimized AMI リリース時に自動的にアップデートされる。安全ではないので本番環境では注意.

  # https://karpenter.sh/v0.37/concepts/nodeclasses/#al2023-1
  blockDeviceMappings:
    - deviceName: /dev/xvda
      ebs:
        volumeSize: 64Gi
        volumeType: gp3
        iops: 3000
        encrypted: true
        deleteOnTermination: true
        throughput: 125

  # https://karpenter.sh/v0.37/concepts/nodeclasses/#al2023-3
  # NodeConfigのリファレンス: https://awslabs.github.io/amazon-eks-ami/nodeadm/doc/api/
  # NodeConfigの設定例: https://awslabs.github.io/amazon-eks-ami/nodeadm/doc/examples/
  userData: |
    MIME-Version: 1.0
    Content-Type: multipart/mixed; boundary="BOUNDARY"
  
    --BOUNDARY
    Content-Type: application/node.eks.aws
  
    ---
    apiVersion: node.eks.aws/v1alpha1
    kind: NodeConfig
    spec:
      cluster:
        name: ${CLUSTER_NAME}
        apiServerEndpoint: ${CLUSTER_ENDPOINT}
        certificateAuthority: ${CLUSTER_CERTIFICATE_AUTHORITY_DATA}
        cidr: ${CLUSTER_SERVICE_CIDR}
  
    --BOUNDARY
    Content-Type: text/x-shellscript; charset="us-ascii"
  
    #!/bin/bash
    echo "Hello, AL2023!"
    --BOUNDARY--
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
        apiVersion: karpenter.k8s.aws/v1beta1
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
# amazon-eks-ami リリース: https://github.com/awslabs/amazon-eks-ami/releases
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
    # amazon-eks-ami リリース: https://github.com/awslabs/amazon-eks-ami/releases
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
  name: gpu-nvidia
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
          values: ["g4dn"]
        - key: "karpenter.k8s.aws/instance-cpu"
          operator: In
          values: ["4"]
      nodeClassRef:
        apiVersion: karpenter.k8s.aws/v1beta1
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
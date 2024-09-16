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
rm -r $SCRIPT_DIR/tmp
mkdir -p $SCRIPT_DIR/tmp
CLUSTER_VERSION=$(terraform -chdir=${TERRAFORM_DIR}/cluster output -raw eks_cluster_version)
CLUSTER_ENDPOINT=$(terraform -chdir=${TERRAFORM_DIR}/cluster output -raw eks_cluster_endpoint)
CLUSTER_CERTIFICATE_AUTHORITY_DATA=$(terraform -chdir=${TERRAFORM_DIR}/cluster output -raw eks_cluster_certificate_authority_data)
CLUSTER_SERVICE_CIDR=$(terraform -chdir=${TERRAFORM_DIR}/cluster output -raw eks_cluster_service_cidr)
KARPENTER_NODE_ROLE_NAME=$(terraform -chdir=${TERRAFORM_DIR}/helm output -raw karpenter_node_role_name)


#
# AL2023, x86-64
#
# NodeClasses | Karpenter: https://karpenter.sh/v0.37/concepts/nodeclasses/
cat <<EOF > $SCRIPT_DIR/tmp/nodeclass-al2023-x86-64.yaml
---
apiVersion: karpenter.k8s.aws/v1
kind: EC2NodeClass
metadata:
  name: al2023-x86-64
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
cat <<EOF > $SCRIPT_DIR/tmp/nodepool-al2023-x86-64-standard.yaml
---
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: al2023-x86-64-standard
spec:
  template:
    metadata:
      labels:
        karpenter.baseport.net/nodeclass: al2023-x86-64
    spec:
      terminationGracePeriod: 24h  # ノードが強制削除される前にdrainできる最大時間
      expireAfter: 720h  # クラスタにノードが存在できる最長時間 (ノードの長期間の稼動による問題(メモリリークなど)のリスクを低減する)
      requirements:
        - key: kubernetes.io/arch
          operator: In
          values: ["amd64"]
        - key: kubernetes.io/os
          operator: In
          values: ["linux"]
        - key: karpenter.sh/capacity-type
          operator: In
          values: ["spot"]  # spot or on-demand
        - key: karpenter.k8s.aws/instance-family
          operator: In
          values: ["t3", "t3a", "m5", "m5a", "m6i", "m6a", "m7i", "m7a"]
        - key: "karpenter.k8s.aws/instance-cpu"
          operator: In
          values: ["2", "4"]
      nodeClassRef:
        group: karpenter.k8s.aws
        kind: EC2NodeClass
        name: al2023-x86-64
  limits:
    cpu: 20
  disruption:
    # 統合のために考慮すべきノードの種類
    # WhenEmptyOrUnderutilized: すべてのノードを統合の対象とし、ノードが十分に活用されておらず、コスト削減のために変更できると判断した場合にノードを削除・置換しようとする
    # WhenEmpty: ワークロードポッドを含まないノードのみを統合の対象とする
    consolidationPolicy: WhenEmptyOrUnderutilized

    # Podがノードに追加または削除された後、Karpenterがノードを統合するまでの待機時間。
    consolidateAfter: 1m
EOF

#
# AL2, x86-64, NVIDIA
#
# Amazon EKS 最適化高速 Amazon Linux AMI: https://docs.aws.amazon.com/ja_jp/eks/latest/userguide/eks-optimized-ami.html#gpu-ami
# amazon-eks-ami リリース: https://github.com/awslabs/amazon-eks-ami/releases
#
cat <<EOF > $SCRIPT_DIR/tmp/nodeclass-al2-x86-64-nvidia.yaml
---
apiVersion: karpenter.k8s.aws/v1
kind: EC2NodeClass
metadata:
  name: al2-x86-64-nvidia
spec:
  # GPUはAL2とBottlerocketでのみサポートされる
  amiFamily: AL2
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
  # EKS起動テンプレート: https://docs.aws.amazon.com/ja_jp/eks/latest/userguide/launch-templates.html#launch-template-custom-ami
  #                     https://karpenter.sh/v0.37/concepts/nodeclasses/#al2ubuntu
  # bootstrap.sh のソースコード: https://github.com/awslabs/amazon-eks-ami/blob/main/templates/al2/runtime/bootstrap.sh
  userData: |
    MIME-Version: 1.0
    Content-Type: multipart/mixed; boundary="==BOUNDARY=="

    --==BOUNDARY==
    Content-Type:text/x-shellscript; charset="us-ascii"

    exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
    #!/bin/bash -xe
    /etc/eks/bootstrap.sh '${CLUSTER_NAME}' \
      --apiserver-endpoint '${CLUSTER_ENDPOINT}' \
      --b64-cluster-ca '${CLUSTER_CERTIFICATE_AUTHORITY_DATA}'

    echo "KARPENTER: Starting user data script"
    --==BOUNDARY==--
EOF
# g4dn Family: https://karpenter.sh/docs/reference/instance-types/#g4dn-family
cat <<EOF > $SCRIPT_DIR/tmp/nodepool-al2-x86-64-nvidia.yaml
---
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: al2-x86-64-nvidia-standard
spec:
  template:
    metadata:
      labels:
        karpenter.baseport.net/nodeclass: al2-x86-64-nvidia
    spec:
      terminationGracePeriod: 24h  # ノードが強制削除される前にdrainできる最大時間
      expireAfter: 720h  # クラスタにノードが存在できる最長時間 (ノードの長期間の稼動による問題(メモリリークなど)のリスクを低減する)
      requirements:
        - key: kubernetes.io/arch
          operator: In
          values: ["amd64"]
        - key: kubernetes.io/os
          operator: In
          values: ["linux"]
        - key: karpenter.sh/capacity-type
          operator: In
          values: ["spot"]  # spot or on-demand
        - key: karpenter.k8s.aws/instance-family
          operator: In
          values: ["g4dn"]
        - key: "karpenter.k8s.aws/instance-cpu"
          operator: In
          values: ["4"]
      nodeClassRef:
        group: karpenter.k8s.aws
        kind: EC2NodeClass
        name: al2-x86-64-nvidia
      # nvidia-device-pluginデーモンセットを起動しなければならないため "nvidia.com/gpu" 以外のtaintの付与には注意
      # nvidia-device-pluginデーモンセットのtoleration: https://github.com/NVIDIA/k8s-device-plugin/blob/v0.16.2/deployments/helm/nvidia-device-plugin/values.yaml#L85
      taints:
        - key: nvidia.com/gpu
          value: "true"
          effect: "NoSchedule"
  limits:
    cpu: 20
  disruption:
    # 統合のために考慮すべきノードの種類
    # WhenEmptyOrUnderutilized: すべてのノードを統合の対象とし、ノードが十分に活用されておらず、コスト削減のために変更できると判断した場合にノードを削除・置換しようとする
    # WhenEmpty: ワークロードポッドを含まないノードのみを統合の対象とする
    consolidationPolicy: WhenEmptyOrUnderutilized

    # Podがノードに追加または削除された後、Karpenterがノードを統合するまでの待機時間。
    consolidateAfter: 1m
EOF

#
# bottlerocket, x86-64
#
# NodeClasses | Karpenter: https://karpenter.sh/v0.37/concepts/nodeclasses/
# bottlerocket | Github: https://github.com/bottlerocket-os/bottlerocket
# bottlerocket Settings: https://bottlerocket.dev/en/os/1.20.x/api/settings-index/
cat <<EOF > $SCRIPT_DIR/tmp/nodeclass-bottlerocket-x86-64.yaml
---
apiVersion: karpenter.k8s.aws/v1
kind: EC2NodeClass
metadata:
  name: bottlerocket-x86-64
spec:
  amiFamily: Bottlerocket
  role: "${KARPENTER_NODE_ROLE_NAME}" # replace with your cluster name
  subnetSelectorTerms:
    - tags:
        karpenter.sh/discovery: "${CLUSTER_NAME}" # replace with your cluster name
  securityGroupSelectorTerms:
    - tags:
        karpenter.sh/discovery: "${CLUSTER_NAME}" # replace with your cluster name
  amiSelectorTerms:
    #- id: "AMI_ID"
    # bottlerocketのami: https://github.com/bottlerocket-os/bottlerocket#variants
    - name: "bottlerocket-aws-k8s-${CLUSTER_VERSION}-x86_64-*"

  # https://karpenter.sh/v0.37/concepts/nodeclasses/#bottlerocket-1
  blockDeviceMappings:
    # Root device
    - deviceName: /dev/xvda
      ebs:
        volumeSize: 4Gi
        volumeType: gp3
        encrypted: true
        deleteOnTermination: true
    # Data device: Container resources such as images and logs
    - deviceName: /dev/xvdb
      ebs:
        volumeSize: 64Gi
        volumeType: gp3
        encrypted: true
        deleteOnTermination: true

  # UserDataのリファレンス: https://bottlerocket.dev/en/os/1.20.x/api/settings-index/
  # UserDataの設定例: https://karpenter.sh/v0.37/concepts/nodeclasses/#bottlerocket
  userData: |
    [settings]
    [settings.kubernetes]
    api-server = '${CLUSTER_ENDPOINT}'
    cluster-certificate = '${CLUSTER_CERTIFICATE_AUTHORITY_DATA}'
    cluster-name = '${CLUSTER_NAME}'

EOF

# NodePools | Karpenter: https://karpenter.sh/docs/concepts/nodepools/
#   - instance-types | Karpenter: https://karpenter.sh/docs/reference/instance-types/
cat <<EOF > $SCRIPT_DIR/tmp/nodepool-bottlerocket-x86-64-standard.yaml
---
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: bottlerocket-x86-64-standard
spec:
  template:
    metadata:
      labels:
        karpenter.baseport.net/nodeclass: bottlerocket-x86-64
    spec:
      terminationGracePeriod: 24h  # ノードが強制削除される前にdrainできる最大時間
      expireAfter: 720h  # クラスタにノードが存在できる最長時間 (ノードの長期間の稼動による問題(メモリリークなど)のリスクを低減する)
      requirements:
        - key: kubernetes.io/arch
          operator: In
          values: ["amd64"]
        - key: kubernetes.io/os
          operator: In
          values: ["linux"]
        - key: karpenter.sh/capacity-type
          operator: In
          values: ["spot"]  # spot or on-demand
        - key: karpenter.k8s.aws/instance-family
          operator: In
          values: ["t3", "t3a", "m5", "m5a", "m6i", "m6a", "m7i", "m7a"]
        - key: "karpenter.k8s.aws/instance-cpu"
          operator: In
          values: ["2", "4"]
      nodeClassRef:
        group: karpenter.k8s.aws
        kind: EC2NodeClass
        name: bottlerocket-x86-64
  limits:
    cpu: 20
  disruption:
    # 統合のために考慮すべきノードの種類
    # WhenEmptyOrUnderutilized: すべてのノードを統合の対象とし、ノードが十分に活用されておらず、コスト削減のために変更できると判断した場合にノードを削除・置換しようとする
    # WhenEmpty: ワークロードポッドを含まないノードのみを統合の対象とする
    consolidationPolicy: WhenEmptyOrUnderutilized

    # Podがノードに追加または削除された後、Karpenterがノードを統合するまでの待機時間。
    consolidateAfter: 1m
EOF

#
# bottlerocket, x86-64, NVIDIA
#
# NodeClasses | Karpenter: https://karpenter.sh/v0.37/concepts/nodeclasses/
# bottlerocket | Github: https://github.com/bottlerocket-os/bottlerocket
# bottlerocket Settings: https://bottlerocket.dev/en/os/1.20.x/api/settings-index/
cat <<EOF > $SCRIPT_DIR/tmp/nodeclass-bottlerocket-x86-64-nvidia.yaml
---
apiVersion: karpenter.k8s.aws/v1
kind: EC2NodeClass
metadata:
  name: bottlerocket-x86-64-nvidia
spec:
  amiFamily: Bottlerocket
  role: "${KARPENTER_NODE_ROLE_NAME}" # replace with your cluster name
  subnetSelectorTerms:
    - tags:
        karpenter.sh/discovery: "${CLUSTER_NAME}" # replace with your cluster name
  securityGroupSelectorTerms:
    - tags:
        karpenter.sh/discovery: "${CLUSTER_NAME}" # replace with your cluster name
  amiSelectorTerms:
    #- id: "AMI_ID"
    # bottlerocketのami: https://github.com/bottlerocket-os/bottlerocket#variants
    - name: "bottlerocket-aws-k8s-${CLUSTER_VERSION}-nvidia-x86_64-*"

  # https://karpenter.sh/v0.37/concepts/nodeclasses/#bottlerocket-1
  blockDeviceMappings:
    # Root device
    - deviceName: /dev/xvda
      ebs:
        volumeSize: 4Gi
        volumeType: gp3
        encrypted: true
        deleteOnTermination: true
    # Data device: Container resources such as images and logs
    - deviceName: /dev/xvdb
      ebs:
        volumeSize: 64Gi
        volumeType: gp3
        encrypted: true
        deleteOnTermination: true

  # UserDataのリファレンス: https://bottlerocket.dev/en/os/1.20.x/api/settings-index/
  # UserDataの設定例: https://karpenter.sh/v0.37/concepts/nodeclasses/#bottlerocket
  userData: |
    [settings]
    [settings.kubernetes]
    api-server = '${CLUSTER_ENDPOINT}'
    cluster-certificate = '${CLUSTER_CERTIFICATE_AUTHORITY_DATA}'
    cluster-name = '${CLUSTER_NAME}'

EOF

# NodePools | Karpenter: https://karpenter.sh/docs/concepts/nodepools/
#   - instance-types | Karpenter: https://karpenter.sh/docs/reference/instance-types/
cat <<EOF > $SCRIPT_DIR/tmp/nodepool-bottlerocket-x86-64-nvidia-standard.yaml
---
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: bottlerocket-x86-64-nvidia-standard
spec:
  template:
    metadata:
      labels:
        karpenter.baseport.net/nodeclass: bottlerocket-x86-64-nvidia
    spec:
      terminationGracePeriod: 24h  # ノードが強制削除される前にdrainできる最大時間
      expireAfter: 720h  # クラスタにノードが存在できる最長時間 (ノードの長期間の稼動による問題(メモリリークなど)のリスクを低減する)
      requirements:
        - key: kubernetes.io/arch
          operator: In
          values: ["amd64"]
        - key: kubernetes.io/os
          operator: In
          values: ["linux"]
        - key: karpenter.sh/capacity-type
          operator: In
          values: ["spot"]  # spot or on-demand
        - key: karpenter.k8s.aws/instance-family
          operator: In
          values: ["g4dn"]
        - key: "karpenter.k8s.aws/instance-cpu"
          operator: In
          values: ["4"]
      nodeClassRef:
        group: karpenter.k8s.aws
        kind: EC2NodeClass
        name: bottlerocket-x86-64-nvidia
      # nvidia-device-pluginデーモンセットを起動しなければならないため "nvidia.com/gpu" 以外のtaintの付与には注意
      # nvidia-device-pluginデーモンセットのtoleration: https://github.com/NVIDIA/k8s-device-plugin/blob/v0.16.2/deployments/helm/nvidia-device-plugin/values.yaml#L85
      taints:
        - key: nvidia.com/gpu
          value: "true"
          effect: "NoSchedule"
  limits:
    cpu: 20
  disruption:
    # 統合のために考慮すべきノードの種類
    # WhenEmptyOrUnderutilized: すべてのノードを統合の対象とし、ノードが十分に活用されておらず、コスト削減のために変更できると判断した場合にノードを削除・置換しようとする
    # WhenEmpty: ワークロードポッドを含まないノードのみを統合の対象とする
    consolidationPolicy: WhenEmptyOrUnderutilized

    # Podがノードに追加または削除された後、Karpenterがノードを統合するまでの待機時間。
    consolidateAfter: 1m
EOF

#
# bottlerocket, aarch64, NVIDIA
#
# NodeClasses | Karpenter: https://karpenter.sh/v0.37/concepts/nodeclasses/
# bottlerocket | Github: https://github.com/bottlerocket-os/bottlerocket
# bottlerocket Settings: https://bottlerocket.dev/en/os/1.20.x/api/settings-index/
cat <<EOF > $SCRIPT_DIR/tmp/nodeclass-bottlerocket-aarch64-nvidia.yaml
---
apiVersion: karpenter.k8s.aws/v1
kind: EC2NodeClass
metadata:
  name: bottlerocket-aarch64-nvidia
spec:
  amiFamily: Bottlerocket
  role: "${KARPENTER_NODE_ROLE_NAME}" # replace with your cluster name
  subnetSelectorTerms:
    - tags:
        karpenter.sh/discovery: "${CLUSTER_NAME}" # replace with your cluster name
  securityGroupSelectorTerms:
    - tags:
        karpenter.sh/discovery: "${CLUSTER_NAME}" # replace with your cluster name
  amiSelectorTerms:
    #- id: "AMI_ID"
    # bottlerocketのami: https://github.com/bottlerocket-os/bottlerocket#variants
    - name: "bottlerocket-aws-k8s-${CLUSTER_VERSION}-nvidia-aarch64-*"

  # https://karpenter.sh/v0.37/concepts/nodeclasses/#bottlerocket-1
  blockDeviceMappings:
    # Root device
    - deviceName: /dev/xvda
      ebs:
        volumeSize: 4Gi
        volumeType: gp3
        encrypted: true
        deleteOnTermination: true
    # Data device: Container resources such as images and logs
    - deviceName: /dev/xvdb
      ebs:
        volumeSize: 64Gi
        volumeType: gp3
        encrypted: true
        deleteOnTermination: true

  # UserDataのリファレンス: https://bottlerocket.dev/en/os/1.20.x/api/settings-index/
  # UserDataの設定例: https://karpenter.sh/v0.37/concepts/nodeclasses/#bottlerocket
  userData: |
    [settings]
    [settings.kubernetes]
    api-server = '${CLUSTER_ENDPOINT}'
    cluster-certificate = '${CLUSTER_CERTIFICATE_AUTHORITY_DATA}'
    cluster-name = '${CLUSTER_NAME}'

EOF

# NodePools | Karpenter: https://karpenter.sh/docs/concepts/nodepools/
#   - instance-types | Karpenter: https://karpenter.sh/docs/reference/instance-types/
cat <<EOF > $SCRIPT_DIR/tmp/nodepool-bottlerocket-aarch64-nvidia-standard.yaml
---
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: bottlerocket-aarch64-nvidia-standard
spec:
  template:
    metadata:
      labels:
        karpenter.baseport.net/nodeclass: bottlerocket-aarch64-nvidia
    spec:
      terminationGracePeriod: 24h  # ノードが強制削除される前にdrainできる最大時間
      expireAfter: 720h  # クラスタにノードが存在できる最長時間 (ノードの長期間の稼動による問題(メモリリークなど)のリスクを低減する)
      requirements:
        - key: kubernetes.io/arch
          operator: In
          values: ["arm64"]
        - key: kubernetes.io/os
          operator: In
          values: ["linux"]
        - key: karpenter.sh/capacity-type
          operator: In
          values: ["spot"]  # spot or on-demand
        - key: karpenter.k8s.aws/instance-family
          operator: In
          values: ["g5g"]
        - key: "karpenter.k8s.aws/instance-cpu"
          operator: In
          values: ["4"]
      nodeClassRef:
        group: karpenter.k8s.aws
        kind: EC2NodeClass
        name: bottlerocket-aarch64-nvidia
      # nvidia-device-pluginデーモンセットを起動しなければならないため "nvidia.com/gpu" 以外のtaintの付与には注意
      # nvidia-device-pluginデーモンセットのtoleration: https://github.com/NVIDIA/k8s-device-plugin/blob/v0.16.2/deployments/helm/nvidia-device-plugin/values.yaml#L85
      taints:
        - key: nvidia.com/gpu
          value: "true"
          effect: "NoSchedule"
  limits:
    cpu: 20
  disruption:
    # 統合のために考慮すべきノードの種類
    # WhenEmptyOrUnderutilized: すべてのノードを統合の対象とし、ノードが十分に活用されておらず、コスト削減のために変更できると判断した場合にノードを削除・置換しようとする
    # WhenEmpty: ワークロードポッドを含まないノードのみを統合の対象とする
    consolidationPolicy: WhenEmptyOrUnderutilized

    # Podがノードに追加または削除された後、Karpenterがノードを統合するまでの待機時間。
    consolidateAfter: 1m
EOF
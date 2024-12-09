
# クラスターロールの作成
[Create an EKS Auto Mode Cluster IAM Role | AWS](https://docs.aws.amazon.com/eks/latest/userguide/automode-get-started-cli.html#_create_an_eks_auto_mode_cluster_iam_role)


クラスタロールには以下のポリシーを追加で付与する
- AmazonEKSComputePolicy
- AmazonEKSBlockStoragePolicy
- AmazonEKSLoadBalancingPolicy
- AmazonEKSNetworkingPolicy
- AmazonEKSClusterPolicy

```bash
terraform -chdir=$CONTAINER_PROJECT_ROOT/terraform/env/prd/eks init
terraform -chdir=$CONTAINER_PROJECT_ROOT/terraform/env/prd/eks plan
terraform -chdir=$CONTAINER_PROJECT_ROOT/terraform/env/prd/eks apply -auto-approve
```

# ノードロールの作成
[Create an EKS Auto Mode Node IAM Role | AWS](https://docs.aws.amazon.com/eks/latest/userguide/automode-get-started-cli.html#_create_an_eks_auto_mode_node_iam_role)

```bash
terraform -chdir=$CONTAINER_PROJECT_ROOT/terraform/env/prd/addon init
terraform -chdir=$CONTAINER_PROJECT_ROOT/terraform/env/prd/addon plan
terraform -chdir=$CONTAINER_PROJECT_ROOT/terraform/env/prd/addon apply -auto-approve

# ノードロールの名前を確認
terraform -chdir=$CONTAINER_PROJECT_ROOT/terraform/env/prd/addon output automode_node_role
```


# 利用するリソースにタグ付け

```bash
STAGE_NAME="prd"
TERRAFORM_DIR="${CONTAINER_PROJECT_ROOT}/terraform/env/$STAGE_NAME"
CLUSTER_NAME=$( terraform -chdir=$TERRAFORM_DIR/cluster output -raw eks_cluster_name)

#
# EKS Auto Modeで利用するサブネットにタグ付け
#
PRIVATE_SUBNET_IDS=$(terraform -chdir=${TERRAFORM_DIR}/cluster output -json private_subnets | jq -r ".[]")

for subnet_id in $PRIVATE_SUBNET_IDS; do
  echo "[subnet] $subnet_id"
  aws ec2 create-tags \
    --resources $subnet_id \
    --tags "Key=automode.prd.baseport.net/discovery,Value=${CLUSTER_NAME}"
done

#
# EKS Auto Modeで利用するSecurity Groupにタグ付け
#

# クラスタプライマリセキュリティグループ
CLUSTER_PRIMARY_SECURITY_GROUP_ID=$(terraform -chdir=${TERRAFORM_DIR}/cluster output -raw eks_cluster_primary_sg_id)
echo "[cluster primary security-group] $CLUSTER_PRIMARY_SECURITY_GROUP_ID"
aws ec2 create-tags \
  --resources $CLUSTER_PRIMARY_SECURITY_GROUP_ID \
  --tags "Key=automode.prd.baseport.net/discovery,Value=${CLUSTER_NAME}"


# クラスタセキュリティグループ
CLUSTER_SECURITY_GROUP_IDS=$(terraform -chdir=${TERRAFORM_DIR}/cluster output  -json eks_cluster_sg_ids | jq -r ".[]")

if [ -n "$CLUSTER_SECURITY_GROUP_IDS" ]; then
  for CLUSTER_SECURITY_GROUP_ID in $CLUSTER_SECURITY_GROUP_IDS; do
    echo "[cluster security-group] $CLUSTER_SECURITY_GROUP_ID"
    aws ec2 create-tags \
      --resources $CLUSTER_SECURITY_GROUP_ID \
      --tags "Key=automode.prd.baseport.net/discovery,Value=${CLUSTER_NAME}"
  done
fi
```

# ノードクラス・ノードプールのマニフェストをapply

```bash
$ kubectl apply -f plugin/eks-auto-mode/resources/nodeclass-standard.yaml
nodeclass.eks.amazonaws.com/standard unchanged
$ kubectl apply -f plugin/eks-auto-mode/resources/nodepool-standard.yaml
nodepool.karpenter.sh/automode-standard created

# ちゃんと動くかテスト
$ kubectl apply -f plugin/eks-auto-mode/sample/automode-standard.yaml
deployment.apps/automode-standard-test created
$ kubectl delete -f plugin/eks-auto-mode/sample/automode-standard.yaml
```
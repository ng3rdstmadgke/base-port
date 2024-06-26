# BasePort

EKS環境を構築するプロジェクト


# Get Started

## EKSクラスタ作成

```bash
cd ${CONTAINER_PROJECT_ROOT}/teraform/env/cluster/prd
terraform init
terraform plan
terraform apply -auto-approve
```

`~/.kube/config` にクラスタを登録

```bash
aws eks update-kubeconfig --name baseport-prd

# kubectlコマンドが実行できるかを確認
kubectl get all
```

## AWSコンソールからpodを閲覧できるようにする

```bash
CLUSTER_NAME=baseport-prd
ROLE_ARN=arn:aws:iam::xxxxxxxxxxxx:role/xxxxxxxxxxxxxxxxxxxxxxxxxxx

# IAMロールにEKSの権限を付与する (aws-auth ConfigMapに設定を追加)
eksctl create iamidentitymapping \
  --cluster $CLUSTER_NAME \
  --region ap-northeast-1 \
  --arn $ROLE_ARN \
  --group system:masters \
  --username AwsConsole

# 指定したロールがsystem:mastersグループに属しているかを確認
kubectl describe -n kube-system configmap/aws-auth
```


## Helmチャートのインストール

```bash
cd ${CONTAINER_PROJECT_ROOT}/teraform/env/helm/prd
terraform init
terraform plan
terraform apply -auto-approve
```


# 削除

```bash
cd ${CONTAINER_PROJECT_ROOT}/teraform/env/helm/prd
terraform destroy -auto-approve

cd ${CONTAINER_PROJECT_ROOT}/teraform/env/cluster/prd
terraform destroy -auto-approve
```
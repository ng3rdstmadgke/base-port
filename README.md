# BasePort

EKS環境を構築するプロジェクト


# Get Started

## EKSクラスタ作成

```bash
terraform -chdir=${CONTAINER_PROJECT_ROOT}/terraform/env/cluster/prd init
terraform -chdir=${CONTAINER_PROJECT_ROOT}/terraform/env/cluster/prd plan
terraform -chdir=${CONTAINER_PROJECT_ROOT}/terraform/env/cluster/prd apply -auto-approve
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

## ノードグループの作成

```bash
terraform -chdir=${CONTAINER_PROJECT_ROOT}/terraform/env/node/prd init
terraform -chdir=${CONTAINER_PROJECT_ROOT}/terraform/env/node/prd plan
terraform -chdir=${CONTAINER_PROJECT_ROOT}/terraform/env/node/prd apply -auto-approve
```

## Helmチャートのインストール

```bash
terraform -chdir=${CONTAINER_PROJECT_ROOT}/terraform/env/helm/prd init
terraform -chdir=${CONTAINER_PROJECT_ROOT}/terraform/env/helm/prd plan
terraform -chdir=${CONTAINER_PROJECT_ROOT}/terraform/env/helm/prd apply -auto-approve
```

## DBの作成

```bash
terraform -chdir=${CONTAINER_PROJECT_ROOT}/terraform/env/database/prd init
terraform -chdir=${CONTAINER_PROJECT_ROOT}/terraform/env/database/prd plan
terraform -chdir=${CONTAINER_PROJECT_ROOT}/terraform/env/database/prd apply -auto-approve
```

## サービスリソース作成

```bash
terraform -chdir=${CONTAINER_PROJECT_ROOT}/terraform/env/service/prd init
terraform -chdir=${CONTAINER_PROJECT_ROOT}/terraform/env/service/prd plan
terraform -chdir=${CONTAINER_PROJECT_ROOT}/terraform/env/service/prd apply -auto-approve
```

## セットアップスクリプトの実行

```bash
# Karpenterのノードプールを作成
./scripts/karpenter/setup.sh
```


# 削除

```bash
terraform -chdir=${CONTAINER_PROJECT_ROOT}/terraform/env/helm/prd destroy -auto-approve
terraform -chdir=${CONTAINER_PROJECT_ROOT}/terraform/env/cluster/prd destroy -auto-approve
```
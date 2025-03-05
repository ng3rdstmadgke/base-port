# BasePort

EKS環境を構築するプロジェクト


# デプロイ

```bash
STAGE=prd
```

## ベースコンポーネント

```bash
make tf-plan STAGE=$STAGE COMPONENT=base
make tf-apply STAGE=$STAGE COMPONENT=base
```

## ネットワークコンポーネント

```bash
make tf-plan STAGE=$STAGE COMPONENT=network
make tf-apply STAGE=$STAGE COMPONENT=network
```

## EKSクラスタコンポーネント

```bash
make tf-plan STAGE=$STAGE COMPONENT=cluster
make tf-apply STAGE=$STAGE COMPONENT=cluster
```

`~/.kube/config` にクラスタを登録

```bash
aws eks update-kubeconfig --name baseport-prd

# kubectlコマンドが実行できるかを確認
kubectl get all
```

## ノードグループコンポーネントの作成

```bash
make tf-plan STAGE=$STAGE COMPONENT=node-group
make tf-apply STAGE=$STAGE COMPONENT=node-group
```

## アドオンコンポーネントの作成

```bash
make tf-plan STAGE=$STAGE COMPONENT=addon
make tf-apply STAGE=$STAGE COMPONENT=addon
```

## プラグインチャートのインストール

```bash
make tf-plan STAGE=$STAGE COMPONENT=plugin
make tf-apply STAGE=$STAGE COMPONENT=plugin
```

### セットアップスクリプトの実行

```bash
# Karpenterのノードプールを作成
./plugin/karpenter/setup.sh
```

## DBの作成

```bash
make tf-plan STAGE=$STAGE COMPONENT=database
make tf-apply STAGE=$STAGE COMPONENT=database
```

## サービスリソース作成

```bash
make tf-plan STAGE=$STAGE COMPONENT=service
make tf-apply STAGE=$STAGE COMPONENT=service
```

# 削除

```bash
STAGE=prd
make tf-delete STAGE=$STAGE COMPONENT=service && \
make tf-delete STAGE=$STAGE COMPONENT=database && \
make tf-delete STAGE=$STAGE COMPONENT=plugin && \
make tf-delete STAGE=$STAGE COMPONENT=addon && \
make tf-delete STAGE=$STAGE COMPONENT=node-group && \
make tf-delete STAGE=$STAGE COMPONENT=cluster && \
make tf-delete STAGE=$STAGE COMPONENT=network && \
make tf-delete STAGE=$STAGE COMPONENT=base
```
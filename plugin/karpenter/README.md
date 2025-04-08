# ■ 動作確認

NodeClassを作成

```bash
for manifest in $(ls $PROJECT_DIR/plugin/karpenter/$STAGE/nodeclass); do
  kubectl apply -f $PROJECT_DIR/plugin/karpenter/$STAGE/nodeclass/$manifest
done
```

NodePoolを作成

```bash
for manifest in $(ls $PROJECT_DIR/plugin/karpenter/$STAGE/nodepool); do
  kubectl apply -f $PROJECT_DIR/plugin/karpenter/$STAGE/nodepool/$manifest
done
```

サンプルリソースの構築

```bash
# al2-x86-64-nvidia
kubectl apply -f $PROJECT_DIR/plugin/karpenter/sample/al2-x86-64-nvidia.yaml
# al2023-x86-64
kubectl apply -f $PROJECT_DIR/plugin/karpenter/sample/al2023-x86-64.yaml
# bottlerocket-x86-64
kubectl apply -f $PROJECT_DIR/plugin/karpenter/sample/bottlerocket-x86-64.yaml
# bottlerocket-x86-64-nvidia
kubectl apply -f $PROJECT_DIR/plugin/karpenter/sample/bottlerocket-x86-64-nvidia.yaml
# bottlerocket-x86-64-nvidia-g6
kubectl apply -f $PROJECT_DIR/plugin/karpenter/sample/bottlerocket-x86-64-nvidia-g6.yaml
# bottlerocket-aarch64-nvidia
kubectl apply -f $PROJECT_DIR/plugin/karpenter/sample/bottlerocket-aarch64-nvidia.yaml
```

サンプルリソースの削除


```bash
# al2-x86-64-nvidia
kubectl delete -f $PROJECT_DIR/plugin/karpenter/sample/al2-x86-64-nvidia.yaml
# al2023-x86-64
kubectl delete -f $PROJECT_DIR/plugin/karpenter/sample/al2023-x86-64.yaml
# bottlerocket-x86-64
kubectl delete -f $PROJECT_DIR/plugin/karpenter/sample/bottlerocket-x86-64.yaml
# bottlerocket-x86-64-nvidia
kubectl delete -f $PROJECT_DIR/plugin/karpenter/sample/bottlerocket-x86-64-nvidia.yaml
# bottlerocket-x86-64-nvidia-g6
kubectl delete -f $PROJECT_DIR/plugin/karpenter/sample/bottlerocket-x86-64-nvidia-g6.yaml
# bottlerocket-aarch64-nvidia
kubectl delete -f $PROJECT_DIR/plugin/karpenter/sample/bottlerocket-aarch64-nvidia.yaml
```

# ■ インストール

※ terraform の plugin コンポーネントがデプロイされている事が前提

```bash
KARPENTER_VERSION=1.1.0
KARPENTER_NAMESPACE="kube-system"
STAGE=prd

helm upgrade --install karpenter-crd oci://public.ecr.aws/karpenter/karpenter-crd \
  --version $KARPENTER_VERSION \
  --namespace "$KARPENTER_NAMESPACE" \
  --create-namespace \
  --wait

helm upgrade --install karpenter oci://public.ecr.aws/karpenter/karpenter \
  --version "$KARPENTER_VERSION" \
  --namespace "$KARPENTER_NAMESPACE" \
  --create-namespace \
  -f $PROJECT_DIR/plugin/karpenter/prd/conf/values_$KARPENTER_VERSION.yaml \
  --wait

cd ${PROJECT_DIR}/plugin/karpenter

# NodeClassを作成
for manifest in $(ls $PROJECT_DIR/plugin/karpenter/$STAGE/nodeclass); do
  kubectl apply -f $PROJECT_DIR/plugin/karpenter/$STAGE/nodeclass/$manifest
done

# NodePoolを作成
for manifest in $(ls $PROJECT_DIR/plugin/karpenter/$STAGE/nodepool); do
  kubectl apply -f $PROJECT_DIR/plugin/karpenter/$STAGE/nodepool/$manifest
done
```

# ■ アップデート履歴
## (v1.1.0 -> v1.3.3)

差分確認

```bash
KARPENTER_VERSION=1.3.3
KARPENTER_NAMESPACE="kube-system"

helm diff upgrade karpenter-crd oci://public.ecr.aws/karpenter/karpenter-crd \
  --namespace $KARPENTER_NAMESPACE \
  --version $KARPENTER_VERSION

helm diff upgrade karpenter oci://public.ecr.aws/karpenter/karpenter \
  --namespace $KARPENTER_NAMESPACE \
  --values $PROJECT_DIR/plugin/karpenter/prd/conf/values_$KARPENTER_VERSION.yaml \
  --version $KARPENTER_VERSION
```

アップデート

```bash
# karpenter-crd
helm upgrade --install karpenter-crd oci://public.ecr.aws/karpenter/karpenter-crd \
  --version $KARPENTER_VERSION \
  --namespace "$KARPENTER_NAMESPACE" \
  --create-namespace \
  --wait

# karpenter
helm upgrade --install karpenter oci://public.ecr.aws/karpenter/karpenter \
  --version "$KARPENTER_VERSION" \
  --namespace "$KARPENTER_NAMESPACE" \
  --create-namespace \
  -f $PROJECT_DIR/plugin/karpenter/prd/conf/values_$KARPENTER_VERSION.yaml \
  --wait

# バージョンアップの確認
helm list -A | grep karpenter
# karpenter      kube-system  6  2024-12-09 18:01:13.724344281 +0900 JST deployed  karpenter-1.0.8      1.0.8
# karpenter-crd  kube-system  5  2024-12-09 18:01:49.402501464 +0900 JST deployed  karpenter-crd-1.0.8  1.0.8
```

動作確認

```bash
# bottlerocket-x86-64
kubectl apply -f $PROJECT_DIR/plugin/karpenter/sample/bottlerocket-x86-64.yaml
kubectl delete -f $PROJECT_DIR/plugin/karpenter/sample/bottlerocket-x86-64.yaml
```
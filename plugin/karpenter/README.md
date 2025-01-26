# セットアップ

```bash
cd ${PROJECT_DIR}/plugin/karpenter
# マニフェストファイルを作成
./setup.sh

# NodeClass, NodePoolを作成
./apply.sh

# NodeClass, NodePoolの削除
./delete.sh
```

# 動作確認

```bash
# al2023-x86-64
kubectl apply -f sample/al2023-x86-64.yaml
kubectl delete -f sample/al2023-x86-64.yaml

# al2-x86-64-nvidia
kubectl apply -f sample/al2-x86-64-nvidia.yaml
kubectl delete -f sample/al2-x86-64-nvidia.yaml

# bottlerocket-x86-64
kubectl apply -f sample/bottlerocket-x86-64.yaml
kubectl delete -f sample/bottlerocket-x86-64.yaml

# bottlerocket-x86-64-nvidia
kubectl apply -f sample/bottlerocket-x86-64-nvidia.yaml
kubectl delete -f sample/bottlerocket-x86-64-nvidia.yaml
```


# アップデート(v1.0.1 -> v1.1.0)

## v1.0.1 -> v1.0.8

[Before Upgrading to v1.1.0 | Karpenter](https://karpenter.sh/v1.0/upgrading/v1-migration/#before-upgrading-to-v110)

karpenterのアップデート

```hcl:terraform/module/karpenter/main.tf
resource "helm_release" "karpenter" {
  name       = "karpenter"
  #repository = "xxxxxxxxxxxxxxxxxxxxx"
  chart      = "oci://public.ecr.aws/karpenter/karpenter"
  version    = "1.0.8"
  //...
}
```

```bash
terraform init
terraform plan
terraform apply
```

karpenter-crdのアップデート

```bash
KARPENTER_NAMESPACE=kube-system
KARPENTER_CRD_VERSION=1.0.8
helm upgrade --install karpenter-crd oci://public.ecr.aws/karpenter/karpenter-crd --version $KARPENTER_CRD_VERSION --namespace "${KARPENTER_NAMESPACE}" --create-namespace
```

バージョンアップの確認

```bash
 $ helm list -A | grep karpenter
karpenter      kube-system  6  2024-12-09 18:01:13.724344281 +0900 JST deployed  karpenter-1.0.8      1.0.8
karpenter-crd  kube-system  5  2024-12-09 18:01:49.402501464 +0900 JST deployed  karpenter-crd-1.0.8  1.0.8
```

すべてのリソースがetcdにv1として格納されていることを確認。  
※ v1.0.6+ には格納されているすべてのリソースをv1に自動的に移行するコントローラが含まれているため、1.0.8にアップグレードした

```bash
$ for crd in "nodepools.karpenter.sh" "nodeclaims.karpenter.sh" "ec2nodeclasses.karpenter.k8s.aws"; do kubectl get crd ${crd} -ojsonpath="{.status.storedVersions}{'\n'}" done
["v1"]
["v1"]
["v1"]
```

## v1.0.8 -> v1.1.0

[Upgradingto 1.1.0+](https://karpenter.sh/docs/upgrading/upgrade-guide/#upgrading-to-110)


karpenterのアップデート

```hcl:terraform/module/karpenter/main.tf
resource "helm_release" "karpenter" {
  name       = "karpenter"
  #repository = "xxxxxxxxxxxxxxxxxxxxx"
  chart      = "oci://public.ecr.aws/karpenter/karpenter"
  version    = "1.1.0"
  //...
}
```

```bash
terraform init
terraform plan
terraform apply
```


karpenter-crdのアップデート

```bash
KARPENTER_NAMESPACE=kube-system
KARPENTER_CRD_VERSION=1.1.0
helm upgrade --install karpenter-crd oci://public.ecr.aws/karpenter/karpenter-crd --version $KARPENTER_CRD_VERSION --namespace "${KARPENTER_NAMESPACE}" --create-namespace
```
# セットアップ

```bash
cd ${CONTAINER_PROJECT_ROOT}/scripts/karpenter
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
# セットアップ

```bash
cd ${CONTAINER_PROJECT_ROOT}/scripts/karpenter
# マニフェストファイルを作成
setup.sh

# ノードプールを作成
kubectl apply -f tmp/node_pool.yaml

# ノードプールの削除
kubectl delete -f tmp/node_pool.yaml
```

# 動作確認

```bash
# スケールアップ
${CONTAINER_PROJECT_ROOT}/scripts/karpenter/test/scale_up.sh

# スケールダウン
${CONTAINER_PROJECT_ROOT}/scripts/karpenter/test/scale_down.sh
```

# デバッグ


```bash
# karpenter controllerのログ確認
${CONTAINER_PROJECT_ROOT}/scripts/karpenter/tail_log.sh
```
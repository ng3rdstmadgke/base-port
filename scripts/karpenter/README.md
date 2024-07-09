# セットアップ

```bash
# マニフェストファイルを作成
${CONTAINER_PROJECT_ROOT}/scripts/karpenter/setup.sh

# ノードプールを作成
kubectl apply -f ${CONTAINER_PROJECT_ROOT}/scripts/karpenter/tmp/node_pool.yaml

# ノードプールの削除
kubectl delete -f ${CONTAINER_PROJECT_ROOT}/scripts/karpenter/tmp/node_pool.yaml
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
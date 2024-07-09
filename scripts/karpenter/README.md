# セットアップ

```bash
./scripts/karpenter/setup.sh
```

# 動作確認

```bash
# karpenter controllerのログ確認
./scripts/karpenter/test/tail_log.sh

# スケールアップ
./scripts/karpenter/test/scale_up.sh

# スケールダウン
./scripts/karpenter/test/scale_down.sh
```

ログ確認


```bash
$ kubectl get po -n kube-system | grep karpenter

$ kubectl logs -n kube-system -f karpenter-cf47cdf67-x4qxq
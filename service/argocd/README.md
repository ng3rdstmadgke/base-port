# デプロイ
## ArgoCDに外部から接続するためのALBを作成

参考: https://argo-cd.readthedocs.io/en/stable/operator-manual/ingress/#aws-application-load-balancers-albs-and-classic-elb-http-mode

```bash
# argocd-server をターゲットとするALBを作成
kubectl apply -f ${CONTAINER_PROJECT_ROOT}/scripts/argocd/ingress.yaml
```

# ポートフォワーディング

```bash
${CONTAINER_PROJECT_ROOT}/scripts/argocd/port-forward.sh
```

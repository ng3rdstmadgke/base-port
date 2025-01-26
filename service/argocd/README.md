# デプロイ
## ArgoCDに外部から接続するためのALBを作成

参考: https://argo-cd.readthedocs.io/en/stable/operator-manual/ingress/#aws-application-load-balancers-albs-and-classic-elb-http-mode

```bash
# argocd-server をターゲットとするALBを作成
kubectl apply -f ${PROJECT_DIR}/service/argocd/ingress.yaml
```

# ポートフォワーディング

```bash
${PROJECT_DIR}/service/argocd/port-forward.sh
```

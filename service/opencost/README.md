# opencostのデプロイ

```bash
cd terraform/env/prd/helm

terraform apply -auto-approve
```

ポートフォワーディング

https://www.opencost.io/docs/installation/ui#kubectl-port-forward


```bash
kubectl port-forward --namespace opencost service/opencost 9003 9090
```

# オプション
## ingress作成

https://www.opencost.io/docs/installation/ui#ingress-for-opencost-ui

```bash
kubectl apply -f ingress.yaml
```


## CloudCostの利用 (Secretを利用する)

https://www.opencost.io/docs/configuration/aws#aws-cloud-costs

```bash
kubectl create secret generic cloud-costs --from-file=./cloud-integration.json --namespace opencost
```


values.yamlに下記設定を追加

```yaml
opencost:
  cloudIntegrationSecret: cloud-costs
  cloudCost:
    enabled: true
```
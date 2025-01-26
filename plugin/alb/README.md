# デプロイ

## ドメイン取得

参考: https://ktamido.esa.io/posts/354

`baseport.net` ドメインを取得し、Route53にホストゾーンを作成します。  


## ACM作成

参考: https://ktamido.esa.io/posts/360

下記2つのドメインの証明書を作成します。  

- `*.prd.baseport.net`
- `*.dev.baseport.net`

## リソースのデプロイ

```bash
# dev用のALBとそれに紐づくサンプルアプリをデプロイ
kubectl apply -f ${PROJECT_DIR}/plugin/alb/ingress-dev-sample.yaml

# prd用のALBとそれに紐づくサンプルアプリをデプロイ
kubectl apply -f ${PROJECT_DIR}/plugin/alb/ingress-prd-sample.yaml
```

下記にアクセス

- https://sample.dev.baseport.net
- https://sample.prd.baseport.net


## Route53にレコードを追加

- dev用
  - レコード名: `*.dev.baseport.net` 
  - タイプ: `CNAME`
  - 値: dev用のALBのDNS名
- prd用
  - レコード名: `*.prd.baseport.net` 
  - タイプ: `CNAME`
  - 値: prd用のALBのDNS名

## 削除

dev用

```bash
# metadata.annotations.alb.ingress.kubernetes.io/load-balancer-attributes の deletion_protection.enabled を falseに設定
kubectl -n ingress-dev-sample edit app-alb

# 削除
kubectl delete -f ${PROJECT_DIR}/plugin/alb/ingress-dev-sample.yaml
```

prd用

```bash
# metadata.annotations.alb.ingress.kubernetes.io/load-balancer-attributes の deletion_protection.enabled を falseに設定
kubectl -n ingress-prd-sample edit app-alb

# 削除
kubectl delete -f ${PROJECT_DIR}/plugin/alb/ingress-prd-sample.yaml
```

# テスト用のリソース

```bash
# デプロイ
kubectl apply -f ${PROJECT_DIR}/plugin/alb/sample/app.yaml

# https://ingress-test.dev.baseport.net にアクセス

# 削除
kubectl delete -f ${PROJECT_DIR}/plugin/alb/sample/app.yaml

```
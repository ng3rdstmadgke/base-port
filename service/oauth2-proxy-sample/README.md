# デプロイ

```bash
# デプロイ
kubectl apply -f ${PROJECT_DIR}/service/oauth2-proxy-sample/app.yaml
```

- http://oauth2-proxy-sample.dev.baseport.net


# 削除


```bash
# 削除
kubectl delete -f ${PROJECT_DIR}/service/oauth2-proxy-sample/app.yaml
```
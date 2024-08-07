# デプロイ

```bash
# デプロイ
kubectl apply -f ${CONTAINER_PROJECT_ROOT}/scripts/keycloak/test/oauth2-proxy-sample/app.yaml
```

- http://oauth2-proxy-sample.dev.baseport.net


# 削除


```bash
# 削除
kubectl delete -f ${CONTAINER_PROJECT_ROOT}/scripts/keycloak/test/oauth2-proxy-sample/app.yaml
```
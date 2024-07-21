- https://www.keycloak.org/getting-started/getting-started-kube
- https://www.keycloak.org/getting-started/getting-started-docker
- https://www.keycloak.org/server/containers
- https://www.keycloak.org/server/configuration-production


# デプロイ

##  作成

ベースとなるマニフェストは[kubernetes/keycloak.yaml - keycloak/keycloak-quickstarts | GitHub]( https://raw.githubusercontent.com/keycloak/keycloak-quickstarts/latest/kubernetes/keycloak.yaml)

- リポジトリ: [keycloak/keycloak-quickstarts | GitHub](https://github.com/keycloak/keycloak-quickstarts) 

```bash
kubectl apply -f ${CONTAINER_PROJECT_ROOT}/scripts/keycloak/keycloak.yaml
```

```bash
kubectl delete -f ${CONTAINER_PROJECT_ROOT}/scripts/keycloak/keycloak.yaml
```
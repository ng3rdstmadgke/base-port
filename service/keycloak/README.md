- https://www.keycloak.org/getting-started/getting-started-kube
- https://www.keycloak.org/getting-started/getting-started-docker
- https://www.keycloak.org/server/containers
- https://www.keycloak.org/server/configuration-production


# デプロイ

## テーブルの作成

運用コンテナにログイン

```bash
${PROJECT_DIR}/service/tools/build.sh --push
${PROJECT_DIR}/service/tools/run.sh
```

DBにログイン

```bash
mysql-login
```

テーブル作成

```sql
> DROP DATABASE IF EXISTS keycloak;
> CREATE DATABASE keycloak;
```

## デプロイ

ベースとなるマニフェストは[kubernetes/keycloak.yaml - keycloak/keycloak-quickstarts | GitHub]( https://raw.githubusercontent.com/keycloak/keycloak-quickstarts/latest/kubernetes/keycloak.yaml)

- リポジトリ: [keycloak/keycloak-quickstarts | GitHub](https://github.com/keycloak/keycloak-quickstarts) 

```bash
kubectl apply -f ${PROJECT_DIR}/service/keycloak/keycloak.yaml
```

# 削除

```bash
kubectl delete -f ${PROJECT_DIR}/service/keycloak/keycloak.yaml
```
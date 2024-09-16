# デプロイ
## ECR・ロールの作成

```bash
terraform -chdir=${CONTAINER_PROJECT_ROOT}/terraform/env/helm/prd init
terraform -chdir=${CONTAINER_PROJECT_ROOT}/terraform/env/helm/prd plan
terraform -chdir=${CONTAINER_PROJECT_ROOT}/terraform/env/helm/prd apply -auto-approve
```

## イメージbuild・push

```bash
${CONTAINER_PROJECT_ROOT}/scripts/tools/build.sh --push
```

## ログイン

```bash
${CONTAINER_PROJECT_ROOT}/scripts/tools/run.sh
```

## 削除

```bash
${CONTAINER_PROJECT_ROOT}/scripts/tools/delete.sh
```

## 再起動

```bash
${CONTAINER_PROJECT_ROOT}/scripts/tools/delete.sh && ${CONTAINER_PROJECT_ROOT}/scripts/tools/run.sh
```


# コマンド

```bash
# mysqlログイン
mysql-login.sh
```
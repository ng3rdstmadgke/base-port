# デプロイ
## ECR・ロールの作成

```bash
terraform -chdir=${PROJECT_DIR}/terraform/env/helm/prd init
terraform -chdir=${PROJECT_DIR}/terraform/env/helm/prd plan
terraform -chdir=${PROJECT_DIR}/terraform/env/helm/prd apply -auto-approve
```

## イメージbuild・push

```bash
${PROJECT_DIR}/service/tools/build.sh --push
```

## ログイン

```bash
${PROJECT_DIR}/service/tools/run.sh
```

## 削除

```bash
${PROJECT_DIR}/service/tools/delete.sh
```

## 再起動

```bash
${PROJECT_DIR}/service/tools/delete.sh && ${PROJECT_DIR}/service/tools/run.sh
```


# コマンド

```bash
# mysqlログイン
mysql-login.sh
```
# 注意事項

- ファイルの編集不可
  - `>>` や `>` といったリダイレクトを使ったファイルの編集はできません


# デプロイ手順

- Mountpoint for Amazon S3 CSI ドライバーを使用して Amazon S3 オブジェクトにアクセスする | AWS
  - https://docs.aws.amazon.com/ja_jp/eks/latest/userguide/s3-csi.html
- mountpoint-s3-csi-driver | GitHub
  - https://github.com/awslabs/mountpoint-s3-csi-driver
- mountpoint-s3 | GitHub
  - https://github.com/awslabs/mountpoint-s3/tree/main

## s3バケット作成

マウント対象のバケットを作成

## アドオンのインストールとIRSA作成

```bash
terraform -chdir=${PROJECT_DIR}/terraform/env/prd/helm init
terraform -chdir=${PROJECT_DIR}/terraform/env/prd/helm plan
terraform -chdir=${PROJECT_DIR}/terraform/env/prd/helm apply -auto-approve
```

# サンプルリソースデプロイ


[サンプルマニフェスト](https://github.com/awslabs/mountpoint-s3-csi-driver/blob/main/examples/kubernetes/static_provisioning/static_provisioning.yaml)


```bash
kubectl apply -f ${PROJECT_DIR}/plugin/s3/sample/static_provisioning.yaml

# podにログインして /dataにファイルが作成されていればOK
ls /data
```

削除

```bash
kubectl delete -f ${PROJECT_DIR}/plugin/s3/sample/static_provisioning.yaml
```
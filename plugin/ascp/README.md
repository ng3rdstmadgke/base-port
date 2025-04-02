# 動作確認 (Pod Identity)

## 作成

```bash
kubectl apply -f $PROJECT_DIR/plugin/ascp/sample/prd/manifest/pod_identity/sample_1.yaml
kubectl apply -f $PROJECT_DIR/plugin/ascp/sample/prd/manifest/pod_identity/sample_2.yaml
kubectl apply -f $PROJECT_DIR/plugin/ascp/sample/prd/manifest/pod_identity/sample_3.yaml
```

## 動作チェック

### sample_1 (シークレットファイルをマウントする方式)

```bash
cat /mnt/secrets-store/_baseport_prd_sample
# {"password":"sample_password","username":"sample_user"}
```

### sample_2 (Podの環境変数にアサインする方式)

```bash
cat /mnt/secrets-store/_baseport_prd_sample 
# {"password":"sample_password","username":"sample_user"}

printenv | grep "^DB"
# DB_SECRET={"password":"sample_password","username":"sample_user"}
```

### sample_3 (Podの環境変数にアサインする方式)

```bash
ls /mnt/secrets-store/
# _baseport_prd_sample  alias_password  alias_username

cat /mnt/secrets-store/_baseport_prd_sample
# {"password":"sample_password","username":"sample_user"}

cat /mnt/secrets-store/alias_password
# sample_password

cat /mnt/secrets-store/alias_username
# sample_use

printenv | grep "^DB_"
# DB_PASSWORD=sample_password
# DB_USER=sample_user
```


## 削除

```bash
kubectl delete -f $PROJECT_DIR/plugin/ascp/sample/prd/manifest/pod_identity/sample_1.yaml
kubectl delete -f $PROJECT_DIR/plugin/ascp/sample/prd/manifest/pod_identity/sample_2.yaml
kubectl delete -f $PROJECT_DIR/plugin/ascp/sample/prd/manifest/pod_identity/sample_3.yaml
```

# 動作確認 (IRSA)

## 作成

```bash
kubectl apply -f $PROJECT_DIR/plugin/ascp/sample/prd/manifest/irsa/sample_1.yaml
kubectl apply -f $PROJECT_DIR/plugin/ascp/sample/prd/manifest/irsa/sample_2.yaml
kubectl apply -f $PROJECT_DIR/plugin/ascp/sample/prd/manifest/irsa/sample_3.yaml
```

## 動作チェック

### sample_1 (シークレットファイルをマウントする方式)

```bash
cat /mnt/secrets-store/_baseport_prd_sample
# {"password":"sample_password","username":"sample_user"}
```

### sample_2 (Podの環境変数にアサインする方式)

```bash
cat /mnt/secrets-store/_baseport_prd_sample 
# {"password":"sample_password","username":"sample_user"}

printenv | grep "^DB"
# DB_SECRET={"password":"sample_password","username":"sample_user"}
```

### sample_3 (Podの環境変数にアサインする方式)

```bash
ls /mnt/secrets-store/
# _baseport_prd_sample  alias_password  alias_username

cat /mnt/secrets-store/_baseport_prd_sample
# {"password":"sample_password","username":"sample_user"}

cat /mnt/secrets-store/alias_password
# sample_password

cat /mnt/secrets-store/alias_username
# sample_use

printenv | grep "^DB_"
# DB_PASSWORD=sample_password
# DB_USER=sample_user
```

## 削除

```bash
kubectl delete -f $PROJECT_DIR/plugin/ascp/sample/prd/manifest/irsa/sample_1.yaml
kubectl delete -f $PROJECT_DIR/plugin/ascp/sample/prd/manifest/irsa/sample_2.yaml
kubectl delete -f $PROJECT_DIR/plugin/ascp/sample/prd/manifest/irsa/sample_3.yaml
```

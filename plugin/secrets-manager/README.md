# 動作確認

Secretsとマニフェストの生成

```bash
$ ${PROJECT_DIR}/plugin/secrets-manager/sample/setup.sh
```

## 1. シークレットファイルをマウントする方式

SecretProviderClassの作成

```bash
$ kubectl apply -f ${PROJECT_DIR}/plugin/secrets-manager/sample/tmp/spc_1.yaml

# 確認
$ kubectl get secretproviderclass
NAME                  AGE
ascp-test-secrets-1   8s
```

Deploymentの作成


```bash
$ kubectl apply -f ${PROJECT_DIR}/plugin/secrets-manager/sample/tmp/deployment_1.yaml
```

確認

```bash
# k9sで ascp-test-deployment-1-* podに接続
$ cat /mnt/secrets-store/_baseport_prd_ascp-test
{"username":"hogehoge", "password":"piyopiyo"}
```

削除

```bash
$ kubectl delete -f ${PROJECT_DIR}/plugin/secrets-manager/sample/tmp/deployment_1.yaml
$ kubectl delete -f ${PROJECT_DIR}/plugin/secrets-manager/sample/tmp/spc_1.yaml
```

## 2. Podの環境変数にアサインする方式

SecretProviderClassの作成

```bash
$ kubectl apply -f ${PROJECT_DIR}/plugin/secrets-manager/sample/tmp/spc_2.yaml

# 確認
$ kubectl get secretproviderclass
NAME                  AGE
ascp-test-secrets-2   8s
```

Deploymentの作成


```bash
$ kubectl apply -f ${PROJECT_DIR}/plugin/secrets-manager/sample/tmp/deployment_2.yaml

# ボリュームのマウント状態の確認
$ kubectl get secretproviderclasspodstatus
```

確認

```bash
# k9sで ascp-test-deployment-2-* podに接続

# マウントされているファイルの確認
$ cat /mnt/secrets-store/_baseport_prd_ascp-test
{"username":"hogehoge", "password":"piyopiyo"}

# 環境変数の確認
$ echo $DB_SECRET
{"username":"hogehoge", "password":"piyopiyo"}
```

削除

```bash
$ kubectl delete -f ${PROJECT_DIR}/plugin/secrets-manager/sample/tmp/deployment_2.yaml
$ kubectl delete -f ${PROJECT_DIR}/plugin/secrets-manager/sample/tmp/spc_2.yaml
```

## 3. JSONをパースしてPodの環境変数にアサインする方式

SecretProviderClassの作成

```bash
$ kubectl apply -f ${PROJECT_DIR}/plugin/secrets-manager/sample/tmp/spc_3.yaml

# 確認
$ kubectl get secretproviderclass
NAME                  AGE
ascp-test-secrets-3   8s
```

Deploymentの作成


```bash
$ kubectl apply -f ${PROJECT_DIR}/plugin/secrets-manager/sample/tmp/deployment_3.yaml

# ボリュームのマウント状態の確認
$ kubectl get secretproviderclasspodstatus
```

確認

```bash
# k9sで ascp-test-deployment-2-* podに接続

# マウントされているファイルの確認
$ cat /mnt/secrets-store/_baseport_prd_ascp-test
{"username":"hogehoge", "password":"piyopiyo"}

# 環境変数の確認
$ echo $DB_USER
hogehoge
$ echo $DB_PASSWORD
piyopiyo
```

削除

```bash
$ kubectl delete -f ${PROJECT_DIR}/plugin/secrets-manager/sample/tmp/deployment_3.yaml
$ kubectl delete -f ${PROJECT_DIR}/plugin/secrets-manager/sample/tmp/spc_3.yaml
```
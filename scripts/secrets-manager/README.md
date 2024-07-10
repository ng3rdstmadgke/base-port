# 動作確認

## 1. シークレットファイルをマウントする方法

Secretsとマニフェストの生成

```bash
$ ${CONTAINER_PROJECT_ROOT}/scripts/secrets-manager/test/setup.sh
```
SecretProviderClassの作成

```bash
$ kubectl apply -f ${CONTAINER_PROJECT_ROOT}/scripts/secrets-manager/test/tmp/spc_1.yaml

# 確認
$ kubectl get secretproviderclass
NAME                  AGE
ascp-test-secrets-1   8s

# 詳細
$ kubectl describe secretproviderclass ascp-test-secrets-1
```
Deploymentの作成

```bash
$ kubectl apply -f ${CONTAINER_PROJECT_ROOT}/scripts/secrets-manager/test/tmp/deployment_1.yaml

# podの確認
$ kubectl get po
NAME                                     READY   STATUS    RESTARTS   AGE
ascp-test-deployment-1-995f98fd7-j4ntx   1/1     Running   0          7s

# ボリュームのマウント状態の確認
$ kubectl get secretproviderclasspodstatus
NAME                                                                 AGE
ascp-test-deployment-1-995f98fd7-j4ntx-default-ascp-test-secrets-1   29s

# ボリュームのマウント状態の詳細 (<pod name>-<namespace>-<secretproviderclass name>)
$ $ kubectl describe secretproviderclasspodstatus ascp-test-deployment-1-995f98fd7-j4ntx-default-ascp-test-secrets-1

# SecretsManagerの中身を確認 (シークレット名の "/" は "_" に変換される)
$ kubectl exec -ti ascp-test-deployment-1-995f98fd7-j4ntx -- cat /mnt/secrets-store/_baseport_prd_ascp-test
{"username":"hogehoge", "password":"piyopiyo"}
```

削除

```bash
$ kubectl delete -f ${CONTAINER_PROJECT_ROOT}/scripts/secrets-manager/test/tmp/deployment_1.yaml
$ kubectl delete -f ${CONTAINER_PROJECT_ROOT}/scripts/secrets-manager/test/tmp/spc_1.yaml
```

## 2. Kubernetes の Secret としてPodの環境変数にアサインする方法

Secretsとマニフェストの生成

```bash
$ ${CONTAINER_PROJECT_ROOT}/scripts/secrets-manager/test/setup.sh
```
SecretProviderClassの作成

```bash
$ kubectl apply -f ${CONTAINER_PROJECT_ROOT}/scripts/secrets-manager/test/tmp/spc_2.yaml

# 確認
$ kubectl get secretproviderclass
NAME                  AGE
ascp-test-secrets-2   8s

# 詳細
$ kubectl describe secretproviderclass ascp-test-secrets-2
```
Deploymentの作成

```bash
$ kubectl apply -f ${CONTAINER_PROJECT_ROOT}/scripts/secrets-manager/test/tmp/deployment_2.yaml

# podの確認
$ kubectl get po
NAME                                     READY   STATUS    RESTARTS   AGE
ascp-test-deployment-1-995f98fd7-j4ntx   1/1     Running   0          7s

# ボリュームのマウント状態の確認
$ kubectl get secretproviderclasspodstatus
NAME                                                                 AGE
ascp-test-deployment-2-6f77b87997-pvbjv-default-ascp-test-secrets-2   4m38s

# ボリュームのマウント状態の詳細 (<pod name>-<namespace>-<secretproviderclass name>)
$ kubectl describe secretproviderclasspodstatus  ascp-test-deployment-2-6f77b87997-pvbjv-default-ascp-test-secrets-2

$ kubectl exec -ti ascp-test-deployment-2-6f77b87997-pvbjv -- printenv DB_SECRET
{"username":"hogehoge", "password":"piyopiyo"}

# SecretsManagerの中身を確認 (シークレット名の "/" は "_" に変換される)
#$ kubectl exec -ti ascp-test-deployment-2-6f77b87997-pvbjv -- cat /mnt/secrets-store/_baseport_prd_ascp-test
#{"username":"hogehoge", "password":"piyopiyo"}
#
#$ kubectl exec -ti ascp-test-deployment-2-6f77b87997-pvbjv -- cat /k8s-secret/db_secret
#{"username":"hogehoge", "password":"piyopiyo"}
```

削除

```bash
$ kubectl delete -f ${CONTAINER_PROJECT_ROOT}/scripts/secrets-manager/test/tmp/deployment_2.yaml
$ kubectl delete -f ${CONTAINER_PROJECT_ROOT}/scripts/secrets-manager/test/tmp/spc_2.yaml
```
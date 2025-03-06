# 参考
- [Kubernetes における永続ストレージ | Amazon Web Services ブログ](https://aws.amazon.com/jp/blogs/news/persistent-storage-for-kubernetes/)
- [Amazon EFS CSI dynamic provisioningの御紹介 | Amazon Web Services ブログ](https://aws.amazon.com/jp/blogs/news/amazon-efs-csi-dynamic-provisioning/)
- [installation - aws-efs-csi-driver | GitHub](https://github.com/kubernetes-sigs/aws-efs-csi-driver?tab=readme-ov-file#installation)

# デプロイ

```bash
# StorageClass作成
$ kubectl apply -f ${PROJECT_DIR}/plugin/efs/resources/storageclass-common-01.yaml
storageclass.storage.k8s.io/efs-sc created

# 確認
$ kubectl get sc
NAME     PROVISIONER             RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION   AGE
efs-sc   efs.csi.aws.com         Delete          Immediate              false                  22s
gp2      kubernetes.io/aws-ebs   Delete          WaitForFirstConsumer   false                  13d
```

# 動作確認 (動的プロビジョニング)

StorageClassの `parameters.basePath` `parameters.subPathPattern` `parameters.ensureUniqueDirectory` の設定で構成されるマウントポイントがPVCで一意になるならPVCを削除しても同じパスがマウントされる。

- `parameters.basePath`  
動的プロビジョニング作成されるアクセスポイントのパス
- `parameters.subPathPattern`  
動的プロビジョニングで作成される各アクセスポイントのサブパス
- `parameters.ensureUniqueDirectory`  
動的プロビジョニングで作成される各アクセスポイントのサブパスにUIDを追加する (重複回避)
  - trueだとマウントパスは `/dynamic_provisioning/pvcネームスペース名/pvc名-f9ab375a-4da3-4c4a-a748-391a6da20a91` となる
  - falseだとマウントパスは `/dynamic_provisioning/pvcネームスペース名/pvc名` となる


```bash
# pvc, podの作成
$ kubectl apply -f ${PROJECT_DIR}/plugin/efs/sample/dynamic_provisioning.yaml

# pvcの確認
$ kubectl get pvc

# pvcの詳細
$ kubectl describe pvc efs-pvc

# pvの確認
$ kubectl get pv
```

k9sでpodにログイン

```bash
# efsに出力されているログの確認
$ tail -f /data/out
Tue Jul 9 09:04:59 UTC 2024
Tue Jul 9 09:05:04 UTC 2024
Tue Jul 9 09:05:09 UTC 2024
Tue Jul 9 09:05:14 UTC 2024
Tue Jul 9 09:05:19 UTC 2024

# /dataにマウントされていることを確認
$ df -h
Filesystem      Size  Used Avail Use% Mounted on
overlay          20G  5.3G   15G  27% /
tmpfs            64M     0   64M   0% /dev
127.0.0.1:/     8.0E     0  8.0E   0% /data
/dev/nvme0n1p1   20G  5.3G   15G  27% /etc/hosts
shm              64M     0   64M   0% /dev/shm
tmpfs           3.3G   12K  3.3G   1% /run/secrets/kubernetes.io/serviceaccount
tmpfs           1.9G     0  1.9G   0% /proc/acpi
tmpfs           1.9G     0  1.9G   0% /sys/firmware

# ログアウト
$ exit
```

```bash
# k9sでpodを削除
k9s


# 再デプロイ
$ kubectl apply -f ${PROJECT_DIR}/plugin/efs/sample/dynamic_provisioning.yaml
```

リソースの削除

```bash
$ kubectl delete -f ${PROJECT_DIR}/plugin/efs/sample/dynamic_provisioning.yaml
```

# 動作確認 (静的プロビジョニング)

こちらは動的プロビジョニングと異なり、あらかじめPVをマニフェストで定義しておく  

PersistentVolumeの `csi.volumeHandle` でマウントパスを指定することで、PV, PVCを削除しても同じディレクトリにマウントできる。(ただし、マウントパスはあらかじめ作成しておく必要がある)


```bash
$ kubectl apply -f ${PROJECT_DIR}/plugin/efs/sample/static_provisioning.yaml

# 一回削除
# こちらのバグの問題でファイナライザを削除しないと消せない
# https://github.com/kubernetes-sigs/aws-efs-csi-driver/issues/1207
$ kubectl delete -f ${PROJECT_DIR}/plugin/efs/sample/static_provisioning.yaml

# 再作成されると同じボリュームがマウントされている
$ kubectl apply -f ${PROJECT_DIR}/plugin/efs/sample/static_provisioning.yaml
```


# デバッグ

```bash
# コントローラのログ確認
$ kubectl logs -f -n kube-system -l app.kubernetes.io/name=aws-efs-csi-driver,app=efs-csi-controller

# pvc, scの詳細(Events)
$ kubectl describe pvc efs-pvc
$ kubectl describe sc efs-sc
```


# 削除

```bash
$ kubectl delete -f ${PROJECT_DIR}/plugin/efs/sc.yaml
```
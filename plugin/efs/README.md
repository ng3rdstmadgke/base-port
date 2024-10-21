# 参考
- [Kubernetes における永続ストレージ | Amazon Web Services ブログ](https://aws.amazon.com/jp/blogs/news/persistent-storage-for-kubernetes/)
- [Amazon EFS CSI dynamic provisioningの御紹介 | Amazon Web Services ブログ](https://aws.amazon.com/jp/blogs/news/amazon-efs-csi-dynamic-provisioning/)
- [installation - aws-efs-csi-driver | GitHub](https://github.com/kubernetes-sigs/aws-efs-csi-driver?tab=readme-ov-file#installation)

# デプロイ

```bash
# ${CONTAINER_PROJECT_ROOT}/plugin/efs/tmp/sc.yaml の作成
${CONTAINER_PROJECT_ROOT}/plugin/efs/setup.sh

# StorageClass作成
$ kubectl apply -f ${CONTAINER_PROJECT_ROOT}/plugin/efs/tmp/sc.yaml
storageclass.storage.k8s.io/efs-sc created

# 確認
$ kubectl get sc
NAME     PROVISIONER             RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION   AGE
efs-sc   efs.csi.aws.com         Delete          Immediate              false                  22s
gp2      kubernetes.io/aws-ebs   Delete          WaitForFirstConsumer   false                  13d
```

# 動作確認 (動的プロビジョニング)

```bash
# pvc, podの作成
$ kubectl apply -f ${CONTAINER_PROJECT_ROOT}/plugin/efs/sample/dynamic_provisioning.yaml

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

k9sでpodを削除して再作成すると同じストレージをマウントできる。  
※ PVCを消してしまうとストレージの内容は失われる  

```bash
# k9sでpodを削除
k9s


# 再デプロイ
$ kubectl apply -f ${CONTAINER_PROJECT_ROOT}/plugin/efs/sample/dynamic_provisioning.yaml
```

リソースの削除

```bash
$ kubectl delete -f ${CONTAINER_PROJECT_ROOT}/plugin/efs/sample/dynamic_provisioning.yaml
```

# 動作確認 (静的プロビジョニング)

こちらは動的プロビジョニングと異なり、 
PersistentVolumeの `spec.persistentVolumeReclaimPolicy` が `Retain` なのでPVCが削除されてもPVは残る。  
ただし、PVCを再作成しても同じPVは利用されない

```bash
$ kubectl apply -f ${CONTAINER_PROJECT_ROOT}/plugin/efs/sample/static_provisioning.yaml

# 一回削除
$ kubectl delete -f ${CONTAINER_PROJECT_ROOT}/plugin/efs/sample/static_provisioning.yaml

# 再作成されると同じボリュームがマウントされている
$ kubectl apply -f ${CONTAINER_PROJECT_ROOT}/plugin/efs/sample/static_provisioning.yaml
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
$ kubectl delete -f ${CONTAINER_PROJECT_ROOT}/plugin/efs/sc.yaml
```
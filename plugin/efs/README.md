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

# 動作確認

```bash
# pvc, podの作成
$ kubectl apply -f ${CONTAINER_PROJECT_ROOT}/plugin/efs/sample/pvc_pod.yaml

# pvcの確認
$ kubectl get pvc
NAME      STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   VOLUMEATTRIBUTESCLASS   AGE
efs-pvc   Bound    pvc-ccd02133-a89e-47a4-ad3d-9e59f62a7f49   5Gi        RWX            efs-sc         <unset>                 10m

# pvcの詳細
$ kubectl describe pvc efs-pvc
Name:          efs-pvc
Namespace:     default
StorageClass:  efs-sc
Status:        Bound
Volume:        pvc-4bd29497-4c67-4eec-af6e-d898df48527d
Labels:        <none>
Annotations:   pv.kubernetes.io/bind-completed: yes
               pv.kubernetes.io/bound-by-controller: yes
               volume.beta.kubernetes.io/storage-provisioner: efs.csi.aws.com
               volume.kubernetes.io/storage-provisioner: efs.csi.aws.com
Finalizers:    [kubernetes.io/pvc-protection]
Capacity:      5Gi
Access Modes:  RWX
VolumeMode:    Filesystem
Used By:       efs-app
Events:
  Type    Reason                 Age                From                                                                                     Message
  ----    ------                 ----               ----                                                                                     -------
  Normal  ExternalProvisioning   68s (x2 over 68s)  persistentvolume-controller                                                              Waiting for a volume to be created either by the external provisioner 'efs.csi.aws.com' or manually by the system administrator. If volume creation is delayed, please verify that the provisioner is running and correctly registered.
  Normal  Provisioning           68s                efs.csi.aws.com_efs-csi-controller-55c9f799f-n6vqh_d1ab6d7e-0a1c-4849-a4b3-e0acbe6a59c0  External provisioner is provisioning volume for claim "default/efs-pvc"
  Normal  ProvisioningSucceeded  68s                efs.csi.aws.com_efs-csi-controller-55c9f799f-n6vqh_d1ab6d7e-0a1c-4849-a4b3-e0acbe6a59c0  Successfully provisioned volume pvc-4bd29497-4c67-4eec-af6e-d898df48527d

# pvの確認
$ kubectl get pv
NAME                                       CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM             STORAGECLASS   VOLUMEATTRIBUTESCLASS   REASON   AGE
pvc-ccd02133-a89e-47a4-ad3d-9e59f62a7f49   5Gi        RWX            Delete           Bound    default/efs-pvc   efs-sc         <unset>                          2m6s

# efsに出力されているログの確認
$ kubectl exec efs-app -- tail -n5 /data/out
Tue Jul 9 09:04:59 UTC 2024
Tue Jul 9 09:05:04 UTC 2024
Tue Jul 9 09:05:09 UTC 2024
Tue Jul 9 09:05:14 UTC 2024
Tue Jul 9 09:05:19 UTC 2024

# /dataにマウントされていることを確認
$ kubectl exec efs-app -- df -h
Filesystem      Size  Used Avail Use% Mounted on
overlay          20G  5.3G   15G  27% /
tmpfs            64M     0   64M   0% /dev
127.0.0.1:/     8.0E     0  8.0E   0% /data
/dev/nvme0n1p1   20G  5.3G   15G  27% /etc/hosts
shm              64M     0   64M   0% /dev/shm
tmpfs           3.3G   12K  3.3G   1% /run/secrets/kubernetes.io/serviceaccount
tmpfs           1.9G     0  1.9G   0% /proc/acpi
tmpfs           1.9G     0  1.9G   0% /sys/firmware

# サンプルpod削除
$ kubectl delete -f ${CONTAINER_PROJECT_ROOT}/plugin/efs/sample/pvc_pod.yaml
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
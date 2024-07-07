# 参考

- [HorizontalPodAutoscaler Walkthrough | Kubernetes](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale-walkthrough/#run-and-expose-php-apache-server)
- [Kuberentesの水平オートスケール(HPA v2) | Qiita](https://qiita.com/shmurata/items/e6bd8c56f3e4f9a8e384)
- [HorizontalPodAutoscaler API Reference](https://kubernetes.io/docs/reference/kubernetes-api/workload-resources/horizontal-pod-autoscaler-v2/)

# metrics-serverの導入確認

```bash
$ kubectl get deployment metrics-server -n kube-system
NAME             READY   UP-TO-DATE   AVAILABLE   AGE
metrics-server   1/1     1            1           50s
```

# Horizontal Pod Autoscaler テストアプリケーションを実行する
https://docs.aws.amazon.com/ja_jp/eks/latest/userguide/horizontal-pod-autoscaler.html#hpa-sample-app

## 


```bash
# オートスケール対象のDeploymentを作成
$ scripts/hpa/test/apply-php-apache.sh
```

## オートスケールの作成


```bash
# HorizontalPodAutoscalerを作成
# CLIで作成することも可能
# $ kubectl autoscale deployment php-apache --cpu-percent=50 --min=1 --max=10
$ scripts/hpa/test/apply-hpa.sh
```

確認

```bash
# 作成されたhpaの現在のステータスを確認
$ kubectl get hpa
NAME         REFERENCE               TARGETS       MINPODS   MAXPODS   REPLICAS   AGE
php-apache   Deployment/php-apache   cpu: 0%/50%   1         10        1          18s


# 詳細な設定とステータスの確認
$ kubectl get hpa php-apache -o yaml
```

## 負荷をかけてオートスケールの動作を確認


```bash
# hpaのステータスをwatch
$ kubectl get hpa php-apache --watch
NAME         REFERENCE               TARGETS       MINPODS   MAXPODS   REPLICAS   AGE
php-apache   Deployment/php-apache   cpu: 0%/50%   1         10        1          95s


# php-apacheコンテナにアクセスを投げまくるコンテナを起動 (スケールアウト)
$ kubectl run -i --tty load-generator-1 --rm --image=busybox:1.28 --restart=Never -- /bin/sh -c "while sleep 0.01; do wget -q -O- http://php-apache; done"
$ kubectl run -i --tty load-generator-2 --rm --image=busybox:1.28 --restart=Never -- /bin/sh -c "while sleep 0.01; do wget -q -O- http://php-apache; done"

# load-generatorコンテナを停止 (スケールイン)
```


# 削除

```bash
kubectl delete hpa php-apache
kubectl delete deployment php-apache
```
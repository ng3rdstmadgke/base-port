#!/bin/bash

set -ex

SCRIPT_DIR=$(cd $(dirname $0); pwd)
cd $SCRIPT_DIR


# Kuberentesの水平オートスケール(HPA v2) | Qiita:
# - https://qiita.com/shmurata/items/e6bd8c56f3e4f9a8e384
# HorizontalPodAutoscaler API Reference
# - https://kubernetes.io/docs/reference/kubernetes-api/workload-resources/horizontal-pod-autoscaler-v2/
# Run and expose php-apache server - HorizontalPodAutoscaler Walkthrough
# - https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale-walkthrough/#run-and-expose-php-apache-server
cat <<EOF | kubectl apply -f -
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: php-apache
spec:  # https://kubernetes.io/docs/reference/kubernetes-api/workload-resources/horizontal-pod-autoscaler-v2/#HorizontalPodAutoscalerSpec
  # スケール対象のリソースの種類と名前を指定
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: php-apache
  minReplicas: 1
  maxReplicas: 10
  metrics:  # 必要なレプリカ数を決定するためのメトリクスのリスト
  - type: Resource  # ContainerResource, External, Object, Pods, Resource のいずれかを指定
    resource:  # type が Resource の場合の設定項目
      name: cpu  # メトリクス名。他にはmemoryが指定可能
      target:  # メトリクスの目標値。この目標値を維持すようにレプリカ数が調整される。
        type: Utilization  # Utilization(使用率), Value(値), AverageValue(平均値) のいずれかを指定
        averageUtilization: 50  # メトリクスの目標値(全ポッドの平均値(%))。 resourceメトリックソースタイプに対してのみ有効。
EOF

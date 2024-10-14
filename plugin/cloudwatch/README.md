- [CloudWatch Logs へログを送信する DaemonSet として Fluent Bit を設定する | AWS](https://docs.aws.amazon.com/ja_jp/AmazonCloudWatch/latest/monitoring/Container-Insights-setup-logs-FluentBit.html)

```bash
cd plugin/cloudwatch
```
# ネームスペースの作成

- [cloudwatch-namespace.yaml](https://raw.githubusercontent.com/aws-samples/amazon-cloudwatch-container-insights/latest/k8s-deployment-manifest-templates/deployment-mode/daemonset/container-insights-monitoring/cloudwatch-namespace.yaml)

```bash
kubectl apply -f cloudwatch-namespace.yaml
```

# ConfigMapの作成

```bash
ClusterName=baseport-prd
RegionName=ap-northeast-1
FluentBitHttpPort='2020'
# OFFならデプロイ後の新しいログのみ収集。ONなら現存するすべてのログを収集
FluentBitReadFromHead='Off'
[[ ${FluentBitReadFromHead} = 'On' ]] && FluentBitReadFromTail='Off'|| FluentBitReadFromTail='On'
[[ -z ${FluentBitHttpPort} ]] && FluentBitHttpServer='Off' || FluentBitHttpServer='On'
kubectl create configmap fluent-bit-cluster-info \
--from-literal=cluster.name=${ClusterName} \
--from-literal=http.server=${FluentBitHttpServer} \
--from-literal=http.port=${FluentBitHttpPort} \
--from-literal=read.head=${FluentBitReadFromHead} \
--from-literal=read.tail=${FluentBitReadFromTail} \
--from-literal=logs.region=${RegionName} -n amazon-cloudwatch
```

# Fluent Bit daemonset のデプロイ

- [fluent-bit.yaml](https://raw.githubusercontent.com/aws-samples/amazon-cloudwatch-container-insights/latest/k8s-deployment-manifest-templates/deployment-mode/daemonset/container-insights-monitoring/fluent-bit/fluent-bit.yaml)

※ ノードロールに CloudWatch Logs への書き込み権限を付与しておく必要がある ( `CloudWatchLogsFullAccess` )


```bash
kubectl apply -f fluent-bit.yaml

# fluent-bitというdaemon setが存在しているかを確認
kubectl get daemonset -n amazon-cloudwatch

# ノードごとに fluent-bit という pod が立ち上がっていることを確認 
kubectl get po -n amazon-cloudwatch 
```

# ログの確認

- `/aws/containerinsights/<Cluster_Name>/application`
- `/aws/containerinsights/<Cluster_Name>/host`
- `/aws/containerinsights/<Cluster_Name>/dataplane`
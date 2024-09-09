/**
 * Kubecostのインストール
 * - Kubecost をインストールし、ダッシュボードにアクセスする | AWS:
 *   https://docs.aws.amazon.com/ja_jp/eks/latest/userguide/cost-monitoring-kubecost.html
 * - インストールには aws-ebs-csi-driver が必要
 *   https://docs.aws.amazon.com/ja_jp/eks/latest/userguide/ebs-csi.html
 */

//helm_release: https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release
resource "helm_release" "kubecost" {
  name       = "kubecost"
  chart      = "oci://public.ecr.aws/kubecost/cost-analyzer"
  // バージョンの確認: https://gallery.ecr.aws/kubecost/cost-analyzer
  version    = "2.3.5"
  namespace  = "kubecost"
  create_namespace = true

  // valuesのひな型: https://github.com/NVIDIA/k8s-device-plugin/blob/v0.16.2/deployments/helm/nvidia-device-plugin/values.yaml
  values = [
    // wget https://raw.githubusercontent.com/kubecost/cost-analyzer-helm-chart/develop/cost-analyzer/values-eks-cost-monitoring.yaml
    file("${path.module}/values-eks-cost-monitoring.yaml"),
  ]
}

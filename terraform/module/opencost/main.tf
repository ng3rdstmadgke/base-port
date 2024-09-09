/**
 * OpenCost
 * - Install | OpenCost: https://www.opencost.io/docs/installation/helm
 * - OpenCost | Github: https://github.com/opencost/opencost-helm-chart/tree/main/charts/opencost
 * - Install Prometheus | OpenCost: https://www.opencost.io/docs/installation/prometheus
 * - Prometheus - helm-charts | Github: https://github.com/prometheus-community/helm-charts/tree/main/charts/prometheus
 */
//helm_release: https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release
resource "helm_release" "opencost" {
  name       = "opencost"
  chart      = "opencost"
  repository = "https://opencost.github.io/opencost-helm-chart"
  // バージョンの確認: https://github.com/opencost/opencost-helm-chart/blob/main/charts/opencost/Chart.yaml
  version    = "1.42.0"
  namespace  = "opencost"
  create_namespace = true

  # 設定値: https://github.com/opencost/opencost-helm-chart/blob/main/charts/opencost/values.yaml
  values = [
    file("${path.module}/values.yaml"),
  ]
}
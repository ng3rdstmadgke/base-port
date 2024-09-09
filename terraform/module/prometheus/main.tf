/**
 * Prometheus
 *
 * - Install Prometheus | OpenCost: https://www.opencost.io/docs/installation/prometheus
 */
//helm_release: https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release
// https://github.com/prometheus-community/helm-charts/tree/main/charts/prometheus-operator-crds
resource "helm_release" "prometheus" {
  name       = "prometheus"
  chart      = "prometheus"
  repository = "https://prometheus-community.github.io/helm-charts"
  // バージョン確認: https://github.com/prometheus-community/helm-charts/pkgs/container/charts%2Fprometheus
  version    = "25.27.0"
  namespace  = "prometheus-system"
  create_namespace = true

  # 設定値: https://github.com/prometheus-community/helm-charts/blob/main/charts/prometheus/values.yaml
  values = [
    // wget https://raw.githubusercontent.com/opencost/opencost/develop/kubernetes/prometheus/extraScrapeConfigs.yaml
    file("${path.module}/extraScrapeConfigs.yaml"),
  ]
}

// https://github.com/prometheus-community/helm-charts/tree/main/charts/prometheus-operator-crds
resource "helm_release" "prometheus_operator_crds" {
  name       = "prometheus-operator-crds"
  chart      = "prometheus-operator-crds"
  repository = "https://prometheus-community.github.io/helm-charts"
  // バージョン確認: https://github.com/prometheus-community/helm-charts/blob/main/charts/prometheus-operator-crds/Chart.yaml
  version    = "v14.0.0"
}

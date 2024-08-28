/**
 * NVIDIA Device PluginをHelmでインストール
 * NVIDIA/k8s-device-plugin | GitHub: https://github.com/NVIDIA/k8s-device-plugin
 *   helmでインストール: https://github.com/NVIDIA/k8s-device-plugin/tree/v0.16.2?tab=readme-ov-file#deployment-via-helm
 */

//helm_release: https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release
resource "helm_release" "nvidia_device_plugin" {
  repository = "https://nvidia.github.io/k8s-device-plugin"
  name       = "nvdp"
  chart      = "nvidia-device-plugin"
  // 最新バージョン: helm search repo nvdp --devel
  version    = "0.16.2"
  namespace  = "nvidia-device-plugin"
  create_namespace = true

  // valuesのひな型: https://github.com/NVIDIA/k8s-device-plugin/blob/v0.16.2/deployments/helm/nvidia-device-plugin/values.yaml
  values = [
    file("${path.module}/values.yaml"),
  ]
}

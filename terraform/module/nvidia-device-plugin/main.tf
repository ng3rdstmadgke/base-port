/**
 * NVIDIA Device PluginをHelmでインストール
 *
 * NVIDIA/k8s-device-plugin | GitHub: https://github.com/NVIDIA/k8s-device-plugin
 */

//helm_release - helm - terraform: https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release
resource "helm_release" "nvidia_device_plugin" {
  repository = "https://nvidia.github.io/k8s-device-plugin"
  name       = "nvdp"
  chart      = "nvidia-device-plugin"
  // 最新バージョン: helm search repo nvdp --devel
  version    = "0.16.2"
  namespace  = "nvidia-device-plugin"
  create_namespace = true

  set {
    // NVIDIA GPU Feature Discoveryを有効にする
    // 有効化することで、NodeにGPUの情報を自動的にラベル付けし有効化する
    // https://github.com/NVIDIA/k8s-device-plugin?tab=readme-ov-file#deploying-with-gpu-feature-discovery-for-automatic-node-labels
    name  = "gfd.enabled"
    value = true
  }
}
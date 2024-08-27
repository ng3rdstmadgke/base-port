/**
 * NVIDIA Device PluginをHelmでインストール
 * NVIDIA/k8s-device-plugin | GitHub: https://github.com/NVIDIA/k8s-device-plugin
 *
 * NOTE: helmでインストールするとうまくいかないので、AWS公式のやり方でインストール
 *       https://docs.aws.amazon.com/ja_jp/eks/latest/userguide/eks-optimized-ami.html#gpu-ami
 */

resource "null_resource" "nvidia_device_plugin" {
  triggers = {
    # VERSION=0.16.2
    # wget https://raw.githubusercontent.com/NVIDIA/k8s-device-plugin/v${VERSION}/deployments/static/nvidia-device-plugin.yml
    file_hash = filebase64sha256("${path.module}/nvidia-device-plugin.yml")
  }
  
  provisioner "local-exec" {
    command = "kubectl apply -f ${path.module}/nvidia-device-plugin.yml > nvidia-device-plugin-install.log 2>&1"
  }

  provisioner "local-exec" {
    command = "kubectl delete -n -f ${path.module}/nvidia-device-plugin.yml > nvidia-device-plugin-install.log 2>&1"
    when    = destroy
  }
}

/*
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
*/

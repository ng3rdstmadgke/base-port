resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"
  }

  lifecycle {
    ignore_changes = all
  }
}

resource "null_resource" "run_script" {
  triggers = {
    # wget https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
    file_hash = filebase64sha256("${path.module}/install.yaml")
  }
  
 provisioner "local-exec" {
    command = "kubectl apply -n argocd -f ${path.module}/install.yaml > argocd_install.log"
  }

  depends_on = [ kubernetes_namespace.argocd ]
}
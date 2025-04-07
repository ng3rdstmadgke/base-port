variable app_name {
  type = string
  description = "アプリケーション名"
}
variable stage {
  type = string
  description = "ステージ名"
}
variable project_dir {
  type = string
  description = "プロジェクトのルートディレクトリ"
}
variable eks_oidc_issure_url {
  type = string
  description = "EKS OIDC issuer URL"
}

data "aws_caller_identity" "self" { }
data "aws_region" "self" {}

locals {
  cluster_name = "${var.app_name}-${var.stage}"
  account_id = data.aws_caller_identity.self.account_id
  region = data.aws_region.self.name
  oidc_provider = replace(var.eks_oidc_issure_url, "https://", "")
  service_account = "karpenter"
  namespace = "kube-system"
}

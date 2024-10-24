variable app_name {}
variable stage {}
variable eks_oidc_issure_url {}

data "aws_caller_identity" "self" { }
data "aws_region" "self" {}

locals {
  cluster_name = "${var.app_name}-${var.stage}"
  account_id = data.aws_caller_identity.self.account_id
  region = data.aws_region.self.name
  oidc_provider = replace(var.eks_oidc_issure_url, "https://", "")
  namespace = "kube-system"
  service_account = "s3-csi-driver-sa"
}
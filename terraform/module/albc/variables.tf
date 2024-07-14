variable app_name {}
variable stage {}
variable vpc_id {}
variable eks_oidc_issure_url {}

variable ingress_dev_cidr_blocks {
  type = list(string)
  default = ["0.0.0.0/0"]
}

variable ingress_prd_cidr_blocks {
  type = list(string)
  default = ["0.0.0.0/0"]
}

data "aws_caller_identity" "self" { }
data "aws_region" "self" {}

locals {
  cluster_name = "${var.app_name}-${var.stage}"
  account_id = data.aws_caller_identity.self.account_id
  region = data.aws_region.self.name
  oidc_provider = replace(var.eks_oidc_issure_url, "https://", "")
}

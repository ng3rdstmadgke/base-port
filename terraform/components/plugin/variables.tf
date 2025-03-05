variable app_name {
  type = string
  description = "アプリケーション名"
}

variable stage {
  type = string
  description = "ステージ名"
}

variable tfstate_region {
  type = string
  description = "tfstateが保存されているリージョン"
}

variable tfstate_bucket {
  type = string
  description = "tfstateが保存されているS3バケット"
}


variable "albc_ingress_internal_cidr_blocks" {
  type = list(string)
  description = "内部アクセス用ALBにへのアクセスを許可するCIDRブロック"
}
variable "albc_ingress_dev_cidr_blocks" {
  type = list(string)
  description = "開発用のALBにへのアクセスを許可するCIDRブロック"
}

locals {
  vpc_id = data.terraform_remote_state.network.outputs.vpc_id
  cluster_name = data.terraform_remote_state.cluster.outputs.eks_cluster_name
  cluster_endpoint = data.terraform_remote_state.cluster.outputs.eks_cluster_endpoint
  cluster_certificate_authority_data = data.terraform_remote_state.cluster.outputs.eks_cluster_certificate_authority_data
  cluster_identity_oidc_issure = data.terraform_remote_state.cluster.outputs.eks_cluster_identity_oidc_issure
  cluster_auth_token = data.terraform_remote_state.cluster.outputs.eks_cluster_auth_token
}

data terraform_remote_state "network" {
  backend = "s3"

  config = {
    region = var.tfstate_region
    bucket = var.tfstate_bucket
    key    = "${var.app_name}/${var.stage}/network/terraform.tfstate"
  }
}

data terraform_remote_state "cluster" {
  backend = "s3"

  config = {
    region = var.tfstate_region
    bucket = var.tfstate_bucket
    key    = "${var.app_name}/${var.stage}/cluster/terraform.tfstate"
  }
}
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


locals {
  project_dir = data.terraform_remote_state.base.outputs.project_dir
  vpc_id = data.terraform_remote_state.network.outputs.vpc_id
  private_subnet_ids = data.terraform_remote_state.network.outputs.private_subnet_ids
  cluster_name = data.terraform_remote_state.cluster.outputs.eks_cluster_name
  cluster_identity_oidc_issure = data.terraform_remote_state.cluster.outputs.eks_cluster_identity_oidc_issure
  cluster_primary_sg_id = data.terraform_remote_state.cluster.outputs.eks_cluster_primary_sg_id
}


data terraform_remote_state "cluster" {
  backend = "s3"

  config = {
    region = var.tfstate_region
    bucket = var.tfstate_bucket
    key    = "${var.app_name}/${var.stage}/cluster/terraform.tfstate"
  }
}

data terraform_remote_state "network" {
  backend = "s3"

  config = {
    region = var.tfstate_region
    bucket = var.tfstate_bucket
    key    = "${var.app_name}/${var.stage}/network/terraform.tfstate"
  }
}

data terraform_remote_state "base" {
  backend = "s3"

  config = {
    region = var.tfstate_region
    bucket = var.tfstate_bucket
    key    = "${var.app_name}/${var.stage}/base/terraform.tfstate"
  }
}

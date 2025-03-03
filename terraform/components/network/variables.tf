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


variable "vpc_cidr" {
  type = string
  description = "VPCのCIDR"
}

variable "private_subnets" {
  type = list(string)
  description = "プライベートサブネットのCIDR"
}

variable "public_subnets" {
  type = list(string)
  description = "パブリックサブネットのCIDR"
}

locals {
  cluster_name = data.terraform_remote_state.base.outputs.cluster_name
}

data terraform_remote_state "base" {
  backend = "s3"

  config = {
    region = var.tfstate_region
    bucket = var.tfstate_bucket
    key    = "${var.app_name}/${var.stage}/base/terraform.tfstate"
  }
}
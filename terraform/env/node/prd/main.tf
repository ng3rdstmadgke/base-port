terraform {
  required_version = "~> 1.8.5"

  backend "s3" {
    bucket = "tfstate-store-a5gnpkub"
    key    = "baseport/prd/node/terraform.tfstate"
    region = "ap-northeast-1"
    encrypt = true
  }

  required_providers {
    // AWS Provider: https://registry.terraform.io/providers/hashicorp/aws/latest/docs
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.55.0"
    }
  }
}

provider "aws" {
  region = "ap-northeast-1"
  default_tags {
    tags = {
      PROJECT = "BASEPORT_PRD",
    }
  }
}

variable "key_pair_name" {}
variable "allow_ssh_source_sg_ids" {
  type = list(string)
  default = []
}

locals {
  app_name = "baseport"
  stage = "prd"
  cluster_name = "${local.app_name}-${local.stage}"
}

module node_group_1 {
  source = "../../../module/node-group"
  app_name = local.app_name
  stage = local.stage
  node_group_name = "ng-1"
  key_pair_name = var.key_pair_name
  allow_ssh_source_sg_ids = var.allow_ssh_source_sg_ids
  // スポット料金: https://aws.amazon.com/jp/ec2/spot/pricing/
  instance_types = ["m6a.large", "m6a.xlarge", "c6a.xlarge"]
  desired_size = 1
}

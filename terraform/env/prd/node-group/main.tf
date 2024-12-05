terraform {
  required_version = "~> 1.8.5"

  backend "s3" {
    bucket = "tfstate-store-a5gnpkub"
    key    = "baseport/prd/node-group/terraform.tfstate"
    region = "ap-northeast-1"
    encrypt = true
  }

  required_providers {
    // AWS Provider: https://registry.terraform.io/providers/hashicorp/aws/latest/docs
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.80.0"
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

locals {
  app_name = "baseport"
  stage = "prd"
  cluster_name = "${local.app_name}-${local.stage}"
}

variable "key_pair_name" {}
variable "node_role_arn" {}

// Data Source: aws_eks_cluster
// https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/eks_cluster
data "aws_eks_cluster" "this" {
  name = local.cluster_name
}

/**
 * ノードグループ
 */
module default_node_group {
  source = "../../../module/node-group"
  app_name = local.app_name
  stage = local.stage
  node_group_name = "ng-common-01"
  key_pair_name = var.key_pair_name
  node_role_arn = var.node_role_arn
  // スポット料金: https://aws.amazon.com/jp/ec2/spot/pricing/
  instance_types = ["t3a.xlarge"]
  desired_size = 2
}

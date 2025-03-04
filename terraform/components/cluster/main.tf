terraform {
  required_version = "~> 1.10.3"

  backend "s3" {
    bucket = "tfstate-store-a5gnpkub"
    key    = "baseport/prd/cluster/terraform.tfstate"
    region = "ap-northeast-1"
    encrypt = true
  }

  required_providers {
    // AWS Provider: https://registry.terraform.io/providers/hashicorp/aws/latest/docs
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.84.0"
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


module eks {
  source = "../../module/eks"
  app_name = local.app_name
  stage = local.stage
  private_subnet_ids = var.private_subnet_ids
  cluster_version = "1.31"
  access_entries = var.access_entries
}

module efs {
  source = "../../module/efs"
  app_name = local.app_name
  stage = local.stage
  vpc_id = var.vpc_id
  private_subnets = var.private_subnet_ids
  eks_cluster_sg_id = module.eks.cluster.vpc_config[0].cluster_security_group_id
}
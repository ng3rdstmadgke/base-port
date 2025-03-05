terraform {
  required_version = "~> 1.10.3"

  backend "s3" {
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
  app_name = var.app_name
  stage = var.stage
  project_dir = local.project_dir
  private_subnet_ids = local.private_subnet_ids
  cluster_version = "1.31"
  access_entries = var.access_entries
}

// TODO: serviceに移動
module efs {
  source = "../../module/efs"
  app_name = var.app_name
  stage = var.stage
  vpc_id = local.vpc_id
  private_subnets = local.private_subnet_ids
  eks_cluster_sg_id = module.eks.cluster.vpc_config[0].cluster_security_group_id
}
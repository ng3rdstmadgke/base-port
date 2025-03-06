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

module "keycloak" {
  source = "../../module/keycloak"
  app_name = var.app_name
  stage = var.stage
  eks_oidc_issure_url = local.cluster_identity_oidc_issure
}

// TODO: serviceに移動
module efs_common_01 {
  source = "../../module/efs"
  app_name = var.app_name
  stage = var.stage
  name = "common-01"
  vpc_id = local.vpc_id
  private_subnets = local.private_subnet_ids
  eks_cluster_sg_id = local.cluster_primary_sg_id
  project_dir = local.project_dir
}
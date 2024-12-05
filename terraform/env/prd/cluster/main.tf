terraform {
  required_version = "~> 1.8.5"

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

module eks {
  source = "../../../module/eks"
  app_name = local.app_name
  stage = local.stage
  // ALBにアクセスする際のIPアドレス
  vpc_cidr = "10.32.0.0/16"
  private_subnets = [
    "10.32.1.0/24",
    "10.32.2.0/24",
    "10.32.3.0/24",
  ]
  public_subnets = [
    "10.32.101.0/24",
    "10.32.102.0/24",
    "10.32.103.0/24"
  ]
  cluster_version = "1.31"
  access_entries = var.access_entries
}

module efs {
  source = "../../../module/efs"
  app_name = local.app_name
  stage = local.stage
  vpc_id = module.eks.vpc.vpc_id
  private_subnets = module.eks.vpc.private_subnets
  eks_cluster_sg_id = module.eks.cluster.cluster_primary_security_group_id
}


/**
 * Fargateプロファイル
 */
#module test-fargate-profile {
#  source = "../../../module/fargate-profile"
#  profile_name = "test"
#  cluster_name = module.eks.cluster.cluster_name
#  private_subnets = module.eks.vpc.private_subnets
#  eks_fargate_pod_execution_role_arn = module.eks.eks_fargate_pod_execution_role_arn
#  selectors = [
#    {
#      namespace = "fargate-test"
#    }
#  ]
#}

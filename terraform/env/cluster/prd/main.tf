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

output "vpc_id" {
  value = module.eks.vpc_id
}


module eks {
  source = "../../../module/eks"
  app_name = "baseport"
  stage = "prd"
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
  cluster_version = "1.30"
}

module default-fargate-profile {
  source = "../../../module/fargate-profile"
  profile_name = "default_profile"
  cluster_name = module.eks.cluster_name
  private_subnets = module.eks.private_subnets
  eks_fargate_pod_execution_role_arn = module.eks.eks_fargate_pod_execution_role_arn
  selectors = [
    { namespace = "*" }
  ]
}
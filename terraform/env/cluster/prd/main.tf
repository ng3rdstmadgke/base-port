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
  value = module.eks.vpc.vpc_id
}

output "eks_cluster_sg_id" {
  value = module.eks.cluster.cluster_security_group_id
}

output "eks_node_sg_id" {
  value = module.eks.cluster.node_security_group_id
}

output "efs_id" {
  value = module.efs.efs_id
}

output "private_subnets" {
  value = module.eks.vpc.private_subnets
}

output "public_subnets" {
  value = module.eks.vpc.public_subnets
}

locals {
  app_name = "baseport"
  stage = "prd"
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
  cluster_version = "1.30"
}

module test-fargate-profile {
  source = "../../../module/fargate-profile"
  profile_name = "test"
  cluster_name = module.eks.cluster.cluster_name
  private_subnets = module.eks.vpc.private_subnets
  eks_fargate_pod_execution_role_arn = module.eks.eks_fargate_pod_execution_role_arn
  selectors = [
    {
      namespace = "fargate-test"
    }
  ]
}

module efs {
  source = "../../../module/efs"
  app_name = local.app_name
  stage = local.stage
  vpc_id = module.eks.vpc.vpc_id
  private_subnets = module.eks.vpc.private_subnets
  eks_cluster_sg_id = module.eks.cluster.cluster_security_group_id
}

/**
 * https://github.com/terraform-aws-modules/terraform-aws-eks/tree/v20.14.0/modules/eks-managed-node-group
 */
/*
module "group01" {
  source = "terraform-aws-modules/eks/aws//modules/eks-managed-node-group"
  name            = "${local.app_name}-${local.stage}-group-01"
  cluster_name    = module.eks.cluster.cluster_name
  cluster_version = module.eks.cluster.cluster_version

  subnet_ids = module.eks.vpc.private_subnets

  // eksモジュールの外でこのモジュールを利用する場合、以下の変数を指定する必要があります
  // これらを指定しないと、ノードのセキュリティグループが空になり、クラスタに参加できません
  cluster_primary_security_group_id = module.eks.cluster.cluster_primary_security_group_id
  vpc_security_group_ids            = [module.eks.cluster.node_security_group_id]

  // Note: `disk_size`, と `remote_access` は デフォルトlaunch templateを利用する場合のみ指定可能
  // このモジュールでは、セキュリティグループ、タグの伝播などをカスタマイズするために、デフォルトでカスタムlaunch templateを提供するようになっています
  // use_custom_launch_template = false
  // disk_size = 50
  //
  //  # Remote access cannot be specified with a launch template
  //  remote_access = {
  //    ec2_ssh_key               = module.key_pair.key_pair_name
  //    source_security_group_ids = [aws_security_group.remote_access.id]
  //  }

  min_size     = 1
  max_size     = 10
  desired_size = 1

  instance_types = ["t3.medium"]
  capacity_type  = "SPOT"

  //labels = {
  //  "nodegroup-type" = "some"
  //}
}
*/
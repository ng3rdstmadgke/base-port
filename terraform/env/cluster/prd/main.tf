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

/**
 * https://github.com/terraform-aws-modules/terraform-aws-eks/tree/v20.14.0/modules/eks-managed-node-group
 */
/*
module "eks_managed_node_group" {
  source = "terraform-aws-modules/eks/aws//modules/eks-managed-node-group"
  name            = "default"
  cluster_name    = module.eks.cluster_name
  cluster_version = module.eks.cluster_version

  subnet_ids = module.eks.subnet_ids

  // eksモジュールの外でこのモジュールを利用する場合、以下の変数を指定する必要があります
  // これらを指定しないと、ノードのセキュリティグループが空になり、クラスタに参加できません
  cluster_primary_security_group_id = module.eks.cluster_primary_security_group_id
  vpc_security_group_ids            = [module.eks.node_security_group_id]

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
}
 */
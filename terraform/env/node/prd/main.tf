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

/**
 * ノードグループ用追加SG (あってもなくてもいい)
 */
// Data Source: aws_eks_cluster
// https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/eks_cluster
data "aws_eks_cluster" "this" {
  name = local.cluster_name
}

resource "aws_security_group" "additional_node_sg" {
  name        = "${local.app_name}-${local.stage}-AdditionalNodeSecurityGroup"
  description = "additional security group for ${local.app_name}-${local.stage}"
  vpc_id      = data.aws_eks_cluster.this.vpc_config[0].vpc_id

  ingress {
    description = "Allow cluster SecurityGroup access."
    from_port   = 0
    to_port     = 0
    protocol    = "all"
    security_groups = [
      data.aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
    ]
  }

  ingress {
    description = "Allow self access."
    from_port   = 0
    to_port     = 0
    protocol    = "all"
    self        = true
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "all"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "${local.app_name}-${local.stage}-AdditionalNodeSecurityGroup"
    // karpenterでもSGを使いたいので、karpenterのDiscovery用にタグを追加
    "karpenter.sh/discovery" = local.cluster_name 

  }
}

module node_group_1 {
  source = "../../../module/node-group"
  app_name = local.app_name
  stage = local.stage
  node_group_name = "ng-1"
  key_pair_name = var.key_pair_name
  node_role_arn = "arn:aws:iam::674582907715:role/baseport-prd-EKSNodeRole"
  node_additional_sg_ids = [aws_security_group.additional_node_sg.id]
  // スポット料金: https://aws.amazon.com/jp/ec2/spot/pricing/
  instance_types = ["t3a.xlarge"]
  desired_size = 1
}

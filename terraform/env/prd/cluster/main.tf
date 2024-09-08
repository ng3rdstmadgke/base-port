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
      version = "~> 5.64.0"
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
  cluster_version = "1.30"
  access_entries = var.access_entries
}

/**
 * ノードグループ
 */
module default_node_group {
  source = "../../../module/node-group"
  app_name = local.app_name
  stage = local.stage
  node_group_name = "ng-default"
  key_pair_name = var.key_pair_name
  node_role_arn = module.eks.node_role_arn
  // スポット料金: https://aws.amazon.com/jp/ec2/spot/pricing/
  instance_types = ["t3a.xlarge"]
  desired_size = 1

  depends_on = [
    module.eks
  ]
}

/**
 * アドオン
 *
 * aws_eks_addon | Terraform
 * https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_addon
 */
resource "aws_eks_addon" "coredns" {
  cluster_name  = module.eks.cluster.cluster_name
  addon_name    = "coredns"
  addon_version = "v1.11.1-eksbuild.8"
  #configuration_values = jsonencode({
  #  computeType = "fargate"
  #})
  depends_on = [
    module.default_node_group
  ]
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name  = module.eks.cluster.cluster_name
  addon_name   = "kube-proxy"
  addon_version = "v1.30.0-eksbuild.3"
  depends_on = [
    module.default_node_group
  ]
}

resource "aws_eks_addon" "vpc_cni" {
  cluster_name  = module.eks.cluster.cluster_name
  addon_name   = "vpc-cni"
  addon_version = "v1.18.3-eksbuild.2"
  depends_on = [
    module.default_node_group
  ]
}

resource "aws_eks_addon" "eks_pod_identity_agent" {
  cluster_name  = module.eks.cluster.cluster_name
  addon_name   = "eks-pod-identity-agent"
  addon_version = "v1.3.0-eksbuild.1"
  depends_on = [
    module.default_node_group
  ]
}


module ebs_csi_controller_sa_role {
  source = "../../../module/irsa"
  app_name = local.app_name
  stage = local.stage
  cluster_name = module.eks.cluster.cluster_name
  role_name = "AmazonEksEbsCsiDriverRole"
  managed_policies = [
    "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  ]
  policies = {
    "EncryptEBSVolume" = jsonencode(
      {
        "Version": "2012-10-17",
        "Statement": [
          {
            "Effect": "Allow",
            "Action": [
              "kms:CreateGrant",
              "kms:ListGrants",
              "kms:RevokeGrant"
            ],
            "Resource": ["*"],
            "Condition": {
              "Bool": {
                "kms:GrantIsForAWSResource": "true"
              }
            }
          },
          {
            "Effect": "Allow",
            "Action": [
              "kms:Encrypt",
              "kms:Decrypt",
              "kms:ReEncrypt*",
              "kms:GenerateDataKey*",
              "kms:DescribeKey"
            ],
            "Resource": ["*"]
          }
        ]
      }
    )
  }
  namespace = "kube-system"
  service_account = "ebs-csi-controller-sa"
}

resource "aws_eks_addon" "aws_ebs_csi_driver" {
  cluster_name  = module.eks.cluster.cluster_name
  addon_name   = "aws-ebs-csi-driver"
  // バージョンの確認: aws eks describe-addon-versions --addon-name aws-ebs-csi-driver
  addon_version = "v1.34.0-eksbuild.1"
  // ebs-csi-driverのインストールにはIAMロールが必要: https://docs.aws.amazon.com/ja_jp/eks/latest/userguide/ebs-csi.html#csi-iam-role
  service_account_role_arn = module.ebs_csi_controller_sa_role.role_arn
  depends_on = [
    module.default_node_group
  ]
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

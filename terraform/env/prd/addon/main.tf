terraform {
  required_version = "~> 1.8.5"

  backend "s3" {
    bucket = "tfstate-store-a5gnpkub"
    key    = "baseport/prd/addon/terraform.tfstate"
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

// Data Source: aws_eks_cluster
// https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/eks_cluster
data "aws_eks_cluster" "this" {
  name = local.cluster_name
}

/**
 * アドオン
 *
 * aws_eks_addon | Terraform
 * https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_addon
 */
resource "aws_eks_addon" "coredns" {
  cluster_name  = data.aws_eks_cluster.this.id
  addon_name    = "coredns"
  addon_version = "v1.11.1-eksbuild.8"
  #configuration_values = jsonencode({
  #  computeType = "fargate"
  #})
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name  = data.aws_eks_cluster.this.id
  addon_name    = "kube-proxy"
  addon_version = "v1.30.0-eksbuild.3"
}

resource "aws_eks_addon" "vpc_cni" {
  cluster_name  = data.aws_eks_cluster.this.id
  addon_name    = "vpc-cni"
  addon_version = "v1.18.3-eksbuild.2"
}

resource "aws_eks_addon" "eks_pod_identity_agent" {
  cluster_name  = data.aws_eks_cluster.this.id
  addon_name    = "eks-pod-identity-agent"
  addon_version = "v1.3.0-eksbuild.1"
}


module ebs_csi_controller_sa_role {
  source = "../../../module/irsa"
  app_name = local.app_name
  stage = local.stage
  cluster_name = data.aws_eks_cluster.this.id
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
  cluster_name  = data.aws_eks_cluster.this.id
  addon_name    = "aws-ebs-csi-driver"
  // バージョンの確認: aws eks describe-addon-versions --addon-name aws-ebs-csi-driver
  addon_version = "v1.34.0-eksbuild.1"
  // ebs-csi-driverのインストールにはIAMロールが必要: https://docs.aws.amazon.com/ja_jp/eks/latest/userguide/ebs-csi.html#csi-iam-role
  service_account_role_arn = module.ebs_csi_controller_sa_role.role_arn
}
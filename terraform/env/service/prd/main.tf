terraform {
  required_version = "~> 1.8.5"

  backend "s3" {
    bucket = "tfstate-store-a5gnpkub"
    key    = "baseport/prd/service/terraform.tfstate"
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

locals {
  app_name = "baseport"
  stage = "prd"
  cluster_name = "${local.app_name}-${local.stage}"
}

// Data Source: aws_eks_cluster: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/eks_cluster
data "aws_eks_cluster" "this" {
  name = local.cluster_name
}

output "keycloak_ascp_role" {
  value = module.keycloak.keycloak_ascp_role
}

module "keycloak" {
  source = "../../../module/keycloak"
  app_name = local.app_name
  stage = local.stage
  // このコマンドで取得できる:
  // aws eks describe-cluster --name baseport-prd --output text --query "cluster.identity.oidc.issuer"
  eks_oidc_issure_url = data.aws_eks_cluster.this.identity[0].oidc[0].issuer
}
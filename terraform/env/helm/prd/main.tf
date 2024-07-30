terraform {
  required_version = "~> 1.8.5"

  backend "s3" {
    bucket = "tfstate-store-a5gnpkub"
    key    = "baseport/prd/helm/terraform.tfstate"
    #bucket = "kubernetes-work-tfstate"
    #key    = "eks-work-iac/prd/helm/terraform.tfstate"
    region = "ap-northeast-1"
    encrypt = true
  }

  required_providers {
    // AWS Provider: https://registry.terraform.io/providers/hashicorp/aws/latest/docs
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.55.0"
    }
    // Kubernetes Provider: https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.31.0"
    }
    // Helm Provider: https://registry.terraform.io/providers/hashicorp/helm/latest/docs
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.14.0"
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

variable "albc_ingress_dev_cidr_blocks" {
  type = list(string)
}

locals {
  app_name = "baseport"
  stage = "prd"
  cluster_name = "${local.app_name}-${local.stage}"
}

output "keda_operator_role_arn" {
  value = module.keda.keda_operator_role_arn
}

output "ascp_test_service_account" {
  value = module.secret_store_csi_driver.ascp_test_service_account
}

output "ingress_dev_sg" {
  value = module.albc.ingress_dev_sg
}

output "ingress_prd_sg" {
  value = module.albc.ingress_prd_sg
}

output "tools_ecr" {
  value = module.tools.ecr
}

output "tools_role" {
  value = module.tools.role
}


// Data Source: aws_eks_cluster
// https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/eks_cluster
data "aws_eks_cluster" "this" {
  name = local.cluster_name
}

// Data Source: aws_eks_cluster_auth
// https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/eks_cluster_auth
data "aws_eks_cluster_auth" "this" {
  name = local.cluster_name
}

// Kubernetes Provider: https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs
provider "kubernetes" {
  // kubenetesAPIのホスト名(URL形式)。KUBE_HOST環境変数で指定している値に基づく。
  host                   = data.aws_eks_cluster.this.endpoint
  // TLS認証用のPEMエンコードされたルート証明書のバンドル
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.this.token
}

// Helm Provider: https://registry.terraform.io/providers/hashicorp/helm/latest/docs
provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.this.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}

module albc {
  source = "../../../module/albc"
  app_name = local.app_name
  stage = local.stage
  # https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/eks_cluster#vpc_config
  vpc_id = data.aws_eks_cluster.this.vpc_config[0].vpc_id
  // このコマンドで取得できる:
  // aws eks describe-cluster --name baseport-prd --output text --query "cluster.identity.oidc.issuer"
  eks_oidc_issure_url = data.aws_eks_cluster.this.identity[0].oidc[0].issuer
  ingress_dev_cidr_blocks = var.albc_ingress_dev_cidr_blocks
}

module keda {
  source = "../../../module/keda"
  app_name = local.app_name
  stage = local.stage
  // このコマンドで取得できる:
  // aws eks describe-cluster --name baseport-prd --output text --query "cluster.identity.oidc.issuer"
  eks_oidc_issure_url = data.aws_eks_cluster.this.identity[0].oidc[0].issuer

}

module argocd {
  source = "../../../module/argocd"
}

module karpenter {
  source = "../../../module/karpenter"
  app_name = local.app_name
  stage = local.stage
  // このコマンドで取得できる:
  // aws eks describe-cluster --name baseport-prd --output text --query "cluster.identity.oidc.issuer"
  eks_oidc_issure_url = data.aws_eks_cluster.this.identity[0].oidc[0].issuer

}

module metrics_server {
  source = "../../../module/metrics-server"
}

module efs_csi_driver {
  source = "../../../module/efs-csi-driver"
  app_name = local.app_name
  stage = local.stage
  vpc_id = data.aws_eks_cluster.this.vpc_config[0].vpc_id
  eks_oidc_issure_url = data.aws_eks_cluster.this.identity[0].oidc[0].issuer
}

module secret_store_csi_driver {
  source = "../../../module/secret-store-csi-driver"
  app_name = local.app_name
  stage = local.stage
  eks_oidc_issure_url = data.aws_eks_cluster.this.identity[0].oidc[0].issuer
}

module tools {
  source = "../../../module/tools"
  app_name = local.app_name
  stage = local.stage
  eks_oidc_issure_url = data.aws_eks_cluster.this.identity[0].oidc[0].issuer
}
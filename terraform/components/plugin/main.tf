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


// Data Source: aws_eks_cluster_auth
// https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/eks_cluster_auth
data "aws_eks_cluster_auth" "this" {
  name = local.cluster_name
}

// Kubernetes Provider: https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs
provider "kubernetes" {
  // kubenetesAPIのホスト名(URL形式)。KUBE_HOST環境変数で指定している値に基づく。
  host                   = local.cluster_endpoint
  // TLS認証用のPEMエンコードされたルート証明書のバンドル
  cluster_ca_certificate = base64decode(local.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.this.token
}

// Helm Provider: https://registry.terraform.io/providers/hashicorp/helm/latest/docs
provider "helm" {
  kubernetes {
    host                   = local.cluster_endpoint
    cluster_ca_certificate = base64decode(local.cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}

module albc {
  source = "../../module/albc"
  app_name = var.app_name
  stage = var.stage
  # https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/eks_cluster#vpc_config
  vpc_id = local.vpc_id
  eks_oidc_issure_url = local.cluster_identity_oidc_issure
  ingress_dev_cidr_blocks = var.albc_ingress_dev_cidr_blocks
  ingress_internal_cidr_blocks = var.albc_ingress_internal_cidr_blocks
}

module keda {
  source = "../../module/keda"
  app_name = var.app_name
  stage = var.stage
  eks_oidc_issure_url = local.cluster_identity_oidc_issure
}

module argocd {
  source = "../../module/argocd"
}

module karpenter {
  source = "../../module/karpenter"
  app_name = var.app_name
  stage = var.stage
  eks_oidc_issure_url = local.cluster_identity_oidc_issure
}

module metrics_server {
  source = "../../module/metrics-server"
}

module efs_csi_driver {
  source = "../../module/efs-csi-driver"
  app_name = var.app_name
  stage = var.stage
  vpc_id = local.vpc_id
  eks_oidc_issure_url = local.cluster_identity_oidc_issure
}

module secret_store_csi_driver {
  source = "../../module/secret-store-csi-driver"
  app_name = var.app_name
  stage = var.stage
  project_dir = local.project_dir
  eks_oidc_issure_url = local.cluster_identity_oidc_issure
  eks_cluster_name = local.cluster_name
}

module tools {
  source = "../../module/tools"
  app_name = var.app_name
  stage = var.stage
  eks_oidc_issure_url = local.cluster_identity_oidc_issure
}

module nvidia_device_plugin {
  source = "../../module/nvidia-device-plugin"
}

#module kubecost {
#  source = "../../module/kubecost"
#}

module prometheus {
  source = "../../module/prometheus"
}

module opencost {
  source = "../../module/opencost"
  app_name = var.app_name
  stage = var.stage
  cluster_name = local.cluster_name
  datafeed_bucket_name = "spot-instance-datafeed-dm5b7kok4h"
  depends_on = [ module.prometheus ]
}

module s3_csi_driver {
  source = "../../module/mountpoint-s3-csi-driver"
  app_name = var.app_name
  stage = var.stage
  eks_oidc_issure_url = local.cluster_identity_oidc_issure
}
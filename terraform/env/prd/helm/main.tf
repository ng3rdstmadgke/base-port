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
      version = "~> 5.64.0"
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

module nvidia_device_plugin {
  source = "../../../module/nvidia-device-plugin"
}

#module kubecost {
#  source = "../../../module/kubecost"
#}

module prometheus {
  source = "../../../module/prometheus"
}

module opencost {
  source = "../../../module/opencost"
  app_name = local.app_name
  stage = local.stage
  cluster_name = local.cluster_name
  datafeed_bucket_name = "spot-instance-datafeed-dm5b7kok4h"
  depends_on = [ module.prometheus ]
}
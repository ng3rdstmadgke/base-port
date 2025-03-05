output "efs_id" {
  value = module.efs.efs_id
}

output "eks_cluster_name" {
  value = module.eks.cluster.name
}

output "eks_cluster_version" {
  value = module.eks.cluster.version
}

output "eks_cluster_endpoint" {
  value = module.eks.cluster.endpoint
}

output "eks_cluster_certificate_authority_data" {
  value = module.eks.cluster.certificate_authority[0].data
}

output "eks_cluster_service_cidr" {
  value = data.aws_eks_cluster.this.kubernetes_network_config[0].service_ipv4_cidr
}


output "eks_cluster_primary_sg_id" {
  value = module.eks.cluster.vpc_config[0].cluster_security_group_id
}

output "eks_cluster_sg_ids" {
  value = data.aws_eks_cluster.this.vpc_config[0].security_group_ids
}

output "eks_node_role_arn" {
  value = module.eks.node_role_arn
}

output "eks_cluster_identity_oidc_issure" {
  // 以下コマンドで取得できる:
  // aws eks describe-cluster --name baseport-prd --output text --query "cluster.identity.oidc.issuer"
  value = data.aws_eks_cluster.this.identity[0].oidc[0].issuer
}

output "eks_cluster_auth_token" {
  value = data.aws_eks_cluster_auth.this.token
  sensitive = true
}

// Data Source: aws_eks_cluster
// https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/eks_cluster
data "aws_eks_cluster" "this" {
  name = module.eks.cluster.name
}

// Data Source: aws_eks_cluster_auth
// https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/eks_cluster_auth
data "aws_eks_cluster_auth" "this" {
  name = module.eks.cluster.name
}
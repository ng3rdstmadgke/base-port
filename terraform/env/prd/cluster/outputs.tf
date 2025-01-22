output "vpc_id" {
  value = module.eks.vpc.vpc_id
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

data "aws_eks_cluster" "this" {
  name = module.eks.cluster.name
}
output "vpc_id" {
  value = module.eks.vpc.vpc_id
}

output "eks_cluster_sg_id" {
  value = module.eks.cluster.cluster_primary_security_group_id
}

output "eks_node_sg_id" {
  value = module.eks.cluster.cluster_primary_security_group_id
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

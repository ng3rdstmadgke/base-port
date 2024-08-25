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

output "eks_cluster_primary_sg_id" {
  value = module.eks.cluster.cluster_primary_security_group_id
}

output "eks_cluster_sg_ids" {
  value = join(" ", data.aws_eks_cluster.this.vpc_config[0].security_group_ids)
}


data "aws_eks_cluster" "this" {
  name = module.eks.cluster.cluster_name
}
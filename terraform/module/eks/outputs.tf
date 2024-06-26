output cluster_name {
  value = module.eks.cluster_name
}

output vpc_id {
  value = module.vpc.vpc_id
}

output private_subnets {
  value = module.vpc.private_subnets
}

output eks_fargate_pod_execution_role_arn {
  value = aws_iam_role.eks_fargate_pod_execution_role.arn
}
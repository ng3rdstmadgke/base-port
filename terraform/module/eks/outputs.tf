output eks {
  value = module.eks
}

output vpc {
  value = module.vpc
}

output eks_fargate_pod_execution_role_arn {
  value = aws_iam_role.eks_fargate_pod_execution_role.arn
}
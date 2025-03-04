output cluster {
  value = aws_eks_cluster.this
}

output fargate_pod_execution_role_arn {
  value = aws_iam_role.eks_fargate_pod_execution_role.arn
}

output node_role_arn {
  value = aws_iam_role.eks_node_role.arn
}
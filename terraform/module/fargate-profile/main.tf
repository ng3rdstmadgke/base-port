variable profile_name {}
variable cluster_name {}
variable private_subnets {}
variable eks_fargate_pod_execution_role_arn {}
variable selectors {
  type = list(any)
  default = [
    { namespace = "*" }
  ]
}
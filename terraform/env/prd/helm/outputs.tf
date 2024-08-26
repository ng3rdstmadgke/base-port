output karpenter_node_role_name {
  value = module.karpenter.karpenter_node_role.name
}

output "keda_operator_role_arn" {
  value = module.keda.keda_operator_role_arn
}

output "ascp_test_service_account" {
  value = module.secret_store_csi_driver.ascp_test_service_account
}

output "ingress_dev_sg" {
  value = module.albc.ingress_dev_sg
}

output "ingress_prd_sg" {
  value = module.albc.ingress_prd_sg
}

output "tools_ecr" {
  value = module.tools.ecr
}

output "tools_role" {
  value = module.tools.role
}
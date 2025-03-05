variable "albc_ingress_internal_cidr_blocks" {
  type = list(string)
}
variable "albc_ingress_dev_cidr_blocks" {
  type = list(string)
}

locals {
  app_name = "baseport"
  stage = "prd"
  cluster_name = "${local.app_name}-${local.stage}"
}

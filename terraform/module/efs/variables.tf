variable app_name {}
variable stage {}
variable vpc_id {}
variable private_subnets {
  type = list(string)
}
variable eks_cluster_sg_id {}

data "aws_caller_identity" "self" { }
data "aws_region" "self" {}
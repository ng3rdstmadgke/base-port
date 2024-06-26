variable "app_name" {}
variable "stage" {}
variable "cluster_version" {}
variable "vpc_cidr" {}
variable "private_subnets" {
  type = list(string)
}
variable "public_subnets" {
  type = list(string)
}

locals {
  cluster_name = "${var.app_name}-${var.stage}"
}

data "aws_caller_identity" "self" { }
data "aws_region" "self" {}

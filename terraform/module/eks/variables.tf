variable "app_name" {}
variable "stage" {}
variable "cluster_version" {}
variable "private_subnet_ids" {
  type = list(string)
}

variable access_entries {
  type = list(string)
  description = "arn:aws:iam::111111111111:user/xxxxxxxxxxxxxxxx or arn:aws:iam::111111111111:role/xxxxxxxxxxxxxxxxxxxxxxxxxxx"
}


locals {
  cluster_name = "${var.app_name}-${var.stage}"
}

data "aws_caller_identity" "self" { }
data "aws_region" "self" {}

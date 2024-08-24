variable app_name {}
variable stage {}
variable node_group_name {}
variable key_pair_name {}
variable node_role_arn {}

variable node_additional_sg_ids {
  type = list(string)
  default = []
}

variable instance_types {
  type = list(string)
  default = ["m6a.large"]
}

variable desired_size {
  type = number
  default = 1
}

variable capacity_type {
  type = string
  default = "SPOT"
}

// Data Source: aws_eks_cluster
// https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/eks_cluster
data "aws_eks_cluster" "this" {
  name = local.cluster_name
}

locals {
  cluster_name = "${var.app_name}-${var.stage}"
}

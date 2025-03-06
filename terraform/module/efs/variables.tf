variable app_name {
  type = string
}

variable stage {
  type = string
}

variable name {
  type = string
}

variable vpc_id {
  type = string
}

variable private_subnets {
  type = list(string)
}

variable eks_cluster_sg_id {
  type = string
}

variable project_dir {
  type = string
}
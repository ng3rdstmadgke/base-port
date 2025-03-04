variable key_pair_name {
  type = string
} 

variable access_entries {
  type = list(string)
  description = "arn:aws:iam::111111111111:user/xxxxxxxxxxxxxxxx or arn:aws:iam::111111111111:role/xxxxxxxxxxxxxxxxxxxxxxxxxxx"
}

variable vpc_id {
  type = string
}

variable private_subnet_ids {
  type = list(string)
}

locals {
  app_name = "baseport"
  stage = "prd"
}

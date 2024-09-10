variable app_name {}
variable stage {}
variable cluster_name {}
variable datafeed_bucket_name {}

data "aws_caller_identity" "self" { }
data "aws_region" "self" {}


locals {
  account_id = data.aws_caller_identity.self.account_id
  region = data.aws_region.self.name
  namespace = "opencost"
  service_account = "opencost"
}
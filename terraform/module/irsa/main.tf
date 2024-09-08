variable app_name {}
variable stage {}
variable cluster_name {}
variable role_name {}
variable policies {
  type = map(any)
  description = "{\"POLICY_NAME\": jsonencode({...})}"
  default = {}
}
variable managed_policies {
  type = list(string)
  description = "[\"arn:aws:iam::aws:policy/AdministratorAccess\"]"
  default = []
}
variable namespace {
  default = "*"
}
variable service_account {
  default = "*"
}

data "aws_caller_identity" "current" { }

data "aws_eks_cluster" "this" {
  name = var.cluster_name
}

locals {
  account_id      = data.aws_caller_identity.current.account_id
  oidc_provider   = replace(data.aws_eks_cluster.this.identity[0].oidc[0].issuer, "https://", "")

}

output "role_arn" {
  value = aws_iam_role.this.arn
}

resource "aws_iam_role" "this" {
  name = "${var.app_name}-${var.stage}-${var.role_name}"
  assume_role_policy = jsonencode({
    "Version": "2012-10-17"
    "Statement": {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::${local.account_id}:oidc-provider/${local.oidc_provider}"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringLike": {
          "${local.oidc_provider}:sub": "system:serviceaccount:${var.namespace}:${var.service_account}",
          "${local.oidc_provider}:aud": "sts.amazonaws.com"
        }
      }
    }
  })

  depends_on = [ aws_iam_policy.user_policy ]
}

resource "aws_iam_policy" "user_policy" {
  for_each = var.policies
  name = "${var.app_name}-${var.stage}-${var.role_name}-${each.key}"
  policy = each.value
}

resource "aws_iam_role_policy_attachment" "user_policy" {
  for_each = var.policies
  role = aws_iam_role.this.name
  policy_arn = aws_iam_policy.user_policy[each.key].arn
}

resource "aws_iam_role_policy_attachment" "managed_policy" {
  for_each = toset(var.managed_policies)
  role = aws_iam_role.this.name
  policy_arn = each.key
}
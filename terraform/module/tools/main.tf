variable app_name {}
variable stage {}
variable eks_oidc_issure_url {}
data "aws_caller_identity" "current" { }

locals {
  account_id      = data.aws_caller_identity.current.account_id
  oidc_provider   = replace(var.eks_oidc_issure_url, "https://", "")
  namespace       = "*"
  service_account = "*"

}

output "ecr" {
  value = aws_ecr_repository.tools.repository_url
}

output "role" {
  value = aws_iam_role.tools.arn
}


resource "aws_iam_role" "tools" {
  name = "${var.app_name}-${var.stage}-ToolsPodRole"
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
          "${local.oidc_provider}:sub": "system:serviceaccount:${local.namespace}:${local.service_account}",
          "${local.oidc_provider}:aud": "sts.amazonaws.com"
        }
      }
    }
  })
}

resource "aws_iam_role_policy_attachment" "admin_access" {
  role = aws_iam_role.tools.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

resource "aws_ecr_repository" "tools" {
  name                 = "${var.app_name}/${var.stage}/tools"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}
variable "app_name" { }
variable "stage" { }
variable eks_oidc_issure_url {}

data "aws_caller_identity" "current" { }

output "keycloak_ascp_role" {
  value = aws_iam_role.ascp.arn
}

locals {
  account_id     = data.aws_caller_identity.current.account_id
  oidc_provider = replace(var.eks_oidc_issure_url, "https://", "")
  namespace      = "keycloak"
  service_account = "*"

}

/**
 * Keycloakで利用するDBの認証情報を保持するSecretsManagerにアクセスするためのRole
 */
resource "aws_iam_role" "ascp" {
  name = "${var.app_name}-${var.stage}-keycloak-ASCPRole"
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

  depends_on = [ aws_iam_policy.ascp ]
}

resource "aws_iam_policy" "ascp" {
  name = "${var.app_name}-${var.stage}-keycloak-ASCPTestPolicy"
  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [ {
        "Effect": "Allow",
        "Action": [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ],
        #"Resource": ["arn:*:secretsmanager:*:*:secret:*"]
        "Resource": ["*"]
    } ]
  })
}

resource "aws_iam_role_policy_attachment" "ascp" {
  role = aws_iam_role.ascp.name
  policy_arn = aws_iam_policy.ascp.arn
}

/**
 * Keycloakのadminログイン情報を保持する SecretsManager
 */
resource "random_password" "keycloak_user" {
  length           = 32
  lower            = true  # 小文字を文字列に含める
  numeric          = true  # 数値を文字列に含める
  upper            = true  # 大文字を文字列に含める
  special          = false # 記号を文字列に含める
}

resource "random_password" "keycloak_password" {
  length           = 32
  lower            = true  # 小文字を文字列に含める
  numeric          = true  # 数値を文字列に含める
  upper            = true  # 大文字を文字列に含める
  special          = true  # 記号を文字列に含める
  override_special = "@_=+-"  # 記号で利用する文字列を指定 (default: !@#$%&*()-_=+[]{}<>:?)
}

resource "aws_secretsmanager_secret" "app_db_secret" {
  name = "/${var.app_name}/${var.stage}/keycloak"
  recovery_window_in_days = 0
  force_overwrite_replica_secret = true

}

resource "aws_secretsmanager_secret_version" "app_db_secret_version" {
  secret_id = aws_secretsmanager_secret.app_db_secret.id
  secret_string = jsonencode({
    user = random_password.keycloak_user.result
    password = random_password.keycloak_password.result
  })
}
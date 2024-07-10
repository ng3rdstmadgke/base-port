/**
 * secrets-store-csi-driver-provicer-awsを利用して、
 * SecretsManagerのシークレットをマウントするためのサービスアカウントとIAMロールを作成します。
 *
 * - Usage - secrets-store-csi-driver-provider-aws | GitHub
 *   https://github.com/aws/secrets-store-csi-driver-provider-aws?tab=readme-ov-file#usage
 */
variable app_name {}
variable stage {}
variable eks_oidc_issure_url {}
data "aws_caller_identity" "current" { }

locals {
  account_id     = data.aws_caller_identity.current.account_id
  oidc_provider = replace(var.eks_oidc_issure_url, "https://", "")
  namespace      = "default"
  service_account = "ascp-test"

}

output "ascp_test_service_account" {
  value = local.service_account
}

resource "kubernetes_service_account" "ascp_test" {
  metadata {
    name      = local.service_account
    namespace = local.namespace
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.ascp_test.arn
    }
  }
}

resource "aws_iam_role" "ascp_test" {
  name = "${var.app_name}-${var.stage}-ASCPTestRole"
  assume_role_policy = jsonencode({
    "Version": "2012-10-17"
    "Statement": {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::${local.account_id}:oidc-provider/${local.oidc_provider}"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "${local.oidc_provider}:sub": "system:serviceaccount:${local.namespace}:${local.service_account}",
          "${local.oidc_provider}:aud": "sts.amazonaws.com"
        }
      }
    }
  })

  depends_on = [ aws_iam_policy.ascp_test ]
}

resource "aws_iam_policy" "ascp_test" {
  name = "${var.app_name}-${var.stage}-ASCPTestPolicy"
  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [ {
        "Effect": "Allow",
        "Action": ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"],
        "Resource": ["arn:*:secretsmanager:*:*:secret:*"]
    } ]
  })
}

resource "aws_iam_role_policy_attachment" "ascp_test" {
  role = aws_iam_role.ascp_test.name
  policy_arn = aws_iam_policy.ascp_test.arn
}

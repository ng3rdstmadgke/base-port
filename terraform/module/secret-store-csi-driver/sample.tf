/**
 * secrets-store-csi-driver-provicer-awsを利用して、
 * SecretsManagerのシークレットをマウントするためのサービスアカウントとIAMロールを作成します。
 *
 * - Usage - secrets-store-csi-driver-provider-aws | GitHub
 *   https://github.com/aws/secrets-store-csi-driver-provider-aws?tab=readme-ov-file#usage
 */


#
# Input
#
variable app_name {
  description = "アプリケーション名"
  type        = string
}
variable stage {
  description = "ステージ名"
  type        = string
}

variable project_dir {
  description = "プロジェクトルートディレクトリ"
  type        = string
}

variable eks_cluster_name {
  description = "EKSクラスター名"
  type        = string
}
variable eks_oidc_issure_url {
  description = "EKS OIDC Issuer URL"
  type        = string
}

data "aws_caller_identity" "current" { }

locals {
  account_id     = data.aws_caller_identity.current.account_id
  oidc_provider = replace(var.eks_oidc_issure_url, "https://", "")
  namespace      = "ascp-test"
  sa_for_pod_identity = "ascp-test-pod-identity"
  sa_for_irsa = "ascp-test-irsa"

}

#
# Output
#
output "sa_for_pod_identity" {
  value = local.sa_for_pod_identity
}

output "sa_for_irsa" {
  value = local.sa_for_irsa
}

#
# Namespace
#
resource "kubernetes_namespace" "ascp_test" {
  metadata {
    name = local.namespace
  }
}

#
# IAMポリシー
#
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

#
# シークレット
#
resource "aws_secretsmanager_secret" "sample_secret" {
  name = "/${var.app_name}/${var.stage}/sample"
  recovery_window_in_days = 0
  force_overwrite_replica_secret = true

}

resource "aws_secretsmanager_secret_version" "sample_secret_version" {
  secret_id = aws_secretsmanager_secret.sample_secret.id
  secret_string = jsonencode({
    "username" = "sample_user"
    "password" = "sample_password"
  })
}


#
# IRSA 用のリソース
#
resource "aws_iam_role" "ascp_test_irsa" {
  name = "${var.app_name}-${var.stage}-IRSA-ASCPTestRole"
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
          "${local.oidc_provider}:sub": "system:serviceaccount:${local.namespace}:${local.sa_for_irsa}",
          "${local.oidc_provider}:aud": "sts.amazonaws.com"
        }
      }
    }
  })

  depends_on = [ aws_iam_policy.ascp_test ]
}

resource "aws_iam_role_policy_attachment" "ascp_test_irsa" {
  role = aws_iam_role.ascp_test_irsa.name
  policy_arn = aws_iam_policy.ascp_test.arn
}

resource "kubernetes_service_account" "ascp_test_irsa" {
  metadata {
    name      = local.sa_for_irsa
    namespace = local.namespace
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.ascp_test_irsa.arn
    }
  }
}

resource "local_file" "irsa_sample" {
  for_each = toset(["sample_1.yaml", "sample_2.yaml", "sample_3.yaml"])
  filename = "${var.project_dir}/plugin/ascp/sample/${var.stage}/manifest/irsa/${each.key}"
  directory_permission = "0755"
  file_permission = "0644"
  content = templatefile(
    "${path.module}/sample/irsa/${each.key}",
    {
      namespace = local.namespace,
      service_account = local.sa_for_irsa,
      secrets_name = aws_secretsmanager_secret.sample_secret.name,
      escaped_secret_name = replace(aws_secretsmanager_secret.sample_secret.name, "/", "_"),
    }
  )
}


#
# Pod Identity 用のリソース
#
resource "aws_iam_role" "ascp_test_pod_identity" {
  name = "${var.app_name}-${var.stage}-PodIdentity-ASCPTestRole"
  assume_role_policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Sid": "AllowEksAuthToAssumeRoleForPodIdentity",
        "Effect": "Allow",
        "Principal": {
          "Service": "pods.eks.amazonaws.com"
        },
        "Action": [
          "sts:AssumeRole",
          "sts:TagSession"
        ]
      }
    ]
  })

  depends_on = [ aws_iam_policy.ascp_test ]
}

resource "aws_iam_role_policy_attachment" "ascp_test_pod_identity" {
  role = aws_iam_role.ascp_test_pod_identity.name
  policy_arn = aws_iam_policy.ascp_test.arn
}

resource "kubernetes_service_account" "ascp_test_pod_identity" {
  metadata {
    name      = local.sa_for_pod_identity
    namespace = local.namespace
  }
}

resource "aws_eks_pod_identity_association" "example" {
  cluster_name    = var.eks_cluster_name
  namespace       = local.namespace
  service_account = local.sa_for_pod_identity
  role_arn        = aws_iam_role.ascp_test_pod_identity.arn
}

resource "local_file" "pod_identity_sample" {
  for_each = toset(["sample_1.yaml", "sample_2.yaml", "sample_3.yaml"])
  filename = "${var.project_dir}/plugin/ascp/sample/${var.stage}/manifest/pod_identity/${each.key}"
  directory_permission = "0755"
  file_permission = "0644"
  content = templatefile(
    "${path.module}/sample/pod_identity/${each.key}",
    {
      namespace = local.namespace,
      service_account = local.sa_for_pod_identity,
      secrets_name = aws_secretsmanager_secret.sample_secret.name,
      escaped_secret_name = replace(aws_secretsmanager_secret.sample_secret.name, "/", "_"),
    }
  )
}

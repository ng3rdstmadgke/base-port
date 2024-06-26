/**
 * KEDA: https://keda.sh/docs/2.14/
 */

/**
 * KEDA Operator が利用するIAM Role
 * KedaTriggerAuthRole(KEDAがSQSなどをポーリングするためのRole) へのAssumeRole権限を持つ
 */
resource "aws_iam_role" "keda_operator" {
  name = "${var.app_name}-${var.stage}-KedaOperatorRole"
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
          "${local.oidc_provider}:sub": "system:serviceaccount:${local.keda_namespace}:keda-operator",
          "${local.oidc_provider}:aud": "sts.amazonaws.com"
        }
      }
    }
  })

  depends_on = [ aws_iam_policy.keda_operator ]
}

resource "aws_iam_policy" "keda_operator" {
  name = "${var.app_name}-${var.stage}-KedaOperatorPolicy"
  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": [
          "sts:AssumeRole",
        ],
        // keda-operatorにAssumeRoleする KedaTriggerAuthRole を指定
        "Resource": "*"
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "keda_operator" {
  role = aws_iam_role.keda_operator.name
  policy_arn = aws_iam_policy.keda_operator.arn
}

/**
 * kedaチャートをインストールします。
 *
 * 参考
 *   - Deploying KEDA: https://keda.sh/docs/2.14/deploy/
 *   - KEDA | ArtifactHUB: https://artifacthub.io/packages/helm/kedacore/keda
 */

//helm_release - helm - terraform: https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release
resource "helm_release" "keda" {
  name       = "keda"
  repository = "https://kedacore.github.io/charts"
  chart      = "keda"
  version    = "2.14.2"
  namespace  = local.keda_namespace
  create_namespace = true
  depends_on = [
    aws_iam_role.keda_operator
  ]

  // AWS (IRSA) Pod Identity Webhook: https://keda.sh/docs/2.14/authentication-providers/aws/
  set {
    name  = "podIdentity.aws.irsa.enabled"
    value = true
  }

  // AWS (IRSA) Pod Identity Webhook: https://keda.sh/docs/2.14/authentication-providers/aws/
  set {
    name  = "podIdentity.aws.irsa.roleArn"
    value = aws_iam_role.keda_operator.arn
  }
}
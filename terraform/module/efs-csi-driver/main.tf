/**
 * - Amazon EFS CSI dynamic provisioningの御紹介 | Amazon Web Services ブログ
 * https://aws.amazon.com/jp/blogs/news/amazon-efs-csi-dynamic-provisioning/
 * - aws-efs-csi-driver | GitHub
 * https://github.com/kubernetes-sigs/aws-efs-csi-driver
 */

// IRSA(IAM Roles for Service Accounts)用のサービスアカウントを作成します。
// https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/service_account
resource "kubernetes_service_account" "efs_csi_controller" {
  metadata {
    name      = local.service_account
    namespace = local.namespace
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.efs_csi_controller.arn
    }
  }
}

/**
 * EFS CSI DriverがEFSアクセスポイントを管理するためのIAMロール
 * 
 * - Amazon EFS CSI ドライバー | AWS
 *   https://docs.aws.amazon.com/ja_jp/eks/latest/userguide/efs-csi.html#efs-create-iam-resources
 */
resource "aws_iam_role" "efs_csi_controller" {
  name = "${var.app_name}-${var.stage}-EfsCsiControllerRole"
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

  depends_on = [ aws_iam_policy.efs_csi_controller ]
}

resource "aws_iam_policy" "efs_csi_controller" {
  name = "${var.app_name}-${var.stage}-EfsCsiControllerPolicy"
  // - Set up driver permission - aws-efs-csi-driver | GitHub
  // https://github.com/kubernetes-sigs/aws-efs-csi-driver?tab=readme-ov-file#set-up-driver-permission
  // - iam-policy-example.json - aws-efs-csi-driver | GitHub
  //   https://github.com/kubernetes-sigs/aws-efs-csi-driver/blob/master/docs/iam-policy-example.json
  policy = file("${path.module}/efs-csi-controller-policy.json")
}

resource "aws_iam_role_policy_attachment" "efs_csi_controller" {
  role = aws_iam_role.efs_csi_controller.name
  policy_arn = aws_iam_policy.efs_csi_controller.arn
}

/**
 * EFS CSI Driver チャートをインストールします。
 *
 * 参考
 * - installation - aws-efs-csi-driver | GitHub
 *   https://github.com/kubernetes-sigs/aws-efs-csi-driver?tab=readme-ov-file#installation
 * - Amazon EFS CSI dynamic provisioningの御紹介 | Amazon Web Services ブログ
 *   https://aws.amazon.com/jp/blogs/news/amazon-efs-csi-dynamic-provisioning/
 */

//helm_release - helm - terraform: https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release
resource "helm_release" "efs_csi_driver" {
  name       = "aws-efs-csi-driver"
  repository = "https://kubernetes-sigs.github.io/aws-efs-csi-driver/"
  chart      = "aws-efs-csi-driver"
  version    = "3.0.6"  # helm search repo aws-efs-csi-driver
  namespace  = local.namespace
  create_namespace = true
  depends_on = [
    aws_iam_role.efs_csi_controller
  ]

  // イメージリポジトリをAmazon container image registriesに置き換え
  // https://docs.aws.amazon.com/eks/latest/userguide/add-ons-images.html
  set {
    name  = "image.repository"
    value = "	602401143452.dkr.ecr.ap-northeast-1.amazonaws.com/eks/aws-efs-csi-driver"
  }

  // すでにサービスアカウントを作成済みの場合
  set {
    name  = "controller.serviceAccount.create"
    value = false
  }
  set {
    name  = "controller.serviceAccount.name"
    value = local.service_account
  }
}

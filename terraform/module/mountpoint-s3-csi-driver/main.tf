# インストール手順: https://docs.aws.amazon.com/ja_jp/eks/latest/userguide/s3-csi.html
/**
 * Mountpoint for Amazon S3 CSI ドライバーがファイルシステムと対話するためのS3アクセス許可
 * https://docs.aws.amazon.com/ja_jp/eks/latest/userguide/s3-csi.html#s3-create-iam-role
 */
resource "aws_iam_role" "s3_csi_driver_role" {
  name = "${var.app_name}-${var.stage}-S3CsiDriverRole"
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

  depends_on = [ aws_iam_policy.s3_csi_driver_policy ]
}

# https://docs.aws.amazon.com/ja_jp/eks/latest/userguide/s3-csi.html#s3-create-iam-policy
resource "aws_iam_policy" "s3_csi_driver_policy" {
  name = "${var.app_name}-${var.stage}-AmazonS3CSIDriverPolicy"
  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Sid": "MountpointFullBucketAccess",
        "Effect": "Allow",
        "Action": [
          "s3:ListBucket"
        ],
        "Resource": [
          "arn:aws:s3:::baseport-*"
        ]
      },
      {
        "Sid": "MountpointFullObjectAccess",
        "Effect": "Allow",
        "Action": [
          "s3:GetObject",
          "s3:PutObject",
          "s3:AbortMultipartUpload",
          "s3:DeleteObject"
        ],
        "Resource": [
          "arn:aws:s3:::baseport-*/*"
        ]
      },
      {
          "Effect": "Allow",
          "Action": "s3express:CreateSession",
          "Resource": "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "s3_csi_driver" {
  role = aws_iam_role.s3_csi_driver_role.name
  policy_arn = aws_iam_policy.s3_csi_driver_policy.arn
}

/**
 * アドオンの追加
 */
resource "aws_eks_addon" "aws_mountpoint_s3_csi_driver" {
  cluster_name  = local.cluster_name
  addon_name   = "aws-mountpoint-s3-csi-driver"
  addon_version = "v1.10.0-eksbuild.1"
  service_account_role_arn = aws_iam_role.s3_csi_driver_role.arn
}
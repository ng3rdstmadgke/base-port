/**
 * EKSのPod実行ロール
 * - terraform-aws-eks の サブモジュール fargate-profile のソースコード
 *   - https://github.com/terraform-aws-modules/terraform-aws-eks/blob/v20.14.0/modules/fargate-profile/main.tf#L20
 */
resource "aws_iam_role" "eks_fargate_pod_execution_role" {
  name = "${var.app_name}-${var.stage}-EKSFargatePodExecutionRole"
  assume_role_policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Condition": {
          "ArnLike": {
            "aws:SourceArn": "arn:aws:eks:${data.aws_region.self.name}:${data.aws_caller_identity.self.account_id}:fargateprofile/${local.cluster_name}/*"
          }
        },
        "Principal": {
          "Service": "eks-fargate-pods.amazonaws.com"
        },
        "Action": "sts:AssumeRole"
      }
    ]
  })
}

// PodをFargateで実行するためのEKS Pod実行ロールポリシーをアタッチ
//   - https://docs.aws.amazon.com/ja_jp/eks/latest/userguide/pod-execution-role.html#create-pod-execution-role
resource "aws_iam_role_policy_attachment" "eks_fargate_pod_execution_role_policy" {
  role = aws_iam_role.eks_fargate_pod_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSFargatePodExecutionRolePolicy"
}

// IRSAをIPv4利用するためのポリシーアタッチメント
//   - https://docs.aws.amazon.com/ja_jp/eks/latest/userguide/cni-iam-role.html#cni-iam-role-create-role
resource "aws_iam_role_policy_attachment" "amazoneks_cni_policy" {
  role = aws_iam_role.eks_fargate_pod_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

// IRSAをIPv6利用するためのポリシーアタッチメント
//   - https://docs.aws.amazon.com/ja_jp/eks/latest/userguide/cni-iam-role.html#cni-iam-role-create-role
// IPv6 を使用するクラスター用の IAM ポリシー
//   - https://docs.aws.amazon.com/ja_jp/eks/latest/userguide/cni-iam-role.html#cni-iam-role-create-ipv6-policy
resource "aws_iam_policy" "amazoneks_cni_ipv6_policy" {
  name = "${var.app_name}-${var.stage}-AmazonEKS_CNI_IPv6_Policy"
  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": [
          "ec2:AssignIpv6Addresses",
          "ec2:DescribeInstances",
          "ec2:DescribeTags",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DescribeInstanceTypes"
        ],
        "Resource": "*"
      },
      {
        "Effect": "Allow",
        "Action": [
          "ec2:CreateTags"
        ],
        "Resource": [
          "arn:aws:ec2:*:*:network-interface/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "amazoneks_cni_ipv6_policy" {
  role = aws_iam_role.eks_fargate_pod_execution_role.name
  policy_arn = aws_iam_policy.amazoneks_cni_ipv6_policy.arn
}


// 追加のIAMポリシーをアタッチ
// terraform-aws-eks の fargate_profile example から引用
//   - https://github.com/terraform-aws-modules/terraform-aws-eks/blob/v20.14.0/examples/fargate_profile/main.tf#L146
resource "aws_iam_policy" "additional" {
  name = "${var.app_name}-${var.stage}-AdditionalPolicy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ec2:Describe*",
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "additional_policy" {
  role = aws_iam_role.eks_fargate_pod_execution_role.name
  policy_arn = aws_iam_policy.additional.arn
}
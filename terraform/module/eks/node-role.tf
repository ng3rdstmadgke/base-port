/**
 * ノードのIAMロールの作成
 *   - managed_node_group で使用する IAM ロールを作成します。
 *     - https://docs.aws.amazon.com/ja_jp/eks/latest/userguide/create-node-role.html#create-worker-node-role
 *   - terraform-aws-eks の サブモジュール eks-managed-node-group のソースコード
 *     - https://github.com/terraform-aws-modules/terraform-aws-eks/blob/v20.14.0/modules/eks-managed-node-group/main.tf#L470
 */
resource "aws_iam_role" "eks_node_role" {
  name = "${var.app_name}-${var.stage}-EKSNodeRole"
  assume_role_policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Principal": {
          "Service": "ec2.amazonaws.com"
        },
        "Action": "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "eks_node_role_worker_node_policy" {
  role = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "ec2_node_role_container_registry_read_only" {
  role = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "eks_node_role_cni_policy" {
  role = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_policy" "eks_node_role_cni_ipv6_policy" {
  name = "${var.app_name}-${var.stage}-node-AmazonEKS_CNI_IPv6_Policy"
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

resource "aws_iam_role_policy_attachment" "eks_node_role_cni_ipv6_policy" {
  role = aws_iam_role.eks_node_role.name

  policy_arn = aws_iam_policy.eks_node_role_cni_ipv6_policy.arn
}

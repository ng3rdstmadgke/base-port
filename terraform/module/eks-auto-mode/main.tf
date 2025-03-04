// https://docs.aws.amazon.com/eks/latest/userguide/automode-get-started-cli.html#_create_an_eks_auto_mode_node_iam_role
/**
 * EKS AutoModeでプロビジョニングされるNodeに付与するロール
 */
resource "aws_iam_role" "automode_node_role" {
  name = "${var.app_name}-${var.stage}-AmazonEKSAutoNodeRole"
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

resource "aws_iam_role_policy_attachment" "automode_node_role_policy" {
  for_each = {
    worker_node_minimal_policy: "arn:aws:iam::aws:policy/AmazonEKSWorkerNodeMinimalPolicy",
    container_registry_pull_only_policy: "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPullOnly",
  }
  role = aws_iam_role.automode_node_role.name
  policy_arn = each.value
}
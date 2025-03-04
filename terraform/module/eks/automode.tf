// https://docs.aws.amazon.com/eks/latest/userguide/automode-get-started-cli.html#_create_an_eks_auto_mode_node_iam_role
/**
 * EKS AutoModeでプロビジョニングされるNodeに付与するロール
 */
resource "aws_iam_role" "automode_node_role" {
  name = "${var.app_name}-${var.stage}-AmazonEKSAutoModeNodeRole"
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

resource "local_file" "eks_automode_nodeclass_yaml_01" {
  filename = "${var.project_dir}/plugin/eks-auto-mode/resources/nodeclass-standard.yaml"
  file_permission = "0644"
  content = templatefile(
    "${path.module}/resources/automode-nodeclass-standard.yaml",
    {
      cluster_name = local.cluster_name,
      automode_node_role_name = aws_iam_role.automode_node_role.name,
    }
  )
}

resource "local_file" "eks_automode_nodepool_yaml_01" {
  filename = "${var.project_dir}/plugin/eks-auto-mode/resources/nodepool-standard.yaml"
  file_permission = "0644"
  content = templatefile(
    "${path.module}/resources/automode-nodepool-standard.yaml",
    {}
  )
}
/**
 * Kubernetes における永続ストレージ | Amazon Web Services ブログ
 * https://aws.amazon.com/jp/blogs/news/persistent-storage-for-kubernetes/
 */

/**
 * EFS
 */
// https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/efs_file_system
resource "aws_efs_file_system" "this" {
  creation_token = "${var.app_name}-${var.stage}"
  encrypted = true

  tags = {
    Name = "${var.app_name}-${var.stage}"
  }
}

// https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/efs_mount_target
resource "aws_efs_mount_target" "alpha" {
  for_each = toset(var.private_subnets)
  file_system_id = aws_efs_file_system.this.id
  subnet_id      = each.key
  security_groups = [
    aws_security_group.efs.id
  ]
}

/**
 * ALB のセキュリティグループ
 */
resource "aws_security_group" "efs" {
  name        = "${var.app_name}-${var.stage}-efsMountTarget"
  description = "Allow EKS Cluster SG access."
  vpc_id      = var.vpc_id

  ingress {
    description = "Allow EKS Cluster SG access."
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    security_groups = [var.eks_cluster_sg_id]
  }
  tags = {
    Name = "${var.app_name}-${var.stage}-efsMountTarget"
  }
}
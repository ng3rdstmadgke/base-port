/**
 * Kubernetes における永続ストレージ | Amazon Web Services ブログ
 * https://aws.amazon.com/jp/blogs/news/persistent-storage-for-kubernetes/
 */

/**
 * EFS
 */
// https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/efs_file_system
resource "aws_efs_file_system" "this" {
  creation_token = "${var.app_name}-${var.stage}-${var.name}"
  encrypted = true
  throughput_mode = "elastic"

  tags = {
    Name = "${var.app_name}-${var.stage}-${var.name}"
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

resource "aws_security_group" "efs" {
  name        = "${var.app_name}-${var.stage}-${var.name}-efsMountTarget"
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
    Name = "${var.app_name}-${var.stage}-${var.name}-efsMountTarget"
  }
}

resource "local_file" "eks_automode_nodepool_yaml_01" {
  filename = "${var.project_dir}/plugin/efs/resources/storageclass-${var.name}.yaml"
  directory_permission = "0755"
  file_permission = "0644"
  content = templatefile(
    "${path.module}/resources/storageclass.yaml",
    {
      name = var.name,
      efs_id = aws_efs_file_system.this.id,
    }
  )
}
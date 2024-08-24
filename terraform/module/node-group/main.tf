/**
 * ノードグループ用追加SG
 */
resource "aws_security_group" "additional_node_sg" {
  name        = "${var.app_name}-${var.stage}-${var.node_group_name}-AdditionalNodeSecurityGroup"
  description = "additional security group for ${var.node_group_name} node group."
  vpc_id      = data.aws_eks_cluster.this.vpc_config[0].vpc_id

  ingress {
    description = "Allow cluster SecurityGroup access."
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks      = ["10.0.0.0/8"]
  }

  tags = {
    Name = "${var.app_name}-${var.stage}-${var.node_group_name}-AdditionalNodeSecurityGroup"
  }
}

/**
 * 起動テンプレート
 * https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/launch_template
 */
resource "aws_launch_template" "node_instance" {
  name = "${var.app_name}-${var.stage}-${var.node_group_name}-EKSNodeLaunchTemplate"

  // イメージ ID を明示的に指定する場合
  // image_id = nonsensitive(aws_ssm_parameter.eks_ami_release_version.value)

  key_name = var.key_pair_name
  vpc_security_group_ids = concat([
    data.aws_eks_cluster.this.vpc_config[0].cluster_security_group_id,
    aws_security_group.additional_node_sg.id
  ], var.node_additional_sg_ids)

  update_default_version = true

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size = 50
      volume_type = "gp3"
    }
  }

  monitoring {
    enabled = true
  }

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "${var.app_name}-${var.stage}-${var.node_group_name}"
    }
  }
}

/**
 * AMI ID を明示的に指定する場合
 * - Amazon EKS 最適化 AMI
 *   https://docs.aws.amazon.com/ja_jp/eks/latest/userguide/eks-optimized-amis.html
 * - Amazon EKS 最適化 Amazon Linux AMI ID の取得
 *   https://docs.aws.amazon.com/ja_jp/eks/latest/userguide/retrieve-ami-id.html
 *
 *  下記のコマンドで AMI ID を取得できます
 *  K8S_VERSION=1.30
 *  AMI_TYPE=amazon-linux-2023/x86_64/standard
 *  REGION=ap-northeast-1
 *  
 *  aws ssm get-parameter \
 *    --name /aws/service/eks/optimized-ami/${K8S_VERSION}/${AMI_TYPE}/recommended/image_id \
 *      --region $REGION \
 *      --query "Parameter.Value" \
 *      --output text
 */
// locals {
//   ami_type = "amazon-linux-2023/x86_64/standard"
// }
// data "aws_ssm_parameter" "eks_ami_release_version" {
//   name = "/aws/service/eks/optimized-ami/${data.aws_eks_cluster.this.version}/${local.ami_type}/recommended/release_version"
// }


/**
 * EKSノードグループ
 * https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_node_group
 */
resource "aws_eks_node_group" "this" {
  cluster_name    = local.cluster_name
  version         = data.aws_eks_cluster.this.version

  node_group_name = var.node_group_name
  node_role_arn   = var.node_role_arn
  subnet_ids      = data.aws_eks_cluster.this.vpc_config[0].subnet_ids
  capacity_type = var.capacity_type
  // スポット料金: https://aws.amazon.com/jp/ec2/spot/pricing/
  instance_types = var.instance_types

  scaling_config {
    desired_size = var.desired_size
    max_size     = 10
    min_size     = 1
  }

  // 起動テンプレートを指定する場合、disk_size , remote_access
  launch_template {
    id = aws_launch_template.node_instance.id
    version = aws_launch_template.node_instance.latest_version
  }

  update_config {
    // ノード更新時に利用不可能になるノードの最大数
    max_unavailable = 1
  }

  // https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_node_group#tracking-the-latest-eks-node-group-ami-releases
  // release_version = nonsensitive(aws_ssm_parameter.eks_ami_release_version.value)
}

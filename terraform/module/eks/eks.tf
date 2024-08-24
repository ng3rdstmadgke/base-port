/**
 * VPC
 * terraform-aws-modules/vpc/aws
 *   - https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws/latest
 * terraform-aws-eks example fargate_profile
 *   - https://github.com/terraform-aws-modules/terraform-aws-eks/blob/v20.14.0/examples/fargate_profile/main.tf#L120
 */
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  version = "~> 5.8.1"

  name = "${var.app_name}-${var.stage}-vpc"
  cidr = "10.32.0.0/16"

  azs             = ["ap-northeast-1a", "ap-northeast-1c", "ap-northeast-1d"]
  private_subnets = var.private_subnets
  public_subnets  = var.public_subnets

  enable_nat_gateway = true
  single_nat_gateway = true
  enable_vpn_gateway = false

  // パブリックサブネットを外部LB用に利用することをKubernetesとALBが認識できるようにするためのタグ
  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }
  // プライベートネットを内部LB用に利用することをKubernetesとALBが認識できるようにするためのタグ
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
  }
}

/**
 * EKSクラスタ
 *   terraform-aws-modules/eks/aws: https://registry.terraform.io/modules/terraform-aws-modules/eks/aws/latest
 *   fargate_profile example: https://github.com/terraform-aws-modules/terraform-aws-eks/blob/v20.14.0/examples/fargate_profile/main.tf
 */
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.24.0"

  cluster_name = local.cluster_name
  cluster_version = var.cluster_version

  // Amazon EKSパブリックAPIサーバーエンドポイントが有効かどうかを示します。
  // NOTE: 「APIサーバーエンドポイント」「パブリックアクセス」とは？: https://dev.classmethod.jp/articles/eks-public-endpoint-access-restriction/#toc-1
  cluster_endpoint_public_access = true

  vpc_id = module.vpc.vpc_id

  // ノード/ノードグループがプロビジョニングされるサブネット ID
  // control_plane_subnet_idsが省略された場合、EKS クラスタの制御プレーン (ENI) はこれらのサブネットにプロビジョニングされる
  // パブリックサブネットを含める場合: subnet_ids = concat(module.vpc.private_subnets, module.vpc.public_subnets)
  subnet_ids = module.vpc.private_subnets

  // IAM Roles for Service Accounts (IRSA) を有効にするためにEKS用のOpenID Connect Providerを作成するかどうか
  enable_irsa     = true

  // TerraformをデプロイしたRoleにkubernetesAPIへのアクセス権を付与する (これがないとkubectlコマンドで操作できない)
  enable_cluster_creator_admin_permissions = true

  // クラスターに対するIAMプリンシパルアクセスの有効化: https://docs.aws.amazon.com/ja_jp/eks/latest/userguide/add-user-role.html
  authentication_mode = "API_AND_CONFIG_MAP"

  # 追加のセキュリティグループを作成するかどうか
  create_cluster_security_group = false
  create_node_security_group    = false

  #cluster_security_group_tags = {
  #  #"aws:eks:cluster-name" = local.cluster_name
  #  #"kubernetes.io/cluster/baseport-prd" = "owned"
  #  "karpenter.sh/discovery" = local.cluster_name
  #}

  /**
   * クラスタSG
   * - EKSのセキュリティグループについて理解する | Qiita: https://qiita.com/MAKOTO1995/items/4e70998e50aaea5e9882
   * - クラスタSGは下記に適用される
   *   - EKSコントロールプレーン通信用ENI
   *   - マネージドノードグループ内のEC2ノード (ただし、ノードSGが付与されている場合は、クラスタSGは付与されない)
  cluster_security_group_additional_rules = {
    egress_nodes_ephemeral_ports_tcp = {
      description                = "To node 1025-65535"
      protocol                   = "tcp"
      from_port                  = 1025
      to_port                    = 65535
      type                       = "egress"
      source_node_security_group = true
    }
  }
   */

  /**
   * ノードSG
   * - EKSのセキュリティグループについて理解する | Qiita: https://qiita.com/MAKOTO1995/items/4e70998e50aaea5e9882
   * - ノードSGは下記に適用される
   *   - マネージドノードグループ内のEC2ノードに付与するSG
  node_security_group_additional_rules = {
    admission_webhook = {
      description                   = "Admission Webhook"
      protocol                      = "tcp"
      from_port                     = 0
      to_port                       = 65535
      type                          = "ingress"
      source_cluster_security_group = true
    }

    ingress_self_all = {
      description = "Node to node all ports/protocols"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "ingress"
      self        = true
    }
    egress_all = {
      description      = "Node all egress"
      protocol         = "-1"
      from_port        = 0
      to_port          = 0
      type             = "egress"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    }
  }
   */
}

/**
 * IAMユーザー・ロールにkubernetesAPIへのアクセス権限を付与
 * - EKS アクセスエントリを使用して Kubernetes へのアクセスを IAM ユーザーに許可する | AWS
 *   https://docs.aws.amazon.com/ja_jp/eks/latest/userguide/access-entries.html
 */
// aws_eks_access_entry | Terraform
// https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_access_entry
resource "aws_eks_access_entry" "admin" {
  for_each = toset(var.access_entries)  // 配列はループできないのでセットに変換
  cluster_name      = local.cluster_name
  principal_arn     = each.key
  type              = "STANDARD"

  depends_on = [
    module.eks
  ]
}

// aws_eks_access_policy_association | Terraform
// https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_access_policy_association
resource "aws_eks_access_policy_association" "admin" {
  for_each = toset(var.access_entries)
  cluster_name  = local.cluster_name
  // アクセスポリシー: https://docs.aws.amazon.com/ja_jp/eks/latest/userguide/access-policies.html#access-policy-permissions
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  principal_arn = each.key

  access_scope {
    type       = "cluster"
  }

  depends_on = [
    module.eks
  ]
}

/**
 * TODO: EKSのクラスタロールの作成
 *   - https://docs.aws.amazon.com/ja_jp/eks/latest/userguide/service_IAM_role.html#create-service-role
 *   - terraform-aws-eks の ソースコード
 *     - https://github.com/terraform-aws-modules/terraform-aws-eks/blob/v20.14.0/main.tf#L357
 */

/**
 * TODO: ノードのIAMロールの作成
 *   - managed_node_group で使用する IAM ロールを作成します。
 *     - https://docs.aws.amazon.com/ja_jp/eks/latest/userguide/create-node-role.html#create-worker-node-role
 *   - terraform-aws-eks の サブモジュール eks-managed-node-group のソースコード
 *     - https://github.com/terraform-aws-modules/terraform-aws-eks/blob/v20.14.0/modules/eks-managed-node-group/main.tf#L470
 */

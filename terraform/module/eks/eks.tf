// terraform-aws-modules/eks/aws: https://registry.terraform.io/modules/terraform-aws-modules/eks/aws/latest
// fargate_profile example: https://github.com/terraform-aws-modules/terraform-aws-eks/blob/v20.14.0/examples/fargate_profile/main.tf
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.14.0"

  cluster_name = local.cluster_name
  cluster_version = var.cluster_version

  // Amazon EKSパブリックAPIサーバーエンドポイントが有効かどうかを示します。
  // NOTE: 「APIサーバーエンドポイント」「パブリックアクセス」とは？: https://dev.classmethod.jp/articles/eks-public-endpoint-access-restriction/#toc-1
  cluster_endpoint_public_access = true

  cluster_addons = {
    // クラスター内でサービス検出を有効にする
    coredns = {
      #most_recent = true
      configuration_values = jsonencode({
        computeType = "fargate"
      })
    }
    // クラスター内でサービスネットワーキングを有効にする
    kube-proxy = {
      #most_recent = true
    }
    // クラスター内でポッドネットワーキングを有効にする
    vpc-cni = {
      #most_recent = true
    }
    // Kubernetes サービスアカウントを通じてポッドに AWS IAM アクセス許可を付与する
    eks-pod-identity-agent = {
      #most_recent = true
    }
  }

  vpc_id = module.vpc.vpc_id

  // ノード/ノードグループがプロビジョニングされるサブネット ID
  // control_plane_subnet_idsが省略された場合、EKS クラスタの制御プレーン (ENI) はこれらのサブネットにプロビジョニングされる
  // パブリックサブネットを含める場合: subnet_ids = concat(module.vpc.private_subnets, module.vpc.public_subnets)
  subnet_ids = module.vpc.private_subnets

  // control_plane_subnet_ids = module.vpc.intra_subnets

  // IAM Roles for Service Accounts (IRSA) を有効にするためにEKS用のOpenID Connect Providerを作成するかどうか
  enable_irsa     = true

  // クラスタ作成者(Terraformが使用するID)をアクセスエントリ経由で管理者として追加する
  enable_cluster_creator_admin_permissions = true

  // クラスターに対するIAMプリンシパルアクセスの有効化: https://docs.aws.amazon.com/ja_jp/eks/latest/userguide/add-user-role.html
  authentication_mode = "API_AND_CONFIG_MAP"

  // マネージド型ノードグループ: https://docs.aws.amazon.com/ja_jp/eks/latest/userguide/managed-node-groups.html
  eks_managed_node_groups = {
    default = {
      min_size = 1
      max_size = 5
      desired_size   = 2
      instance_types = ["t3.medium"]
      capacity_type  = "SPOT"
    }
  }

  # Fargate profiles use the cluster primary security group so these are not utilized
  #create_cluster_security_group = false
  #create_node_security_group    = false

  /**
   * クラスタSG
   * - EKSのセキュリティグループについて理解する | Qiita: https://qiita.com/MAKOTO1995/items/4e70998e50aaea5e9882
   * - クラスタSGは下記に適用される
   *   - EKSコントロールプレーン通信用ENI
   *   - マネージドノードグループ内のEC2ノード (ただし、ノードSGが付与されている場合は、クラスタSGは付与されない)
   */
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

  /**
   * ノードSG
   * - EKSのセキュリティグループについて理解する | Qiita: https://qiita.com/MAKOTO1995/items/4e70998e50aaea5e9882
   * - ノードSGは下記に適用される
   *   - マネージドノードグループ内のEC2ノードに付与するSG
   */
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
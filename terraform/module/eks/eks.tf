 /**
  * コントロールプレーンのログを保存するロググループ
  *
  * ロググループ名は /aws/eks/{MY_CLUSTER}/cluster で固定
  * 参考: https://docs.aws.amazon.com/ja_jp/eks/latest/userguide/control-plane-logs.html
  *
  */
resource "aws_cloudwatch_log_group" "eks_control_plane" {
  // https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group

  name = "/aws/eks/${local.cluster_name}/cluster"

  // ログの保持期間
  retention_in_days = 3

  tags = {
    Name = "/aws/eks/${local.cluster_name}/cluster"
  }

  skip_destroy = false
}

/**
 * クラスターロール
 */
resource "aws_iam_role" "cluster_role" {
  #name = "${var.cluster_name}-EKSClusterRole"
  name = "baseport-prd-cluster-20240626022320964400000001"
  force_detach_policies = true
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Sid       = "EKSClusterAssumeRole"
        Action    = [ "sts:TagSession", "sts:AssumeRole" ]
        Effect    = "Allow"
        Principal = { Service = "eks.amazonaws.com" }
      }
    ]
  })
}

// aws管理ポリシー
resource "aws_iam_role_policy_attachment" "aws_managed_policy" {
  for_each = toset([
    "arn:aws:iam::aws:policy/AmazonEKSBlockStoragePolicy",
    "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy",
    "arn:aws:iam::aws:policy/AmazonEKSComputePolicy",
    "arn:aws:iam::aws:policy/AmazonEKSLoadBalancingPolicy",
    "arn:aws:iam::aws:policy/AmazonEKSNetworkingPolicy",
    "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController",
  ])
  role = aws_iam_role.cluster_role.name
  policy_arn = each.key
}

// etcdに保存されたKubernetesシークレットの暗号化に利用するKMSの操作権限
resource "aws_iam_policy" "secret_encription_policy" {
  #name = "${var.cluster_name}-SecretEncriptionPolicy"
  name = "baseport-prd-cluster-ClusterEncryption2024062602234272870000000a"
  description = "Cluster encryption policy to allow cluster role to utilize CMK provided"
  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ListGrants",
          "kms:DescribeKey"
        ],
        "Resource": "arn:aws:kms:ap-northeast-1:674582907715:key/54041834-f170-42cc-96e3-27e6d03d1c05"
      }
    ]
  })
}
resource "aws_iam_role_policy_attachment" "secret_encription_policy" {
  role = aws_iam_role.cluster_role.name
  policy_arn = aws_iam_policy.secret_encription_policy.arn
}



/**
 * Kubernetesのリソースを暗号化するためのKMSキー
 */
resource "aws_kms_key" "kubernetes_encription" {
  // https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key

  description = "${local.cluster_name} cluster encryption key"
  is_enabled = true
  key_usage = "ENCRYPT_DECRYPT"
  multi_region = false
  // キーローテーションの設定
  enable_key_rotation = true
  rotation_period_in_days = 365
  // 暗号化と復号化を行うため対象キーでなければならない
  // キー仕様リファレンス: https://docs.aws.amazon.com/ja_jp/kms/latest/developerguide/symm-asymm-choose-key-spec.html
  customer_master_key_spec = "SYMMETRIC_DEFAULT"
  policy = jsonencode(
    {
      Statement = [
        {
          Sid     = "Default"
          Effect  = "Allow"
          Principal = {
            AWS = "arn:aws:iam::${data.aws_caller_identity.self.account_id}:root"
          }
          Action  = "kms:*"
          Resource  = "*"
        },
        {
          Sid     = "KeyAdministration"
          Effect  = "Allow"
          Principal = {
            AWS = var.access_entries
          }
          Action  = [
            "kms:Update*",
            "kms:UntagResource",
            "kms:TagResource",
            "kms:ScheduleKeyDeletion",
            "kms:Revoke*",
            "kms:ReplicateKey",
            "kms:Put*",
            "kms:List*",
            "kms:ImportKeyMaterial",
            "kms:Get*",
            "kms:Enable*",
            "kms:Disable*",
            "kms:Describe*",
            "kms:Delete*",
            "kms:Create*",
            "kms:CancelKeyDeletion",
          ]
          Resource  = "*"
        },
        {
          Sid     = "KeyUsage"
          Effect  = "Allow"
          Principal = {
            AWS = aws_iam_role.cluster_role.arn
          }
          Action  = [
            "kms:ReEncrypt*",
            "kms:GenerateDataKey*",
            "kms:Encrypt",
            "kms:DescribeKey",
            "kms:Decrypt",
          ]
          Resource  = "*"
        },
      ]
      Version   = "2012-10-17"
    }
  )

  tags = {
    "terraform-aws-modules" = "eks"
  }
}

resource "aws_kms_alias" "kubernetes_encription" {
  // https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_alias

  name = "alias/eks/${local.cluster_name}"
  target_key_id = aws_kms_key.kubernetes_encription.key_id
}



/**
 * EKSクラスタ
 */
resource "aws_eks_cluster" "this" {
  name = local.cluster_name
  role_arn = aws_iam_role.cluster_role.arn
  vpc_config {
    // EKSのプライベートAPIエンドポイントの有効化
    endpoint_private_access = true
    // EKSのパブリックAPIエンドポイントの有効化
    endpoint_public_access = true
    // パブリックAPIエンドポイントにアクセス可能なネットワーク
    public_access_cidrs = [
      "0.0.0.0/0"
    ]
    // コントロールプレーンとワーカーノード間の通信を許可するためのSG
    security_group_ids = [
    ]
    // ワーカーノードが配置されるサブネット (コントロールプレーンとの通信のため、cross-account ENIが作成される)
    subnet_ids = var.private_subnet_ids
  }

  compute_config {
    enabled       = false
    node_pools = []
  }

  kubernetes_network_config {
    ip_family = "ipv4"
    service_ipv4_cidr = "172.20.0.0/16"

    elastic_load_balancing {
      enabled = false
    }
  }

  storage_config {
    block_storage {
      enabled = false
    }
  }

  encryption_config {
    resources = ["secrets"]
    provider {
      key_arn = aws_kms_key.kubernetes_encription.arn
    }
  }

  access_config {
    authentication_mode = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }
  version = "1.31"

  upgrade_policy {
    support_type = "EXTENDED"
  }
  bootstrap_self_managed_addons = false
  enabled_cluster_log_types = [
    #"api",
    #"audit",
    #"authenticator"
  ]

  tags = {
    "terraform-aws-modules" = "eks"
  }

  tags_all = {
    "terraform-aws-modules" = "eks"
  }
}

/**
 * IRSAを利用するため、IAMにEKSのOIDCプロバイダを登録
 * 
 * EKSの認証・認可の仕組み解説 | Zenn: https://zenn.dev/take4s5i/articles/aws-eks-authentication#iam-roles-for-service-accounts(irsa)
 */
resource "aws_iam_openid_connect_provider" "default" {
  // https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_openid_connect_provider
  url = aws_eks_cluster.this.identity[0].oidc[0].issuer

  client_id_list = [
    "sts.amazonaws.com",
  ]

  tags = {
    Name = "${local.cluster_name}-eks-irsa"
  }
}

/**
 * IAMユーザー・ロールにkubernetesAPIへのアクセス権限を付与
 * - EKS アクセスエントリを使用して Kubernetes へのアクセスを IAM ユーザーに許可する | AWS
 *   https://docs.aws.amazon.com/ja_jp/eks/latest/userguide/access-entries.html
 */
// aws_eks_access_entry: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_access_entry
resource "aws_eks_access_entry" "admin" {
  for_each = toset(var.access_entries)  // 配列はループできないのでセットに変換
  cluster_name      = local.cluster_name
  principal_arn     = each.key
  type              = "STANDARD"

  depends_on = [
    aws_eks_cluster.this
  ]
}

// aws_eks_access_policy_association: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_access_policy_association
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
    aws_eks_cluster.this
  ]
}

/**
 * EKSクラスタを作成したIAMユーザーをアクセスエントリに追加
 */
resource "aws_eks_access_entry" "cluster_creator" {
  cluster_name      = local.cluster_name
  principal_arn     = data.aws_caller_identity.self.arn
  type              = "STANDARD"

  depends_on = [
    aws_eks_cluster.this
  ]
}

resource "aws_eks_access_policy_association" "cluster_creator" {
  cluster_name  = local.cluster_name
  // アクセスポリシー: https://docs.aws.amazon.com/ja_jp/eks/latest/userguide/access-policies.html#access-policy-permissions
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  principal_arn = data.aws_caller_identity.self.arn

  access_scope {
    type       = "cluster"
  }

  depends_on = [
    aws_eks_cluster.this
  ]
}
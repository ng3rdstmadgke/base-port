/**
 * 作成するリソース
 *   - Getting Started | karpenter: https://karpenter.sh/docs/getting-started/getting-started-with-karpenter/
 *   - CloudFormation | karpenter: https://karpenter.sh/docs/reference/cloudformation/
 * 
 */
/**
 * KarpenterでプロビジョニングされるNodeに付与するロール
 */
resource "aws_iam_role" "karpenter_node_role" {
  name = "${var.app_name}-${var.stage}-KarpenterNodeRole"
  assume_role_policy = jsonencode({
    "Version": "2012-10-17"
    "Statement": {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole",
    }
  })
}

resource "aws_iam_policy" "karpenter_custom_node_policy" {
  name = "${var.app_name}-${var.stage}-KarpenterCustomNodePolicy"
  policy = jsonencode({
      "Version": "2012-10-17",
      "Statement": [
        {
          "Sid": "KMSDecryptforSSM",
          "Effect": "Allow",
          "Resource": [
            "*"
          ],
          "Action": [
            "kms:Decrypt"
          ]
        } 
      ]
  })
}

resource "aws_iam_role_policy_attachment" "karpenter_node_role_policy" {
  for_each = {
    // Amazon VPC CNI プラグインが EKS ワーカーノードを構成するために必要な権限
    cni_policy: "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    // Amazon EKS ワーカーノードが EKS クラスターに接続できるようにする
    worker_policy: "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    // Amazon EC2 コンテナレジストリ内のリポジトリへの読み取り専用アクセスを許可
    ecr_readonly_policy: "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
    // Amazon EC2 用の AWS Systems Manager サービスコア機能
    ssm_core_policy: "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
    // Fluent Bit で CloudWatch Logs にログを送信するためのポリシー
    cloudwatch_logs_policy: "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess",
    // 追加のノードポリシー
    custom_policy: aws_iam_policy.karpenter_custom_node_policy.arn,
  }
  role = aws_iam_role.karpenter_node_role.name
  policy_arn = each.value
}

/**
 * Karpenterのコントロールpodに付与するロール
 */
resource "aws_iam_role" "karpenter_controller_role" {
  name = "${var.app_name}-${var.stage}-KarpenterControllerRole"
  assume_role_policy = jsonencode({
    "Version": "2012-10-17"
    "Statement": {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::${local.account_id}:oidc-provider/${local.oidc_provider}"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "${local.oidc_provider}:sub": "system:serviceaccount:${local.namespace}:${local.service_account}",
          "${local.oidc_provider}:aud": "sts.amazonaws.com"
        }
      }
    }
  })

  depends_on = [ aws_iam_policy.karpenter_controller_policy ]
}

resource "aws_iam_policy" "karpenter_controller_policy" {
  name = "${var.app_name}-${var.stage}-KarpenterControllerPolicy"
  policy = templatefile(
    "${path.module}/conf/karpenter_controller_policy_1.3.3.json",
    {
      cluster_name = local.cluster_name
      account_id   = local.account_id
      interruption_queue_arn = aws_sqs_queue.karpenter_interruption_queue.arn
      node_role_arn = aws_iam_role.karpenter_node_role.arn
    },
  )
}

resource "aws_iam_role_policy_attachment" "karpenter_controller_policy" {
  role = aws_iam_role.karpenter_controller_role.name
  policy_arn = aws_iam_policy.karpenter_controller_policy.arn
}

/**
 * KarpenterControllerRole に紐づくサービスアカウント
 * - kubernetes_service_account | Terraform
 *   https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/service_account
 */
resource "kubernetes_service_account" "karpenter_controller_role" {
  metadata {
    name      = local.service_account
    namespace = local.namespace
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.karpenter_controller_role.arn
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.karpenter_controller_policy
  ]
}

/**
 * KarpenterNodeRoleをIAM アクセスエントリに追加
 */
resource "aws_eks_access_entry" "karpenter_node_role" {
  // 公式ドキュメントにはconfigmapを利用するように記述されているが、アクセスエントリでも大丈夫らしい
  // https://github.com/aws/karpenter-provider-aws/issues/5369#issuecomment-1924774884
  cluster_name      = local.cluster_name
  principal_arn     = aws_iam_role.karpenter_node_role.arn
  type              = "EC2_LINUX"
}


/**
 * ノードの中断イベントを監視するためのSQS
 * https://karpenter.sh/v0.37/concepts/disruption/#interruption
 *
 * Karpenterでは、AWSサービスからノードに影響を及ぼす可能性のある中断イベント(spot中断など)をSQSを通じてキャッチします。
 * SQSからイベントを受信すると、Karpenterはtaint, drain, を実行して適切にノードを終了させます。
 * このSQSにはEventBridgeルールから下記のイベントが送信されます。
 * - スポットの中断警告
 * - スケジュールされた変更ヘルス イベント (メンテナンス イベント)
 * - インスタンス終了イベント
 * - インスタンス停止イベント
 */
resource "aws_sqs_queue" "karpenter_interruption_queue" {
  name = "${var.app_name}-${var.stage}-KarpenterInterruptionQueue"
  # メッセージ保持期間 (秒)
  message_retention_seconds = 300
  # メッセージの暗号化
  sqs_managed_sse_enabled = true
}

resource "aws_sqs_queue_policy" "karpenter_interruption_queue" {
  queue_url = aws_sqs_queue.karpenter_interruption_queue.id
  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Principal": {
          "Service": [
            "events.amazonaws.com",
            "sqs.amazonaws.com",
          ]
        },
        "Action": "sqs:SendMessage",
        "Resource": "${aws_sqs_queue.karpenter_interruption_queue.arn}",
      },
      {
        "Sid": "DenyHTTP",
        "Effect": "Deny",
        "Principal": "*",
        "Action": "sqs:*",
        "Resource": "${aws_sqs_queue.karpenter_interruption_queue.arn}",
        "Condition": {
          "Bool": {
            "aws:SecureTransport": false
          }
        }

      }
    ]
  })
}

/**
 * ノードのメンテナンスイベントを監視するためのCloudWatch Event Rule
 */
resource "aws_cloudwatch_event_rule" "scheduled_change_rule" {
  name        = "${var.app_name}-${var.stage}-ScheduledChangeRule"
  event_pattern = jsonencode({
    source = [ "aws.health" ]
    detail-type = [ "AWS Health Event" ]
  })
}

resource "aws_cloudwatch_event_target" "scheduled_change_rule" {
  rule = aws_cloudwatch_event_rule.scheduled_change_rule.name
  target_id = "KarpenterInterruptionQueueTarget"
  arn = aws_sqs_queue.karpenter_interruption_queue.arn
}

/**
 * スポット中断イベントを監視するためのCloudWatch Event Rule
 */
resource "aws_cloudwatch_event_rule" "spot_interruption_rule" {
  name        = "${var.app_name}-${var.stage}-SpotInterruptionRule"
  event_pattern = jsonencode({
    source = [ "aws.ec2" ]
    detail-type = [ "EC2 Spot Instance Interruption Warning" ]
  })
}

resource "aws_cloudwatch_event_target" "spot_interruption_rule" {
  rule = aws_cloudwatch_event_rule.spot_interruption_rule.name
  target_id = "KarpenterInterruptionQueueTarget"
  arn = aws_sqs_queue.karpenter_interruption_queue.arn
}

/**
 * spotインスタンスで中断のリスクが高まった場合の通知を監視するためのCloudWatch Event Rule
 * - https://docs.aws.amazon.com/ja_jp/AWSEC2/latest/UserGuide/rebalance-recommendations.html
 */
resource "aws_cloudwatch_event_rule" "rebalance_rule" {
  name        = "${var.app_name}-${var.stage}-RebalanceRule"
  event_pattern = jsonencode({
    source = [ "aws.ec2" ]
    detail-type = [ "EC2 Instance Rebalance Recommendation" ]
  })
}

resource "aws_cloudwatch_event_target" "rebalance_rule" {
  rule = aws_cloudwatch_event_rule.rebalance_rule.name
  target_id = "KarpenterInterruptionQueueTarget"
  arn = aws_sqs_queue.karpenter_interruption_queue.arn
}

/**
 * インスタンスの状態(pending,running, stoping, terminated, etc..)
 * が変更された際に通知を受け取るためのCloudWatch Event Rule
 * - https://docs.aws.amazon.com/ja_jp/AWSEC2/latest/UserGuide/monitoring-instance-state-changes.html
 */
resource "aws_cloudwatch_event_rule" "instance_state_change_rule" {
  name        = "${var.app_name}-${var.stage}-InstanceStateChangeRule"
  event_pattern = jsonencode({
    source = [ "aws.ec2" ]
    detail-type = [ "EC2 Instance State-change Notification" ]
  })
}

resource "aws_cloudwatch_event_target" "instance_state_change_rule" {
  rule = aws_cloudwatch_event_rule.instance_state_change_rule.name
  target_id = "KarpenterInterruptionQueueTarget"
  arn = aws_sqs_queue.karpenter_interruption_queue.arn
}


/**
 * Karpenterのvalues.yamlを作成します。
 */
resource "local_file" "karpenter_values_1_1_0" {
  filename = "${var.project_dir}/plugin/karpenter/${var.stage}/conf/values_1.1.0.yaml"
  directory_permission = "0755"
  file_permission = "0644"
  content = templatefile(
    "${path.module}/conf/karpenter_values_1.1.0.yaml",
    {
      cluster_name = local.cluster_name
      interruption_queue_name = "${var.app_name}-${var.stage}-KarpenterInterruptionQueue"
      service_account = local.service_account
    }
  )
}
resource "local_file" "karpenter_values_1_3_3" {
  filename = "${var.project_dir}/plugin/karpenter/${var.stage}/conf/values_1.3.3.yaml"
  directory_permission = "0755"
  file_permission = "0644"
  content = templatefile(
    "${path.module}/conf/karpenter_values_1.3.3.yaml",
    {
      cluster_name = local.cluster_name
      interruption_queue_name = "${var.app_name}-${var.stage}-KarpenterInterruptionQueue"
      service_account = local.service_account
    }
  )
}

/**
 * karpenter管理ノードの追加セキュリティグループ
 */
data "aws_eks_cluster" "this" {
  name = local.cluster_name
}

resource "aws_security_group" "additional_node_sg" {
  name        = "${var.app_name}-${var.stage}-karpenter-AdditionalNodeSecurityGroup"
  description = "additional security group for karpenter node."
  vpc_id      = data.aws_eks_cluster.this.vpc_config[0].vpc_id

  ingress {
    description = "Allow cluster SecurityGroup access."
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks      = ["10.0.0.0/8"]
  }

  tags = {
    "Name" = "${var.app_name}-${var.stage}-karpenter-AdditionalNodeSecurityGroup"
    "karpenter.sh/discovery" = local.cluster_name
  }
}

/**
 * EC2NodeClass のマニフェスト
 */
resource "local_file" "ec2_node_class" {
  for_each = toset([
    "nodeclass-al2023-x86-64.yaml",
    "nodeclass-al2-x86-64-nvidia.yaml",
    "nodeclass-bottlerocket-aarch64-nvidia.yaml",
    "nodeclass-bottlerocket-x86-64-nvidia.yaml",
    "nodeclass-bottlerocket-x86-64.yaml",
  ])
  filename = "${var.project_dir}/plugin/karpenter/${var.stage}/nodeclass/${each.key}"
  directory_permission = "0755"
  file_permission = "0644"
  content = templatefile(
    "${path.module}/manifest/${each.key}",
    {
      karpenter_node_role_name = aws_iam_role.karpenter_node_role.name
      cluster_name = local.cluster_name
      cluster_version = var.eks_cluster_version
      cluster_endpoint = var.eks_cluster_endpoint
      cluster_certificate_authority_data = var.eks_cluster_certificate_authority_data
      cluster_service_cidr = var.eks_cluster_service_cidr
    }
  )
}


/**
 * NodePool のマニフェスト
 */
resource "local_file" "node_pool" {
  for_each = toset([
    "nodepool-al2023-x86-64-standard.yaml",
    "nodepool-bottlerocket-aarch64-nvidia-standard.yaml",
    "nodepool-bottlerocket-x86-64-nvidia-standard.yaml",
    "nodepool-al2-x86-64-nvidia.yaml",
    "nodepool-bottlerocket-x86-64-nvidia-g6.yaml",
    "nodepool-bottlerocket-x86-64-standard.yaml",
  ])
  filename = "${var.project_dir}/plugin/karpenter/${var.stage}/nodepool/${each.key}"
  directory_permission = "0755"
  file_permission = "0644"
  content = templatefile(
    "${path.module}/manifest/${each.key}",
    {
    }
  )
}
/**
 * 作成するリソース
 *   - Getting Started | karpenter: https://karpenter.sh/docs/getting-started/getting-started-with-karpenter/
 *   - CloudFormation | karpenter: https://karpenter.sh/docs/reference/cloudformation/
 * 
 */
/**
 * ノードをプロビジョニングするためのロール
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

// Amazon VPC CNI プラグインが EKS ワーカーノードを構成するために必要な権限
resource "aws_iam_role_policy_attachment" "amazoneks_cni_policy" {
  role = aws_iam_role.karpenter_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}
// Amazon EKS ワーカーノードが EKS クラスターに接続できるようにする
resource "aws_iam_role_policy_attachment" "amazon_eks_worker_node_policy" {
  role = aws_iam_role.karpenter_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}
// Amazon EC2 コンテナレジストリ内のリポジトリへの読み取り専用アクセスを許可
resource "aws_iam_role_policy_attachment" "amazon_ec2_container_registry_read_only" {
  role = aws_iam_role.karpenter_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}
// Amazon EC2 用の AWS Systems Manager サービスコア機能
resource "aws_iam_role_policy_attachment" "amazon_ssm_managed_instance_core" {
  role = aws_iam_role.karpenter_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

/**
 * KarpenterControllerPolicy
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

resource "aws_iam_role_policy_attachment" "karpenter_controller_policy" {
  role = aws_iam_role.karpenter_controller_role.name
  policy_arn = aws_iam_policy.karpenter_controller_policy.arn
}


resource "aws_iam_policy" "karpenter_controller_policy" {
  name = "${var.app_name}-${var.stage}-KarpenterControllerPolicy"
  policy = jsonencode(
    {
      "Version": "2012-10-17",
      "Statement": [
        {
          "Sid": "AllowScopedEC2InstanceAccessActions",
          "Effect": "Allow",
          "Resource": [
            "arn:aws:ec2:ap-northeast-1::image/*",
            "arn:aws:ec2:ap-northeast-1::snapshot/*",
            "arn:aws:ec2:ap-northeast-1:*:security-group/*",
            "arn:aws:ec2:ap-northeast-1:*:subnet/*"
          ],
          "Action": [
            "ec2:RunInstances",
            "ec2:CreateFleet"
          ]
        },
        {
          "Sid": "AllowScopedEC2LaunchTemplateAccessActions",
          "Effect": "Allow",
          "Resource": "arn:aws:ec2:ap-northeast-1:*:launch-template/*",
          "Action": [
            "ec2:RunInstances",
            "ec2:CreateFleet"
          ],
          "Condition": {
            "StringEquals": {
              "aws:ResourceTag/kubernetes.io/cluster/${local.cluster_name}": "owned"
            },
            "StringLike": {
              "aws:ResourceTag/karpenter.sh/nodepool": "*"
            }
          }
        },
        {
          "Sid": "AllowScopedEC2InstanceActionsWithTags",
          "Effect": "Allow",
          "Resource": [
            "arn:aws:ec2:ap-northeast-1:*:fleet/*",
            "arn:aws:ec2:ap-northeast-1:*:instance/*",
            "arn:aws:ec2:ap-northeast-1:*:volume/*",
            "arn:aws:ec2:ap-northeast-1:*:network-interface/*",
            "arn:aws:ec2:ap-northeast-1:*:launch-template/*",
            "arn:aws:ec2:ap-northeast-1:*:spot-instances-request/*"
          ],
          "Action": [
            "ec2:RunInstances",
            "ec2:CreateFleet",
            "ec2:CreateLaunchTemplate"
          ],
          "Condition": {
            "StringEquals": {
              "aws:RequestTag/kubernetes.io/cluster/${local.cluster_name}": "owned"
            },
            "StringLike": {
              "aws:RequestTag/karpenter.sh/nodepool": "*"
            }
          }
        },
        {
          "Sid": "AllowScopedResourceCreationTagging",
          "Effect": "Allow",
          "Resource": [
            "arn:aws:ec2:ap-northeast-1:*:fleet/*",
            "arn:aws:ec2:ap-northeast-1:*:instance/*",
            "arn:aws:ec2:ap-northeast-1:*:volume/*",
            "arn:aws:ec2:ap-northeast-1:*:network-interface/*",
            "arn:aws:ec2:ap-northeast-1:*:launch-template/*",
            "arn:aws:ec2:ap-northeast-1:*:spot-instances-request/*"
          ],
          "Action": "ec2:CreateTags",
          "Condition": {
            "StringEquals": {
              "aws:RequestTag/kubernetes.io/cluster/${local.cluster_name}": "owned",
              "ec2:CreateAction": [
                "RunInstances",
                "CreateFleet",
                "CreateLaunchTemplate"
              ]
            },
            "StringLike": {
              "aws:RequestTag/karpenter.sh/nodepool": "*"
            }
          }
        },
        {
          "Sid": "AllowScopedResourceTagging",
          "Effect": "Allow",
          "Resource": "arn:aws:ec2:ap-northeast-1:*:instance/*",
          "Action": "ec2:CreateTags",
          "Condition": {
            "StringEquals": {
              "aws:ResourceTag/kubernetes.io/cluster/${local.cluster_name}": "owned"
            },
            "StringLike": {
              "aws:ResourceTag/karpenter.sh/nodepool": "*"
            },
            "ForAllValues:StringEquals": {
              "aws:TagKeys": [
                "karpenter.sh/nodeclaim",
                "Name"
              ]
            }
          }
        },
        {
          "Sid": "AllowScopedDeletion",
          "Effect": "Allow",
          "Resource": [
            "arn:aws:ec2:ap-northeast-1:*:instance/*",
            "arn:aws:ec2:ap-northeast-1:*:launch-template/*"
          ],
          "Action": [
            "ec2:TerminateInstances",
            "ec2:DeleteLaunchTemplate"
          ],
          "Condition": {
            "StringEquals": {
              "aws:ResourceTag/kubernetes.io/cluster/${local.cluster_name}": "owned"
            },
            "StringLike": {
              "aws:ResourceTag/karpenter.sh/nodepool": "*"
            }
          }
        },
        {
          "Sid": "AllowRegionalReadActions",
          "Effect": "Allow",
          "Resource": "*",
          "Action": [
            "ec2:DescribeAvailabilityZones",
            "ec2:DescribeImages",
            "ec2:DescribeInstances",
            "ec2:DescribeInstanceTypeOfferings",
            "ec2:DescribeInstanceTypes",
            "ec2:DescribeLaunchTemplates",
            "ec2:DescribeSecurityGroups",
            "ec2:DescribeSpotPriceHistory",
            "ec2:DescribeSubnets"
          ],
          "Condition": {
            "StringEquals": {
              "aws:RequestedRegion": "ap-northeast-1"
            }
          }
        },
        {
          "Sid": "AllowSSMReadActions",
          "Effect": "Allow",
          "Resource": "arn:aws:ssm:ap-northeast-1::parameter/aws/service/*",
          "Action": "ssm:GetParameter"
        },
        {
          "Sid": "AllowPricingReadActions",
          "Effect": "Allow",
          "Resource": "*",
          "Action": "pricing:GetProducts"
        },
        {
          "Sid": "AllowInterruptionQueueActions",
          "Effect": "Allow",
          "Resource": "${aws_sqs_queue.karpenter_interruption_queue.arn}",
          "Action": [
            "sqs:DeleteMessage",
            "sqs:GetQueueUrl",
            "sqs:ReceiveMessage"
          ]
        },
        {
          "Sid": "AllowPassingInstanceRole",
          "Effect": "Allow",
          "Resource": "${aws_iam_role.karpenter_node_role.arn}",
          "Action": "iam:PassRole",
          "Condition": {
            "StringEquals": {
              "iam:PassedToService": "ec2.amazonaws.com"
            }
          }
        },
        {
          "Sid": "AllowScopedInstanceProfileCreationActions",
          "Effect": "Allow",
          "Resource": "*",
          "Action": [
            "iam:CreateInstanceProfile"
          ],
          "Condition": {
            "StringEquals": {
              "aws:RequestTag/kubernetes.io/cluster/${local.cluster_name}": "owned",
              "aws:RequestTag/topology.kubernetes.io/region": "ap-northeast-1"
            },
            "StringLike": {
              "aws:RequestTag/karpenter.k8s.aws/ec2nodeclass": "*"
            }
          }
        },
        {
          "Sid": "AllowScopedInstanceProfileTagActions",
          "Effect": "Allow",
          "Resource": "*",
          "Action": [
            "iam:TagInstanceProfile"
          ],
          "Condition": {
            "StringEquals": {
              "aws:ResourceTag/kubernetes.io/cluster/${local.cluster_name}": "owned",
              "aws:ResourceTag/topology.kubernetes.io/region": "ap-northeast-1",
              "aws:RequestTag/kubernetes.io/cluster/${local.cluster_name}": "owned",
              "aws:RequestTag/topology.kubernetes.io/region": "ap-northeast-1"
            },
            "StringLike": {
              "aws:ResourceTag/karpenter.k8s.aws/ec2nodeclass": "*",
              "aws:RequestTag/karpenter.k8s.aws/ec2nodeclass": "*"
            }
          }
        },
        {
          "Sid": "AllowScopedInstanceProfileActions",
          "Effect": "Allow",
          "Resource": "*",
          "Action": [
            "iam:AddRoleToInstanceProfile",
            "iam:RemoveRoleFromInstanceProfile",
            "iam:DeleteInstanceProfile"
          ],
          "Condition": {
            "StringEquals": {
              "aws:ResourceTag/kubernetes.io/cluster/${local.cluster_name}": "owned",
              "aws:ResourceTag/topology.kubernetes.io/region": "ap-northeast-1"
            },
            "StringLike": {
              "aws:ResourceTag/karpenter.k8s.aws/ec2nodeclass": "*"
            }
          }
        },
        {
          "Sid": "AllowInstanceProfileReadActions",
          "Effect": "Allow",
          "Resource": "*",
          "Action": "iam:GetInstanceProfile"
        },
        {
          "Sid": "AllowAPIServerEndpointDiscovery",
          "Effect": "Allow",
          "Resource": "arn:aws:eks:ap-northeast-1:${local.account_id}:cluster/${local.cluster_name}",
          "Action": "eks:DescribeCluster"
        }
      ]
    }
  )
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
}

/**
 * KarpenterNodeRoleにEKSの権限(system:bootstrappers, system:nodes)を付与
 */
resource "null_resource" "run_script" {
  triggers = {
    cluster_name = "${local.cluster_name}"
    karpenter_node_role_arn = "${aws_iam_role.karpenter_node_role.arn}"
  }
  
  // local-exec | terraform: https://developer.hashicorp.com/terraform/language/resources/provisioners/local-exec
  provisioner "local-exec" {
    command = <<EOT
eksctl create iamidentitymapping \
  --cluster ${local.cluster_name} \
  --region ${local.region} \
  --arn ${aws_iam_role.karpenter_node_role.arn} \
  --group system:bootstrappers,system:nodes \
  --username system:node:{{EC2PrivateDNSName}}
EOT
  }

  // local-exec | terraform: https://developer.hashicorp.com/terraform/language/resources/provisioners/local-exec
  provisioner "local-exec" {
    command = <<EOT
eksctl delete iamidentitymapping \
  --cluster ${self.triggers.cluster_name} \
  --arn ${self.triggers.karpenter_node_role_arn}
EOT
    when        = destroy
  }
  depends_on = [ aws_iam_role.karpenter_node_role ]
}

/**
 * 割り込みキュー
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
        "Resource": aws_sqs_queue.karpenter_interruption_queue.arn,
      }
    ]
  })
}

/**
 * ScheduledChangeRule
 */
resource "aws_cloudwatch_event_rule" "scheduled_change_rule" {
  name        = "${var.app_name}-${var.stage}-ScheduledChangeRule"
  event_pattern = jsonencode({
    source = [
      "aws.health"
    ],
    detail-type = [
      "AWS Health Event"
    ]
  })
}

resource "aws_cloudwatch_event_target" "scheduled_change_rule" {
  rule = aws_cloudwatch_event_rule.scheduled_change_rule.name
  target_id = "KarpenterInterruptionQueueTarget"
  arn = aws_sqs_queue.karpenter_interruption_queue.arn
}

/**
 * SpotInterruptionRule
 */
resource "aws_cloudwatch_event_rule" "spot_interruption_rule" {
  name        = "${var.app_name}-${var.stage}-SpotInterruptionRule"
  event_pattern = jsonencode({
    source = [
      "aws.ec2"
    ],
    detail-type = [
      "EC2 Spot Instance Interruption Warning"
    ]
  })
}

resource "aws_cloudwatch_event_target" "spot_interruption_rule" {
  rule = aws_cloudwatch_event_rule.spot_interruption_rule.name
  target_id = "KarpenterInterruptionQueueTarget"
  arn = aws_sqs_queue.karpenter_interruption_queue.arn
}

/**
 * RebalanceRule
 */
resource "aws_cloudwatch_event_rule" "rebalance_rule" {
  name        = "${var.app_name}-${var.stage}-RebalanceRule"
  event_pattern = jsonencode({
    source = [
      "aws.ec2"
    ],
    detail-type = [
      "EC2 Instance Rebalance Recommendation"
    ]
  })
}

resource "aws_cloudwatch_event_target" "rebalance_rule" {
  rule = aws_cloudwatch_event_rule.rebalance_rule.name
  target_id = "KarpenterInterruptionQueueTarget"
  arn = aws_sqs_queue.karpenter_interruption_queue.arn
}

/**
 * InstanceStateChangeRule
 */
resource "aws_cloudwatch_event_rule" "instance_state_change_rule" {
  name        = "${var.app_name}-${var.stage}-InstanceStateChangeRule"
  event_pattern = jsonencode({
    source = [
      "aws.ec2"
    ],
    detail-type = [
      "EC2 Instance State-change Notification"
    ]
  })
}

resource "aws_cloudwatch_event_target" "instance_state_change_rule" {
  rule = aws_cloudwatch_event_rule.instance_state_change_rule.name
  target_id = "KarpenterInterruptionQueueTarget"
  arn = aws_sqs_queue.karpenter_interruption_queue.arn
}

/**
 * karpenterチャートをインストールします。
 *
 * 参考
 *   - リポジトリ | AWS: https://gallery.ecr.aws/karpenter/karpenter
 *   - karpenter-provider-aws | GitHub: https://github.com/aws/karpenter-provider-aws/tree/v0.37.0
 */

//helm_release - helm - terraform: https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release
resource "helm_release" "karpenter" {
  name       = "karpenter"
  #repository = "xxxxxxxxxxxxxxxxxxxxx"
  chart      = "oci://public.ecr.aws/karpenter/karpenter"
  version    = local.version
  namespace  = local.namespace
  create_namespace = true

  /**
   * values: https://github.com/aws/karpenter-provider-aws/blob/main/charts/karpenter/values.yaml
   */
  set {
    name  = "settings.clusterName"
    value = local.cluster_name
  }

  set {
    name  = "settings.interruptionQueue"
    value = "${var.app_name}-${var.stage}-KarpenterInterruptionQueue"
  }

  set {
    name  = "controller.resources.requests.cpu"
    value = "1"
  }

  set {
    name  = "controller.resources.requests.memory"
    value = "1Gi"
  }

  set {
    name  = "controller.resources.limits.cpu"
    value = "1"
  }

  set {
    name  = "controller.resources.limits.memory"
    value = "1Gi"
  }

  set {
    name = "serviceAccount.create"
    value = false
  }

  set {
    name  = "serviceAccount.name"
    value = local.service_account
  }


  wait = true

  depends_on = [
    aws_iam_role.karpenter_controller_role,
    aws_sqs_queue.karpenter_interruption_queue
  ]
}
/**
 * OpenCost
 * - Install | OpenCost: https://www.opencost.io/docs/installation/helm
 * - OpenCost | Github: https://github.com/opencost/opencost-helm-chart/tree/main/charts/opencost
 * - Install Prometheus | OpenCost: https://www.opencost.io/docs/installation/prometheus
 * - Prometheus - helm-charts | Github: https://github.com/prometheus-community/helm-charts/tree/main/charts/prometheus
 */
//helm_release: https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release
resource "helm_release" "opencost" {
  name       = "opencost"
  chart      = "opencost"
  repository = "https://opencost.github.io/opencost-helm-chart"
  // バージョンの確認: https://github.com/opencost/opencost-helm-chart/blob/main/charts/opencost/Chart.yaml
  version    = "1.42.0"
  namespace  = local.namespace
  create_namespace = true

  # 設定値: https://github.com/opencost/opencost-helm-chart/blob/main/charts/opencost/values.yaml
  values = [
    templatefile("${path.module}/values.yaml",{
      account_id = local.account_id,
      cluster_name = var.cluster_name,
      servicea_account_role_arn = aws_iam_role.opencost_sa_role.arn,
      datafeed_bucket_name = var.datafeed_bucket_name,
    }),
  ]
  depends_on = [
    aws_eks_pod_identity_association.opencost
   ]
}

/**
 * OpenCostポッドに割り当てるIAMロールを作成する
 * Pod Identity を利用する
 */
resource "aws_iam_role" "opencost_sa_role" {
  name = "${var.app_name}-${var.stage}-OpenCostServiceAccountRole"
  assume_role_policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "AllowEksAuthToAssumeRoleForPodIdentity",
            "Effect": "Allow",
            "Principal": {
                "Service": "pods.eks.amazonaws.com"
            },
            "Action": [
                "sts:AssumeRole",
                "sts:TagSession"
            ]
        }
    ]
  })

  depends_on = [ aws_iam_policy.s3_spot_datafeed_access_policy ]
}

resource "aws_iam_policy" "s3_spot_datafeed_access_policy" {
  name = "${var.app_name}-${var.stage}-s3SpotDatafeedAccessPolicy"
  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": [
                "s3:ListAllMyBuckets",
                "s3:ListBucket",
                #"s3:HeadBucket",
                #"s3:HeadObject",
                "s3:List*",
                "s3:Get*"
            ],
            "Resource": [
                "arn:aws:s3:::${var.datafeed_bucket_name}",
                "arn:aws:s3:::${var.datafeed_bucket_name}/*",
            ],
            "Effect": "Allow",
            "Sid": "SpotDataAccess"
        }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "s3_spot_datafeed_access_policy" {
  role = aws_iam_role.opencost_sa_role.name
  policy_arn = aws_iam_policy.s3_spot_datafeed_access_policy.arn
}

/**
 * Pod Identityとしてロールを登録
 */
resource "aws_eks_pod_identity_association" "opencost" {
  cluster_name    = var.cluster_name
  namespace       = local.namespace
  service_account = local.service_account
  role_arn        = aws_iam_role.opencost_sa_role.arn
}
/**
 * fargate-profile (terraform-aws-modules/eks/aws のサブモジュール)
 *   - https://github.com/terraform-aws-modules/terraform-aws-eks/tree/v20.14.0/modules/fargate-profile
 * Fargateプロファイルの設定項目
 *   - https://docs.aws.amazon.com/ja_jp/eks/latest/userguide/fargate.html#fargate-considerations
 * EKSにおけるFargateの制約事項
 *   - https://docs.aws.amazon.com/ja_jp/eks/latest/userguide/fargate.html#fargate-considerations
 */

 module "fargate_profile" {
  source = "terraform-aws-modules/eks/aws//modules/fargate-profile"
  name         = var.profile_name
  cluster_name = var.cluster_name
  subnet_ids = var.private_subnets  # プライベートサブネットのみ指定可能

  # 自分で作ったPod実行ロールを指定
  create_iam_role = false
  iam_role_arn = var.eks_fargate_pod_execution_role_arn

  // このプロファイルで実行する Pod のセレクタを指定します。
  //   - https://docs.aws.amazon.com/ja_jp/eks/latest/userguide/fargate.html#fargate-considerations
  // 説明
  //   - ワイルドカードは任意の複数文字にマッチする`*` と、任意の一文字にマッチする`?` の2つが使用可能です。
  //   - namespaceのみが指定された場合はそのnamespaceに属するすべてのPodがFargateで実行されます。
  //   - namespaceとlabelsが指定された場合はそのnamespaceに属し、かつ指定されたlabelsを持つPodがFargateで実行されます。
  selectors = var.selectors
}

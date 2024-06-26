// terraform-aws-modules/vpc/aws
//   - https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws/latest
// terraform-aws-eks example fargate_profile
//   - https://github.com/terraform-aws-modules/terraform-aws-eks/blob/v20.14.0/examples/fargate_profile/main.tf#L120
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
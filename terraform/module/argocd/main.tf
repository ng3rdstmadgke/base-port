resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"
  }

  lifecycle {
    ignore_changes = all
  }
}

resource "null_resource" "run_script" {
  triggers = {
    # wget https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
    file_hash = filebase64sha256("${path.module}/install.yaml")
  }
  
 provisioner "local-exec" {
    command = "kubectl apply -n argocd -f ${path.module}/install.yaml > argocd_install.log"
  }

  depends_on = [ kubernetes_namespace.argocd ]
}

/**
 * GitHub ActionsがAWSリソースにOIDC認証でアクセスできるようにするためのIDプロバイダを作成します。
 * 
 * 参考
 *   - GitHub Actions で OIDC を使用して AWS 認証を行う | Zenn
 *     https://zenn.dev/kou_pg_0131/articles/gh-actions-oidc-aws
 *   - AWSの「IDプロバイダーとフェデレーション」の仕組みを利用して、GoogleアカウントでAWSを利用・操作してみた
 *     https://note.com/shift_tech/n/nf5eb16948de1
 *   - IAM ロールを使用して GitHub アクションを AWS のアクションに接続する | AWS セキュリティブログ
 *     https://aws.amazon.com/jp/blogs/security/use-iam-roles-to-connect-github-actions-to-actions-in-aws/
 */
// GitHub ActionsのOIDCプロバイダの信頼性を検証するための証明書を取得
data "tls_certificate" "github_actions" {
  url = "https://token.actions.githubusercontent.com"
}

// AWSにGitHub ActionsのOIDCプロバイダを登録します。
// これによりAWSはGitHub Actionsからの認証リクエストを信頼し、適切なIAMロールへのアクセスを許可することができます。
resource "aws_iam_openid_connect_provider" "github" {
  // GitHub ActionsのOIDCプロバイダのURL
  url             = "https://token.actions.githubusercontent.com"
  // GitHub Actionsに発行された信頼されるクライアントID
  client_id_list  = ["sts.amazonaws.com"]
  // 信頼される証明書のフィンガープリント
  // GitHubActionsのOIDCプロバイダの信頼性を検証するための証明書のSHA-1フィンガープリント
  thumbprint_list = [data.tls_certificate.github_actions.certificates[0].sha1_fingerprint]

  tags = {
    Name = "GitHubActionsProvider"
  }
}
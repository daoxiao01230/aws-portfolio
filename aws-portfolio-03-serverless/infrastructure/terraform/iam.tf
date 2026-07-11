# ============================================================
# 既存IAMユーザーへの権限追加
# Phase 1で作成した github-actions-portfolio-01 を新規作成せず流用する
# （Phase毎にIAMユーザー・GitHub Secretsを増やさない方針）
# ============================================================
data "aws_iam_user" "github_actions" {
  user_name = var.github_actions_iam_user_name
}

# CI/CDが担うのは「Lambda関数コードの更新」のみに限定する
# （Cognito/API Gateway/DynamoDBなどのインフラ変更はPhase 2と同様、
#   ローカルから terraform apply で手動デプロイする方針。
#   理由: CI用IAMユーザーにIAMロール作成権限まで持たせたくないため）
resource "aws_iam_user_policy" "github_actions_lambda_deploy" {
  name = "portfolio-03-lambda-deploy-policy"
  user = data.aws_iam_user.github_actions.user_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "LambdaCodeDeploy"
        Effect = "Allow"
        Action = [
          "lambda:UpdateFunctionCode",
        ]
        Resource = [
          aws_lambda_function.create_entry.arn,
          aws_lambda_function.list_entries.arn,
          aws_lambda_function.update_entry.arn,
          aws_lambda_function.delete_entry.arn,
        ]
      }
    ]
  })
}

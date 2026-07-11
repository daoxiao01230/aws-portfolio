output "api_endpoint" {
  description = "HTTP APIのベースURL（Reactアプリの環境変数に設定する）"
  value       = aws_apigatewayv2_stage.default.invoke_url
}

output "cognito_user_pool_id" {
  description = "Reactアプリの認証設定（Amplify config等）に使用"
  value       = aws_cognito_user_pool.main.id
}

output "cognito_user_pool_client_id" {
  description = "Reactアプリの認証設定（Amplify config等）に使用"
  value       = aws_cognito_user_pool_client.spa.id
}

output "dynamodb_table_name" {
  value = aws_dynamodb_table.entries.name
}

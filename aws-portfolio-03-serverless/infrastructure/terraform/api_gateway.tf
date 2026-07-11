# ============================================================
# API Gateway（HTTP API）
# REST APIより低コスト・低設定。JWT Authorizerを標準搭載しているため、
# Cognito User PoolのIDトークンをそのまま検証できる
# ============================================================
resource "aws_apigatewayv2_api" "main" {
  name          = "${var.project_name}-api"
  protocol_type = "HTTP"

  cors_configuration {
    # 理由: ReactアプリからのブラウザFetchを許可する必要がある
    # Phase 2でカスタムドメインを取得済みのため、本番ではそちらに絞る想定
    allow_origins = ["*"]
    allow_methods = ["GET", "POST", "PUT", "DELETE", "OPTIONS"]
    allow_headers = ["content-type", "authorization"]
  }

  tags = {
    Project = var.project_name
  }
}

# デフォルトステージ（$default）で自動デプロイ
# 理由: HTTP APIはステージ管理がシンプル。REST APIのような手動デプロイ操作が不要
resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.main.id
  name        = "$default"
  auto_deploy = true
}

# ============================================================
# JWT Authorizer
# Cognito User Poolが発行したIDトークンを検証する
# 検証OKのリクエストのみLambdaに到達させる
# ============================================================
resource "aws_apigatewayv2_authorizer" "cognito" {
  api_id           = aws_apigatewayv2_api.main.id
  authorizer_type  = "JWT"
  identity_sources = ["$request.header.Authorization"]
  name             = "${var.project_name}-cognito-authorizer"

  jwt_configuration {
    audience = [aws_cognito_user_pool_client.spa.id]
    issuer   = "https://cognito-idp.${var.aws_region}.amazonaws.com/${aws_cognito_user_pool.main.id}"
  }
}

# ============================================================
# Lambda統合（4本）
# HTTP APIとLambdaを結びつける
# ============================================================
resource "aws_apigatewayv2_integration" "create_entry" {
  api_id                 = aws_apigatewayv2_api.main.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.create_entry.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_integration" "list_entries" {
  api_id                 = aws_apigatewayv2_api.main.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.list_entries.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_integration" "update_entry" {
  api_id                 = aws_apigatewayv2_api.main.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.update_entry.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_integration" "delete_entry" {
  api_id                 = aws_apigatewayv2_api.main.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.delete_entry.invoke_arn
  payload_format_version = "2.0"
}

# ============================================================
# ルート（4本）
# 全ルートにJWT Authorizerを必須で紐付ける
# ============================================================
resource "aws_apigatewayv2_route" "create_entry" {
  api_id             = aws_apigatewayv2_api.main.id
  route_key          = "POST /entries"
  target             = "integrations/${aws_apigatewayv2_integration.create_entry.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id
}

resource "aws_apigatewayv2_route" "list_entries" {
  api_id             = aws_apigatewayv2_api.main.id
  route_key          = "GET /entries"
  target             = "integrations/${aws_apigatewayv2_integration.list_entries.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id
}

resource "aws_apigatewayv2_route" "update_entry" {
  api_id             = aws_apigatewayv2_api.main.id
  route_key          = "PUT /entries/{id}"
  target             = "integrations/${aws_apigatewayv2_integration.update_entry.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id
}

resource "aws_apigatewayv2_route" "delete_entry" {
  api_id             = aws_apigatewayv2_api.main.id
  route_key          = "DELETE /entries/{id}"
  target             = "integrations/${aws_apigatewayv2_integration.delete_entry.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id
}

# ============================================================
# Lambda呼び出し許可
# API GatewayがLambdaを呼び出せるようにリソースベースポリシーを付与
# ============================================================
resource "aws_lambda_permission" "create_entry" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.create_entry.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.main.execution_arn}/*/*"
}

resource "aws_lambda_permission" "list_entries" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.list_entries.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.main.execution_arn}/*/*"
}

resource "aws_lambda_permission" "update_entry" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.update_entry.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.main.execution_arn}/*/*"
}

resource "aws_lambda_permission" "delete_entry" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.delete_entry.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.main.execution_arn}/*/*"
}

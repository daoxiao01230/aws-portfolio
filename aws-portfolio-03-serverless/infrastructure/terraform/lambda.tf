# ============================================================
# Lambda 実行ロール
# 4つのLambda関数が共通で使うロール（DynamoDB CRUD + CloudWatch Logs）
# ============================================================
resource "aws_iam_role" "lambda_exec" {
  name = "${var.project_name}-lambda-exec"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Project = var.project_name
  }
}

# CloudWatch Logsへの書き込み権限（AWS管理ポリシー）
resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# DynamoDBテーブルへのCRUD権限（このテーブルのみに限定）
resource "aws_iam_role_policy" "lambda_dynamodb" {
  name = "${var.project_name}-lambda-dynamodb"
  role = aws_iam_role.lambda_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:Query",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
        ]
        Resource = aws_dynamodb_table.entries.arn
      }
    ]
  })
}

# ============================================================
# Lambda関数コードのzip化
# archive プロバイダで各ハンドラーのディレクトリをzip化する
# ============================================================
data "archive_file" "create_entry" {
  type        = "zip"
  source_dir  = "${path.module}/../../backend/lambda/create_entry"
  output_path = "${path.module}/build/create_entry.zip"
}

data "archive_file" "list_entries" {
  type        = "zip"
  source_dir  = "${path.module}/../../backend/lambda/list_entries"
  output_path = "${path.module}/build/list_entries.zip"
}

data "archive_file" "update_entry" {
  type        = "zip"
  source_dir  = "${path.module}/../../backend/lambda/update_entry"
  output_path = "${path.module}/build/update_entry.zip"
}

data "archive_file" "delete_entry" {
  type        = "zip"
  source_dir  = "${path.module}/../../backend/lambda/delete_entry"
  output_path = "${path.module}/build/delete_entry.zip"
}

# ============================================================
# Lambda関数本体（4本）
# ランタイム: Python 3.12
# ============================================================
resource "aws_lambda_function" "create_entry" {
  function_name    = "${var.project_name}-create-entry"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.12"
  filename         = data.archive_file.create_entry.output_path
  source_code_hash = data.archive_file.create_entry.output_base64sha256

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.entries.name
    }
  }

  tags = {
    Project = var.project_name
  }
}

resource "aws_lambda_function" "list_entries" {
  function_name    = "${var.project_name}-list-entries"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.12"
  filename         = data.archive_file.list_entries.output_path
  source_code_hash = data.archive_file.list_entries.output_base64sha256

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.entries.name
    }
  }

  tags = {
    Project = var.project_name
  }
}

resource "aws_lambda_function" "update_entry" {
  function_name    = "${var.project_name}-update-entry"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.12"
  filename         = data.archive_file.update_entry.output_path
  source_code_hash = data.archive_file.update_entry.output_base64sha256

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.entries.name
    }
  }

  tags = {
    Project = var.project_name
  }
}

resource "aws_lambda_function" "delete_entry" {
  function_name    = "${var.project_name}-delete-entry"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.12"
  filename         = data.archive_file.delete_entry.output_path
  source_code_hash = data.archive_file.delete_entry.output_base64sha256

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.entries.name
    }
  }

  tags = {
    Project = var.project_name
  }
}

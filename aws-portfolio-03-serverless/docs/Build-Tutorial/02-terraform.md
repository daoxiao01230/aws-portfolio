[目次](./README.md) | 前へ: [Part 1 — 全体像](./01-overview.md) | 次へ: [Part 4 — フロントエンド(まず動かす)](./04-frontend-quickstart.md)

---

# Part 2 — Terraformで作る

### 2-0. フォルダを作る

```bash
mkdir -p aws-portfolio-03-serverless/infrastructure/terraform
cd aws-portfolio-03-serverless/infrastructure/terraform
```

以降、このディレクトリの中に`.tf`ファイルを1つずつ作っていく。Terraformは
「フォルダの中の`.tf`ファイル全部」を1つの設定として読むので、ファイルを
分けても分けなくても動作は同じ。役割ごとにファイルを分けるのは人間が
読みやすくするため。

### 2-1. providers.tf — 「AWSのどこを触るか」を宣言する

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
      # archive プロバイダ: Lambda関数コードをzip化するために使用
      # 理由: aws_lambda_function は zip ファイルのアップロードを要求するため、
      #       Terraform apply時にPythonコードを自動でzip化する
    }
  }
  required_version = ">= 1.0"
}

provider "aws" {
  region = var.aws_region
}

# CloudFrontで使うACM証明書はus-east-1でのみ発行可能という制約への対応
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}
```

> 💡 `provider`ブロックは「これから作るAWSリソースは、AWSのこのアカウント・
> このリージョンに作ってください」という宣言。2つ目の`us_east_1`エイリアスは
> Part 2-9（ACM証明書）で使う。CloudFrontで使うSSL証明書は、なぜかリージョンに
> 関係なく必ずus-east-1で発行しないといけないというAWS側の仕様がある。

### 2-2. variables.tf — 使い回す値をまとめる

```hcl
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-1"
}

variable "project_name" {
  description = "プロジェクト識別子。リソース名のプレフィックスとして使用"
  type        = string
  default     = "aws-portfolio-03-serverless"
}

variable "github_actions_iam_user_name" {
  description = "既存のGitHub Actions用IAMユーザー名"
  type        = string
  default     = "github-actions-portfolio-01"
}

variable "domain_name" {
  description = "フロントエンドのカスタムドメイン"
  type        = string
  default     = "journal.daoxiao.org"
  # 自分の環境で試す場合は、自分が所有しているドメインに置き換える
}

variable "hosted_zone_id" {
  description = "Route 53 Hosted Zone ID（自分のドメインのゾーンIDに置き換える）"
  type        = string
  default     = "Z06510601ASWSVLJJY29P"
}
```

> 💡 `variable`は関数の引数のようなもの。`default`があれば何も指定しなくても
> その値が使われる。自分の環境で試す場合は`domain_name`と`hosted_zone_id`を
> 自分のRoute 53ホストゾーンの値に書き換える（独自ドメインを持っていない場合は
> Part 2-9〜2-11のACM/CloudFront/Route53部分はスキップし、CloudFrontの
> デフォルトドメイン（`https://xxxx.cloudfront.net`）だけで公開してもよい）。

### 2-3. cognito.tf — 会員証発行窓口を作る

```hcl
resource "aws_cognito_user_pool" "main" {
  name = "${var.project_name}-users"

  # サインイン方法: メールアドレスをユーザー名として使用
  username_attributes       = ["email"]
  auto_verified_attributes  = ["email"]

  password_policy {
    minimum_length    = 8
    require_lowercase = true
    require_uppercase = true
    require_numbers   = true
    require_symbols   = false
  }

  tags = {
    Project = var.project_name
  }
}

resource "aws_cognito_user_pool_client" "spa" {
  name         = "${var.project_name}-spa-client"
  user_pool_id = aws_cognito_user_pool.main.id

  # SPA（ブラウザ上で動くJS）なのでクライアントシークレットは発行しない
  generate_secret = false

  explicit_auth_flows = [
    "ALLOW_USER_SRP_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
  ]
}
```

> 💡 `aws_cognito_user_pool`が「会員名簿そのもの」、`aws_cognito_user_pool_client`が
> 「そのアプリ専用の受付窓口」。1つの会員名簿に対して、複数のアプリ（Web用・
> モバイルアプリ用など）がそれぞれ別の窓口（Client）を持つことができる。

### 2-4. dynamodb.tf — 台帳を作る

```hcl
resource "aws_dynamodb_table" "entries" {
  name         = "${var.project_name}-entries"
  billing_mode = "PAY_PER_REQUEST"

  hash_key  = "userId"
  range_key = "entryId"

  attribute {
    name = "userId"
    type = "S"
  }

  attribute {
    name = "entryId"
    type = "S"
  }

  tags = {
    Project = var.project_name
  }
}
```

> 💡 `hash_key`（パーティションキー）と`range_key`（ソートキー）の組み合わせが、
> この台帳の「引き出し方」を決める。「userId=Aさんの引き出し」の中に
> 「entryId順に並んだ日記カード」が入っている、とイメージすると分かりやすい。
> `billing_mode = "PAY_PER_REQUEST"`は「使った分だけ払う」設定（他に、
> あらかじめ処理能力を予約する`PROVISIONED`もあるが、アクセス量が読めない
> 個人開発ではオンデマンドの方が安全）。

### 2-5. backend/lambda/ 以下にPythonコードを書く

Terraformの外側（リポジトリの`aws-portfolio-03-serverless/backend/lambda/`）に、
4つのフォルダとPythonファイルを作る。

```bash
mkdir -p ../../backend/lambda/create_entry
mkdir -p ../../backend/lambda/list_entries
mkdir -p ../../backend/lambda/update_entry
mkdir -p ../../backend/lambda/delete_entry
```

`backend/lambda/create_entry/handler.py`:
```python
import json
import os
import uuid
from datetime import datetime, timezone

import boto3

# TABLE_NAME はTerraformのenvironmentブロックから注入される
table = boto3.resource("dynamodb").Table(os.environ["TABLE_NAME"])


def lambda_handler(event, context):
    # HTTP API (JWT Authorizer) を通過したリクエストには
    # Cognitoが検証済みのJWTクレームが自動で付与される
    # sub = Cognitoユーザーの一意なID（ユーザーごとのデータ分離に使う）
    user_id = event["requestContext"]["authorizer"]["jwt"]["claims"]["sub"]
    body = json.loads(event.get("body") or "{}")
    content = body.get("content", "").strip()
    entry_type = body.get("entryType", "gratitude")

    if not content:
        return {
            "statusCode": 400,
            "body": json.dumps({"message": "content is required"}),
        }

    now = datetime.now(timezone.utc).isoformat()
    entry = {
        "userId": user_id,
        # entryId: 作成時刻を先頭に置くことで、Query結果が自然に時系列順になる
        "entryId": f"{now}#{uuid.uuid4()}",
        "content": content,
        "entryType": entry_type,
        "createdAt": now,
        "updatedAt": now,
    }

    table.put_item(Item=entry)

    return {
        "statusCode": 201,
        "body": json.dumps(entry),
    }
```

`backend/lambda/list_entries/handler.py`:
```python
import json
import os

import boto3
from boto3.dynamodb.conditions import Key

table = boto3.resource("dynamodb").Table(os.environ["TABLE_NAME"])


def lambda_handler(event, context):
    user_id = event["requestContext"]["authorizer"]["jwt"]["claims"]["sub"]

    # userId (PK) で絞り込むQuery。Scanと違い、他ユーザーのデータを
    # 読み取る経路が存在しないため安全
    response = table.query(
        KeyConditionExpression=Key("userId").eq(user_id),
        ScanIndexForward=False,  # entryIdの降順 = 新しい日記が先頭
    )

    return {
        "statusCode": 200,
        "body": json.dumps(response.get("Items", [])),
    }
```

`backend/lambda/update_entry/handler.py`:
```python
import json
import os
from datetime import datetime, timezone

import boto3

table = boto3.resource("dynamodb").Table(os.environ["TABLE_NAME"])


def lambda_handler(event, context):
    user_id = event["requestContext"]["authorizer"]["jwt"]["claims"]["sub"]
    entry_id = event["pathParameters"]["id"]
    body = json.loads(event.get("body") or "{}")
    content = body.get("content", "").strip()

    if not content:
        return {
            "statusCode": 400,
            "body": json.dumps({"message": "content is required"}),
        }

    # Key条件にuserIdを含めることで、他ユーザーのentryIdを推測されても
    # 更新できないようにする（IDOR対策）
    table.update_item(
        Key={"userId": user_id, "entryId": entry_id},
        UpdateExpression="SET content = :content, updatedAt = :updatedAt",
        ConditionExpression="attribute_exists(userId)",
        ExpressionAttributeValues={
            ":content": content,
            ":updatedAt": datetime.now(timezone.utc).isoformat(),
        },
    )

    return {
        "statusCode": 200,
        "body": json.dumps({"entryId": entry_id, "content": content}),
    }
```

`backend/lambda/delete_entry/handler.py`:
```python
import json
import os

import boto3

table = boto3.resource("dynamodb").Table(os.environ["TABLE_NAME"])


def lambda_handler(event, context):
    user_id = event["requestContext"]["authorizer"]["jwt"]["claims"]["sub"]
    entry_id = event["pathParameters"]["id"]

    # userIdをKeyに含めることで、他ユーザーのentryIdを削除できないようにする
    table.delete_item(Key={"userId": user_id, "entryId": entry_id})

    return {
        "statusCode": 204,
        "body": "",
    }
```

> 💡 4つとも`event["requestContext"]["authorizer"]["jwt"]["claims"]["sub"]`から
> `user_id`を取り出している。この`sub`はAPI Gatewayの**JWT Authorizerが
> トークンを検証した後で自動的に注入してくれる値**なので、Lambda側では
> 「トークンが本物かどうか」を一切気にしなくてよい。信頼できる形で
> 既に渡されてきている前提でコードを書ける、というのがAPI Gateway側で
> 認証をかけることの最大の利点。

### 2-6. lambda.tf — Lambda関数とその実行権限を作る

```hcl
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

# archive プロバイダで各ハンドラーのディレクトリをzip化する
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
```

> 💡 `aws_iam_role`（実行ロール）は「このLambda関数が変身できる社員証」。
> `assume_role_policy`が「Lambdaサービスだけがこの社員証を借りてよい」という
> 許可、その下の2つのポリシーが「その社員証で何をしてよいか」（ログ出力・
> DynamoDB読み書き）。`data "archive_file"`はTerraformの中でZIP圧縮を
> 行うための特殊なブロックで、実際のAWSリソースは作らず「zipファイルを
> 作る」という下準備だけをする。

### 2-7. api_gateway.tf — 受付カウンターを作る

```hcl
resource "aws_apigatewayv2_api" "main" {
  name          = "${var.project_name}-api"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["GET", "POST", "PUT", "DELETE", "OPTIONS"]
    allow_headers = ["content-type", "authorization"]
  }

  tags = {
    Project = var.project_name
  }
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.main.id
  name        = "$default"
  auto_deploy = true
}

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
```

> 💡 ここは「同じパターンの繰り返し」が4回続くだけ。1組（`POST /entries`用）を
> 理解すれば、あとの3組（GET・PUT・DELETE）は名前が違うだけの複製。
> `aws_apigatewayv2_integration`が「このルートはどのLambdaに転送するか」、
> `aws_apigatewayv2_route`が「このHTTPメソッド＋パスの組み合わせが来たら」、
> `aws_lambda_permission`が「API GatewayがこのLambdaを呼び出してよい」という
> Lambda側の許可（これを忘れると、ルート設定は正しくてもLambdaが
> 「呼び出し元を知らない」と拒否する）。

### 2-8. outputs.tf — 完成後に必要な値を表示させる

```hcl
output "api_endpoint" {
  description = "HTTP APIのベースURL（Reactアプリの環境変数に設定する）"
  value       = aws_apigatewayv2_stage.default.invoke_url
}

output "cognito_user_pool_id" {
  value = aws_cognito_user_pool.main.id
}

output "cognito_user_pool_client_id" {
  value = aws_cognito_user_pool_client.spa.id
}

output "dynamodb_table_name" {
  value = aws_dynamodb_table.entries.name
}
```

### 2-9. ここまでを実行して確認する

```bash
terraform init
terraform plan
```

`terraform plan`は「これから何を作るか」の見積もりを表示するだけで、
まだ何も作らない。表示された内容に見覚えのないリソースが混ざっていないか
確認してから、次に進む。

```bash
terraform apply
# 確認プロンプトが出たら yes と入力
```

数分待つと、`outputs.tf`で指定した値がターミナルに表示される。これらは
後でReactアプリの設定に使うのでメモしておく。

**動作確認①: 認証なしでAPIを叩くと401が返るか**
```bash
curl -i https://<api_endpoint>/entries
# HTTP/1.1 401 Unauthorized が返ればJWT Authorizerが正しく機能している
```

**動作確認②: Lambda関数を直接動かしてDynamoDBに書き込めるか**
```bash
aws lambda invoke \
  --function-name aws-portfolio-03-serverless-create-entry \
  --payload '{"requestContext":{"authorizer":{"jwt":{"claims":{"sub":"test-user"}}}},"body":"{\"content\":\"test\"}"}' \
  --cli-binary-format raw-in-base64-out \
  result.json
cat result.json
# "statusCode": 201 が返ればOK
```

> 💡 このコマンドは、API Gatewayを経由せずLambda関数を直接呼び出している。
> 本来はAPI GatewayのJWT Authorizerが検証してから渡す`claims.sub`の値を、
> ここでは手動で偽装して渡している（テスト目的限定。実際のブラウザ経由の
> リクエストではCognitoが検証した本物の値しか渡らない）。

ここまでで、ログイン＋日記のCRUDのバックエンドが完成した。
続いてフロントエンド（Reactアプリ）を配信するインフラを作る。

### 2-10. s3_frontend.tf — Reactのビルド成果物を置く倉庫

```hcl
data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "frontend" {
  # バケット名はAWSグローバルで一意である必要があるためアカウントIDを付与
  bucket = "portfolio-03-serverless-frontend-${data.aws_caller_identity.current.account_id}"
  force_destroy = true

  tags = {
    Project = var.project_name
  }
}

resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket                  = aws_s3_bucket.frontend.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "frontend" {
  bucket = aws_s3_bucket.frontend.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontServicePrincipal"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.frontend.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.frontend.arn
          }
        }
      }
    ]
  })
}
```

> 💡 S3バケットは**完全非公開**にする（`block_public_acls`等を全部true）。
> 代わりに、次に作るCloudFrontだけが読めるように、バケットポリシーの
> `Condition`で「このCloudFrontディストリビューションからのリクエストのみ許可」
> と限定している。「S3を直接公開する」のではなく「CloudFront経由でのみ
> 読める」形にすることで、HTTPS化やキャッシュ配信も同時に手に入る。

### 2-11. acm.tf — HTTPS証明書を発行する

独自ドメインを持っていない場合はこのステップと次のroute53.tfはスキップし、
`cloudfront.tf`の`aliases`と`viewer_certificate`をコメントアウトして、
CloudFrontのデフォルトドメイン（`https://xxxx.cloudfront.net`）で公開してよい。

```hcl
resource "aws_acm_certificate" "frontend" {
  provider          = aws.us_east_1
  domain_name       = var.domain_name
  validation_method = "DNS"

  tags = {
    Project = var.project_name
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.frontend.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = var.hosted_zone_id
}

resource "aws_acm_certificate_validation" "frontend" {
  provider                = aws.us_east_1
  certificate_arn         = aws_acm_certificate.frontend.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}
```

> 💡 ACM証明書は「発行してほしい」と申請するだけでは発行されない。
> 「本当にそのドメインの持ち主ですか？」を確認するため、指定されたDNS
> レコード（CNAME）を自分のドメインに追加する必要がある（DNS検証）。
> `aws_route53_record.cert_validation`がその確認用レコードを自動で作り、
> `aws_acm_certificate_validation`が「検証が完了するまで待つ」役目を持つ。

### 2-12. cloudfront.tf — 配送センターを作る

```hcl
resource "aws_cloudfront_origin_access_control" "frontend" {
  name        = "${aws_s3_bucket.frontend.bucket}-oac"
  description = "OAC for ${aws_s3_bucket.frontend.bucket}"

  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "frontend" {
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  http_version        = "http2"
  aliases             = [var.domain_name]  # 独自ドメインなしなら削除する

  origin {
    domain_name              = aws_s3_bucket.frontend.bucket_regional_domain_name
    origin_id                = "S3-${aws_s3_bucket.frontend.bucket}"
    origin_access_control_id = aws_cloudfront_origin_access_control.frontend.id
  }

  default_cache_behavior {
    target_origin_id       = "S3-${aws_s3_bucket.frontend.bucket}"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    viewer_protocol_policy = "redirect-to-https"
    compress               = true

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    min_ttl     = 0
    default_ttl = 3600
    max_ttl     = 86400
  }

  custom_error_response {
    error_code         = 403
    response_code      = 200
    response_page_path = "/index.html"
  }

  custom_error_response {
    error_code         = 404
    response_code      = 200
    response_page_path = "/index.html"
  }

  viewer_certificate {
    # 独自ドメインなしなら、この3行を消して
    # cloudfront_default_certificate = true に差し替える
    acm_certificate_arn      = aws_acm_certificate_validation.frontend.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  tags = {
    Project = var.project_name
  }
}
```

### 2-13. route53.tf — ドメイン名をCloudFrontに向ける

独自ドメインなしならこのファイルは不要。

```hcl
resource "aws_route53_record" "frontend" {
  zone_id = var.hosted_zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.frontend.domain_name
    zone_id                = aws_cloudfront_distribution.frontend.hosted_zone_id
    evaluate_target_health = false
  }
}
```

`outputs.tf`にも追記しておく:
```hcl
output "frontend_bucket_name" {
  value = aws_s3_bucket.frontend.bucket
}

output "cloudfront_distribution_id" {
  value = aws_cloudfront_distribution.frontend.id
}

output "site_url" {
  value = "https://${var.domain_name}/"
}
```

### 2-14. 適用して確認する

```bash
terraform plan
terraform apply
```

ACM証明書のDNS検証には数分かかることがある（自動で待機するのでそのまま待つ）。
完了したら、Part 4またはPart 5に進んでReactアプリをビルド・配信する。

Terraform版はここまで。次はPart 4（フロントエンド）に進んでよいし、
同じ内容をCloudFormationでも書いてみたい場合はPart 3へ。

---

[目次](./README.md) | 前へ: [Part 1 — 全体像](./01-overview.md) | 次へ: [Part 4 — フロントエンド(まず動かす)](./04-frontend-quickstart.md)

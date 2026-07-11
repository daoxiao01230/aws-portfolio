# Phase 03 構築チュートリアル — ゼロから自分の手で完成させるガイド

このドキュメントは、**AIに頼らず自分の手だけでPhase 3（サーバーレス感謝日記）を
最初から構築できる**ことを目標にした実況型チュートリアルです。
`docs/Architecture.md`が「なぜこう設計したか」を説明する文書、
`infrastructure/terraform/README.md`が「できあがったものの早見表」だとすると、
この文書は「今この瞬間、何を打ち込めばいいか」だけを追った手順書です。

## この文書の歩き方

- **AWSを触るのが初めて** → Part 0から順番に読む
- **AWSアカウント・IAM・CLIは使ったことがある** → Part 0は読み飛ばしてPart 1から
- インフラの作り方は **Terraform版（Part 2）** と **CloudFormation版（Part 3）** の
  2通りを用意した。どちらか片方だけ進めればOK（両方やってもよい）
- フロントエンドは **まず動かす版（Part 4）** と **段階的に理解する版（Part 5）** の
  2通り。急いでいるならPart 4だけで完成する

```
Part 0  完全初心者向け準備（AWSアカウント・IAM・CLI・Terraform・Node.js）
Part 1  全体像 — 何を作るのか、各AWSサービスは何をする係なのか
Part 2  Terraformで作る（バックエンド → フロントエンド配信）
Part 3  CloudFormationで作る（同じものを別ツールで）
Part 4  フロントエンド：まず動かす版（完成コードを貼って確認）
Part 5  フロントエンド：段階的に理解する版（なぜこの順で書いたか）
Part 6  GitHub Actionsで自動デプロイを設定する
Part 7  完成確認チェックリスト
Part 8  後片付け（リソースの削除）
```

---

## Part 0 — 完全初心者向け準備

**AWSアカウント・IAMユーザー・AWS CLI・Terraformを既に使える人はここを飛ばしてPart 1へ。**

### 0-1. AWSアカウントを作る

1. https://aws.amazon.com/ にアクセスし「無料アカウントを作成」
2. メールアドレス・パスワード・クレジットカード情報を登録する
   （このPhase全体のコストは月$0.00〜$0.01程度。詳細は`docs/Cost-Estimation.md`参照）
3. サインアップ後、AWSマネジメントコンソール（ブラウザの管理画面）にログインできることを確認

> 注意: 最初にログインする「ルートユーザー」は普段使いしない。
> 普段の作業は次のステップで作る「IAMユーザー」で行う（AWSのベストプラクティス）。

### 0-2. 作業用のIAMユーザーを作る

ルートユーザーで毎回作業すると、万一パスワードが漏れたときの被害が大きすぎる。
そのため「自分専用の作業アカウント（IAMユーザー）」を作り、普段はそちらを使う。

1. AWSコンソール上部の検索窓で「IAM」と入力して開く
2. 左メニュー「ユーザー」→「ユーザーを作成」
3. ユーザー名を入力（例: `my-name`）
4. 「AWSマネジメントコンソールへのアクセスを許可する」はチェックしなくてよい
   （コンソールログインではなく、後述のアクセスキーでCLIから操作するため）
5. 「ポリシーを直接アタッチする」→ `AdministratorAccess` を選択
   （学習用の個人環境なので一旦フルアクセスにする。本番運用では最小権限にすべき）
6. ユーザー作成後、そのユーザーの詳細画面 →「セキュリティ認証情報」タブ →
   「アクセスキーを作成」→ ユースケースは「コマンドラインインターフェイス (CLI)」
7. 表示される **アクセスキーID** と **シークレットアクセスキー** を安全な場所に保存
   （シークレットアクセスキーはこの画面でしか表示されない。閉じたら二度と見れない）

### 0-3. AWS CLIをインストールして認証情報を設定する

**Windows:**
```powershell
# https://awscli.amazonaws.com/AWSCLIV2.msi をダウンロードして実行
# インストール後、確認:
aws --version
```

**Mac:**
```bash
curl "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o "AWSCLIV2.pkg"
sudo installer -pkg AWSCLIV2.pkg -target /
aws --version
```

認証情報を設定する:
```bash
aws configure
```
以下を順に聞かれるので入力:
```
AWS Access Key ID [None]: (0-2で保存したアクセスキーID)
AWS Secret Access Key [None]: (0-2で保存したシークレットキー)
Default region name [None]: ap-northeast-1
Default output format [None]: json
```

確認:
```bash
aws sts get-caller-identity
# 自分のアカウントID・ユーザー名が返ってくればOK
```

### 0-4. Terraformをインストールする

**Windows（推奨: winget）:**
```powershell
winget install Hashicorp.Terraform
```

**Mac（推奨: Homebrew）:**
```bash
brew install terraform
```

確認:
```bash
terraform version
# Terraform v1.x.x のように表示されればOK
```

### 0-5. Node.js / npmをインストールする（フロントエンド用）

https://nodejs.org/ からLTS版（2026年時点で20系または22系）をダウンロードしてインストール。

確認:
```bash
node --version
npm --version
```

### 0-6. Gitの基本（このリポジトリを手元に置く）

```bash
git clone https://github.com/daoxiao01230/aws-portfolio.git
cd aws-portfolio
```

> 以降のコマンドはすべて、このリポジトリの `aws-portfolio-03-serverless/` を
> 起点に実行する想定で書いている。

---

## Part 1 — 全体像を理解する

### 1-1. 何を作るのか

「感謝日記（Gratitude Journal）」という、ログインして日記をCRUD（作成・閲覧・更新・
削除）できるだけの小さなWebアプリ。派手な機能はなく、**サーバーレス構成でログイン付き
Webアプリを一通り作れることを示す**のが目的のポートフォリオ作品。

### 1-2. 完成形の全体図

```
ブラウザ
  │
  │ ① https://journal.daoxiao.org を開く
  ▼
CloudFront（世界中にキャッシュ配信するCDN） ── S3（Reactのビルド済みファイルを保管）
  │
  │ ② ログイン画面が表示される。サインアップ/ログインする
  ▼
Cognito（会員証を発行する係）
  │
  │ ③ ログイン成功 → JWT（「私はログイン済みです」を証明する暗号化された紙切れ）を受け取る
  ▼
API Gateway（受付。JWTを確認してから中に通す）
  │
  │ ④ 日記の作成・一覧・更新・削除をリクエストする
  ▼
Lambda（リクエストが来たときだけ動く店員。4人いる: 作成係/一覧係/更新係/削除係）
  │
  │ ⑤ データを読み書きする
  ▼
DynamoDB（帳簿。誰のどの日記か、を記録する台帳）
```

### 1-3. 各AWSサービスは何をする係なのか（たとえ話）

初めて聞く名前ばかりだと思うので、日常のたとえで理解してから読み進めるとよい。

| AWSサービス | たとえ | やっていること |
|---|---|---|
| **S3** | 倉庫 | ファイル（今回はReactのビルド済みHTML/CSS/JS）を保管する場所。それ自体はWebサーバーではない |
| **CloudFront** | 世界中に支店を持つ配送センター | S3の倉庫からファイルを取り寄せて、利用者に近い場所から高速に届ける（CDN）。HTTPS化もここが担当 |
| **Cognito** | 会員証発行窓口 | メールアドレス・パスワードでの会員登録・ログインを管理し、ログイン成功時に「本人確認済み」の証明書（JWT）を発行する |
| **API Gateway** | 受付カウンター | ブラウザからのリクエストを最初に受け取る窓口。「JWTを持っているか」をここでチェックしてから、対応するLambdaに取り次ぐ |
| **Lambda** | 呼ばれたときだけ出勤する店員 | リクエストが来た瞬間だけ起動して処理し、終わったら消える（サーバーを常時起動しておく必要がない＝サーバーレス）。今回は4人（作成/一覧/更新/削除）配置 |
| **DynamoDB** | 台帳（帳簿） | 「誰が」「いつ」「何を書いたか」を記録するデータベース。行と列の表ではなく、キー（伝票番号）で引く仕組み |
| **IAM** | 社員証・権限管理部門 | 「このLambda店員はDynamoDB帳簿を読み書きしてよい」「このCI/CDロボットはLambdaのコード更新だけしてよい」のような権限を管理する |
| **ACM** | 印鑑証明書発行所 | HTTPS通信に必要な証明書（SSL/TLS証明書）を無料で発行する |
| **Route 53** | 電話帳（DNS） | `journal.daoxiao.org`という名前を、CloudFrontの実際の場所に変換する |

### 1-4. なぜこの組み合わせなのか（設計判断の要約）

- API GatewayはREST APIではなく **HTTP API** を選ぶ（安い・シンプル・JWT検証を標準搭載）
- LambdaはPythonで書く（学習中の言語を実務コードにそのまま活かせるため）
- DynamoDBは「1ユーザー＝1つの引き出し」に例えられるテーブル設計にする
  （PK=userId, SK=entryId）。これにより「他人の日記を読み書きするコードが
  そもそも存在しない」という安全設計になる
- 詳しい理由はすべて`docs/Architecture.md`に書いてあるので、
  「なぜ」が気になったら随時そちらも参照

準備と全体像の理解ができたら、Part 2（Terraform）かPart 3（CloudFormation）に進む。

---

## Part 2 — Terraformで作る

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

## Part 3 — CloudFormationで作る

Part 2と全く同じアーキテクチャ（Cognito・DynamoDB・Lambda・API Gateway・
S3+CloudFront+ACM+Route53）を、Terraformの代わりにAWS純正のIaCツールである
**CloudFormation**で構築する。考え方はPart 2と同じなので、「なぜこの設計か」の
説明は繰り返さない。ここでは「CloudFormationならではの書き方・進め方」に絞る。

> ⚠️ このリポジトリの`infrastructure/cloudformation/`には、これから説明する
> 9つのテンプレートが**既に完成した状態で置いてある**（実際にはデプロイされて
> いない参照実装。理由はPart 3-9で説明する）。この章は「その9ファイルを
> 自分でゼロから書けるようになる」ための解説であり、既存ファイルをコピーする
> だけなら`infrastructure/cloudformation/*.yaml`を直接見ればよい。

### 3-1. TerraformとCloudFormationの考え方の違い

| | Terraform | CloudFormation |
|---|---|---|
| ファイルの単位 | フォルダ内の全`.tf`が1つの設定として扱われる | 1つの`.yaml`（または`.json`）が1つの「スタック」として独立してデプロイされる |
| リソース間の依存 | 同じフォルダ内なら自動で解決してくれる | スタックをまたぐ依存は、片方のOutputsをもう片方のParametersに**手動で**渡す必要がある |
| 実行コマンド | `terraform apply`（フォルダ全体を1回で適用） | `aws cloudformation deploy`をスタックの数だけ実行 |
| 状態の保存場所 | `terraform.tfstate`（ローカルまたはS3等） | AWS側がスタックとして管理（ローカルに状態ファイルを持たない） |

このため、CloudFormationでは「依存関係の順番にスタックをデプロイし、
前のスタックのOutputsを次のスタックのパラメータとして手渡す」という
作業が発生する。これがCloudFormation版が複数ファイルに分かれている理由。

### 3-2. デプロイ順序を先に把握する

```
dynamodb.yaml ─┐
cognito.yaml ──┼─→ lambda.yaml ─→ api-gateway.yaml
               │
s3-frontend.yaml ─→ cloudfront.yaml ─→ route53.yaml
acm.yaml (us-east-1) ──────────────↗
                                     │
              lambda.yaml + s3-frontend.yaml + cloudfront.yaml のoutputs
                                     ↓
                              iam-cicd.yaml（最後）
```

矢印の元にあるスタックのOutputsを、矢印の先のスタックのパラメータとして渡す。

### 3-3. dynamodb.yaml — 台帳を作る

```bash
mkdir -p aws-portfolio-03-serverless/infrastructure/cloudformation
cd aws-portfolio-03-serverless/infrastructure/cloudformation
```

```yaml
AWSTemplateFormatVersion: '2010-09-09'
Description: 'Portfolio 03 - DynamoDB entries table'

Parameters:
  ProjectName:
    Type: String
    Default: aws-portfolio-03-serverless

Resources:
  EntriesTable:
    Type: AWS::DynamoDB::Table
    Properties:
      TableName: !Sub '${ProjectName}-entries'
      BillingMode: PAY_PER_REQUEST
      AttributeDefinitions:
        - AttributeName: userId
          AttributeType: S
        - AttributeName: entryId
          AttributeType: S
      KeySchema:
        - AttributeName: userId
          KeyType: HASH
        - AttributeName: entryId
          KeyType: RANGE
      Tags:
        - Key: Project
          Value: !Ref ProjectName

Outputs:
  TableName:
    Value: !Ref EntriesTable
  TableArn:
    Value: !GetAtt EntriesTable.Arn
```

> 💡 CloudFormationの`Type: AWS::DynamoDB::Table`は、Terraformの
> `resource "aws_dynamodb_table"`と1対1で対応する（プロパティ名の
> キャメルケース/スネークケースが違うだけ）。`Outputs`ブロックが、
> 次のスタックに渡す値をエクスポートする場所。

デプロイして確認する:
```bash
aws cloudformation deploy \
  --template-file dynamodb.yaml \
  --stack-name portfolio-03-dynamodb

aws cloudformation describe-stacks \
  --stack-name portfolio-03-dynamodb \
  --query "Stacks[0].Outputs"
# TableName / TableArn の値をメモしておく
```

### 3-4. cognito.yaml — 会員証発行窓口を作る

```yaml
AWSTemplateFormatVersion: '2010-09-09'
Description: 'Portfolio 03 - Cognito User Pool + App Client'

Parameters:
  ProjectName:
    Type: String
    Default: aws-portfolio-03-serverless

Resources:
  UserPool:
    Type: AWS::Cognito::UserPool
    Properties:
      UserPoolName: !Sub '${ProjectName}-users'
      UsernameAttributes:
        - email
      AutoVerifiedAttributes:
        - email
      Policies:
        PasswordPolicy:
          MinimumLength: 8
          RequireLowercase: true
          RequireUppercase: true
          RequireNumbers: true
          RequireSymbols: false
      UserPoolTags:
        Project: !Ref ProjectName

  UserPoolClient:
    Type: AWS::Cognito::UserPoolClient
    Properties:
      ClientName: !Sub '${ProjectName}-spa-client'
      UserPoolId: !Ref UserPool
      GenerateSecret: false
      ExplicitAuthFlows:
        - ALLOW_USER_SRP_AUTH
        - ALLOW_REFRESH_TOKEN_AUTH

Outputs:
  UserPoolId:
    Value: !Ref UserPool
  UserPoolClientId:
    Value: !Ref UserPoolClient
  UserPoolArn:
    Value: !GetAtt UserPool.Arn
```

```bash
aws cloudformation deploy \
  --template-file cognito.yaml \
  --stack-name portfolio-03-cognito

aws cloudformation describe-stacks \
  --stack-name portfolio-03-cognito \
  --query "Stacks[0].Outputs"
```

### 3-5. lambda.yaml — Lambda関数を作る（コードはインライン埋め込み）

CloudFormationにはTerraformの`archive`プロバイダのような「フォルダをzip化する」
機能がない。かわりに、コードが数KB程度と小さい場合は`ZipFile`プロパティに
Pythonコードをそのまま書き込める（4KB弱まで）。

```yaml
AWSTemplateFormatVersion: '2010-09-09'
Description: 'Portfolio 03 - Lambda execution role + 4 functions'

Parameters:
  ProjectName:
    Type: String
    Default: aws-portfolio-03-serverless
  TableName:
    Type: String
  TableArn:
    Type: String

Resources:
  LambdaExecutionRole:
    Type: AWS::IAM::Role
    Properties:
      RoleName: !Sub '${ProjectName}-lambda-exec'
      AssumeRolePolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Principal:
              Service: lambda.amazonaws.com
            Action: sts:AssumeRole
      ManagedPolicyArns:
        - arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
      Policies:
        - PolicyName: !Sub '${ProjectName}-lambda-dynamodb'
          PolicyDocument:
            Version: '2012-10-17'
            Statement:
              - Effect: Allow
                Action:
                  - dynamodb:PutItem
                  - dynamodb:GetItem
                  - dynamodb:Query
                  - dynamodb:UpdateItem
                  - dynamodb:DeleteItem
                Resource: !Ref TableArn

  CreateEntryFunction:
    Type: AWS::Lambda::Function
    Properties:
      FunctionName: !Sub '${ProjectName}-create-entry'
      Role: !GetAtt LambdaExecutionRole.Arn
      Handler: index.lambda_handler
      Runtime: python3.12
      Timeout: 3
      Environment:
        Variables:
          TABLE_NAME: !Ref TableName
      Code:
        ZipFile: |
          import json, os, uuid
          from datetime import datetime, timezone
          import boto3
          table = boto3.resource("dynamodb").Table(os.environ["TABLE_NAME"])

          def lambda_handler(event, context):
              user_id = event["requestContext"]["authorizer"]["jwt"]["claims"]["sub"]
              body = json.loads(event.get("body") or "{}")
              content = body.get("content", "").strip()
              entry_type = body.get("entryType", "gratitude")
              if not content:
                  return {"statusCode": 400, "body": json.dumps({"message": "content is required"})}
              now = datetime.now(timezone.utc).isoformat()
              entry = {
                  "userId": user_id,
                  "entryId": f"{now}#{uuid.uuid4()}",
                  "content": content,
                  "entryType": entry_type,
                  "createdAt": now,
                  "updatedAt": now,
              }
              table.put_item(Item=entry)
              return {"statusCode": 201, "body": json.dumps(entry)}

  # list_entries / update_entry / delete_entry も同じパターンで3つ追加する
  # （完全なコードは infrastructure/cloudformation/lambda.yaml を参照）

Outputs:
  CreateEntryFunctionArn:
    Value: !GetAtt CreateEntryFunction.Arn
  CreateEntryFunctionName:
    Value: !Ref CreateEntryFunction
  # 他3関数分のArn/Nameも同様にOutputsへ
```

> 💡 `Handler: index.lambda_handler`の`index`という名前は固定。CloudFormationの
> `ZipFile`でインラインコードを書くと、AWSが自動的に`index.py`というファイル名で
> zip化するため、実際のファイル名に関わらず必ず`index`を指定する。
> 完全な4関数分のコードは`infrastructure/cloudformation/lambda.yaml`に
> すでに書いてあるので、実際に手を動かす際はそちらをコピーするとよい
> （このチュートリアルでは1つ目だけ示し、パターンの繰り返しは省略した）。

```bash
aws cloudformation deploy \
  --template-file lambda.yaml \
  --stack-name portfolio-03-lambda \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameter-overrides \
    TableName=<dynamodbスタックのTableName> \
    TableArn=<dynamodbスタックのTableArn>
```

> 💡 `--capabilities CAPABILITY_NAMED_IAM`が必要な理由: このテンプレートは
> `AWS::IAM::Role`という「名前付きの」IAMリソースを作る。CloudFormationは
> IAMリソースを勝手に作られると困る場合があるため、デプロイする人が
> 「IAMリソースが作られることを理解して承認した」ことを示すため、
> このフラグを明示的に付ける必要がある。

### 3-6. api-gateway.yaml — 受付カウンターを作る

```yaml
AWSTemplateFormatVersion: '2010-09-09'
Description: 'Portfolio 03 - HTTP API + JWT Authorizer + routes'

Parameters:
  ProjectName:
    Type: String
    Default: aws-portfolio-03-serverless
  AwsRegion:
    Type: String
    Default: ap-northeast-1
  CognitoUserPoolId:
    Type: String
  CognitoUserPoolClientId:
    Type: String
  CreateEntryFunctionArn:
    Type: String
  CreateEntryFunctionName:
    Type: String
  # list/update/delete 分も同様に4組ずつパラメータを用意する

Resources:
  HttpApi:
    Type: AWS::ApiGatewayV2::Api
    Properties:
      Name: !Sub '${ProjectName}-api'
      ProtocolType: HTTP
      CorsConfiguration:
        AllowOrigins: ['*']
        AllowMethods: [GET, POST, PUT, DELETE, OPTIONS]
        AllowHeaders: [content-type, authorization]

  DefaultStage:
    Type: AWS::ApiGatewayV2::Stage
    Properties:
      ApiId: !Ref HttpApi
      StageName: '$default'
      AutoDeploy: true

  CognitoAuthorizer:
    Type: AWS::ApiGatewayV2::Authorizer
    Properties:
      ApiId: !Ref HttpApi
      Name: !Sub '${ProjectName}-cognito-authorizer'
      AuthorizerType: JWT
      IdentitySource:
        - '$request.header.Authorization'
      JwtConfiguration:
        Audience:
          - !Ref CognitoUserPoolClientId
        Issuer: !Sub 'https://cognito-idp.${AwsRegion}.amazonaws.com/${CognitoUserPoolId}'

  CreateEntryIntegration:
    Type: AWS::ApiGatewayV2::Integration
    Properties:
      ApiId: !Ref HttpApi
      IntegrationType: AWS_PROXY
      IntegrationUri: !Ref CreateEntryFunctionArn
      PayloadFormatVersion: '2.0'

  CreateEntryRoute:
    Type: AWS::ApiGatewayV2::Route
    Properties:
      ApiId: !Ref HttpApi
      RouteKey: 'POST /entries'
      Target: !Sub 'integrations/${CreateEntryIntegration}'
      AuthorizationType: JWT
      AuthorizerId: !Ref CognitoAuthorizer

  CreateEntryPermission:
    Type: AWS::Lambda::Permission
    Properties:
      Action: lambda:InvokeFunction
      FunctionName: !Ref CreateEntryFunctionName
      Principal: apigateway.amazonaws.com
      SourceArn: !Sub 'arn:aws:execute-api:${AwsRegion}:${AWS::AccountId}:${HttpApi}/*/*'

  # GET /entries, PUT /entries/{id}, DELETE /entries/{id} も
  # 同じ3点セット（Integration/Route/Permission）を繰り返す
  # 完全版は infrastructure/cloudformation/api-gateway.yaml 参照

Outputs:
  ApiEndpoint:
    Value: !Sub 'https://${HttpApi}.execute-api.${AwsRegion}.amazonaws.com/'
```

```bash
aws cloudformation deploy \
  --template-file api-gateway.yaml \
  --stack-name portfolio-03-api \
  --parameter-overrides \
    CognitoUserPoolId=<cognitoスタックのUserPoolId> \
    CognitoUserPoolClientId=<cognitoスタックのUserPoolClientId> \
    CreateEntryFunctionArn=<lambdaスタックの値> \
    CreateEntryFunctionName=<lambdaスタックの値> \
    ListEntriesFunctionArn=<...> ListEntriesFunctionName=<...> \
    UpdateEntryFunctionArn=<...> UpdateEntryFunctionName=<...> \
    DeleteEntryFunctionArn=<...> DeleteEntryFunctionName=<...>
```

デプロイ後の動作確認はPart 2-9と同じ（`curl`で401確認、`aws lambda invoke`で
直接動作確認）。

### 3-7. s3-frontend.yaml — Reactのビルド成果物を置く倉庫

```yaml
AWSTemplateFormatVersion: '2010-09-09'
Description: 'Portfolio 03 - S3 bucket for frontend hosting'

Parameters:
  BucketName:
    Type: String

Resources:
  FrontendBucket:
    Type: AWS::S3::Bucket
    Properties:
      BucketName: !Ref BucketName
      PublicAccessBlockConfiguration:
        BlockPublicAcls: true
        BlockPublicPolicy: true
        IgnorePublicAcls: true
        RestrictPublicBuckets: true

Outputs:
  BucketName:
    Value: !Ref FrontendBucket
  BucketArn:
    Value: !GetAtt FrontendBucket.Arn
  BucketRegionalDomainName:
    Value: !GetAtt FrontendBucket.RegionalDomainName
```

```bash
aws cloudformation deploy \
  --template-file s3-frontend.yaml \
  --stack-name portfolio-03-s3 \
  --parameter-overrides BucketName=portfolio-03-serverless-frontend-$(aws sts get-caller-identity --query Account --output text)
```

### 3-8. acm.yaml — HTTPS証明書を発行する（us-east-1固定）

独自ドメインなしならこのステップとroute53.yamlはスキップ。

```yaml
AWSTemplateFormatVersion: '2010-09-09'
Description: 'Portfolio 03 - ACM Certificate for journal.daoxiao.org'

Parameters:
  DomainName:
    Type: String
    Default: journal.daoxiao.org
  HostedZoneId:
    Type: String

Resources:
  Certificate:
    Type: AWS::CertificateManager::Certificate
    Properties:
      DomainName: !Ref DomainName
      ValidationMethod: DNS
      DomainValidationOptions:
        - DomainName: !Ref DomainName
          HostedZoneId: !Ref HostedZoneId

Outputs:
  CertificateArn:
    Value: !Ref Certificate
```

```bash
# 必ず us-east-1 でデプロイする（CloudFrontの証明書はここでしか発行できない）
aws cloudformation deploy \
  --template-file acm.yaml \
  --stack-name portfolio-03-acm \
  --region us-east-1 \
  --parameter-overrides HostedZoneId=<自分のRoute53ホストゾーンID>
```

### 3-9. cloudfront.yaml — 配送センターを作る

```yaml
AWSTemplateFormatVersion: '2010-09-09'
Description: 'Portfolio 03 - CloudFront + BucketPolicy'

Parameters:
  BucketName:
    Type: String
  BucketArn:
    Type: String
  BucketRegionalDomainName:
    Type: String
  AcmCertificateArn:
    Type: String
  DomainName:
    Type: String
    Default: journal.daoxiao.org

Resources:
  CloudFrontOAC:
    Type: AWS::CloudFront::OriginAccessControl
    Properties:
      OriginAccessControlConfig:
        Name: !Sub '${BucketName}-oac'
        OriginAccessControlOriginType: s3
        SigningBehavior: always
        SigningProtocol: sigv4

  CloudFrontDistribution:
    Type: AWS::CloudFront::Distribution
    Properties:
      DistributionConfig:
        Enabled: true
        HttpVersion: http2
        IPV6Enabled: true
        DefaultRootObject: index.html
        Aliases:
          - !Ref DomainName
        Origins:
          - Id: !Sub 'S3-${BucketName}'
            DomainName: !Ref BucketRegionalDomainName
            OriginAccessControlId: !GetAtt CloudFrontOAC.Id
            S3OriginConfig:
              OriginAccessIdentity: ''
        DefaultCacheBehavior:
          TargetOriginId: !Sub 'S3-${BucketName}'
          ViewerProtocolPolicy: redirect-to-https
          AllowedMethods: [GET, HEAD]
          CachedMethods: [GET, HEAD]
          Compress: true
          ForwardedValues:
            QueryString: false
            Cookies:
              Forward: none
          MinTTL: 0
          DefaultTTL: 3600
          MaxTTL: 86400
        CustomErrorResponses:
          - ErrorCode: 403
            ResponseCode: 200
            ResponsePagePath: /index.html
          - ErrorCode: 404
            ResponseCode: 200
            ResponsePagePath: /index.html
        ViewerCertificate:
          AcmCertificateArn: !Ref AcmCertificateArn
          SslSupportMethod: sni-only
          MinimumProtocolVersion: TLSv1.2_2021
        Restrictions:
          GeoRestriction:
            RestrictionType: none

  BucketPolicy:
    Type: AWS::S3::BucketPolicy
    Properties:
      Bucket: !Ref BucketName
      PolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Sid: AllowCloudFrontServicePrincipal
            Effect: Allow
            Principal:
              Service: cloudfront.amazonaws.com
            Action: s3:GetObject
            Resource: !Sub '${BucketArn}/*'
            Condition:
              StringEquals:
                AWS:SourceArn: !Sub 'arn:aws:cloudfront::${AWS::AccountId}:distribution/${CloudFrontDistribution}'

Outputs:
  SiteUrl:
    Value: !Sub 'https://${DomainName}/'
  CloudFrontDomainName:
    Value: !GetAtt CloudFrontDistribution.DomainName
  CloudFrontDistributionId:
    Value: !Ref CloudFrontDistribution
  CloudFrontDistributionArn:
    Value: !Sub 'arn:aws:cloudfront::${AWS::AccountId}:distribution/${CloudFrontDistribution}'
```

```bash
aws cloudformation deploy \
  --template-file cloudfront.yaml \
  --stack-name portfolio-03-cloudfront \
  --parameter-overrides \
    BucketName=<s3スタックのBucketName> \
    BucketArn=<s3スタックのBucketArn> \
    BucketRegionalDomainName=<s3スタックのBucketRegionalDomainName> \
    AcmCertificateArn=<acmスタックのCertificateArn（us-east-1で取得したもの）>
```

### 3-10. route53.yaml — ドメイン名をCloudFrontに向ける

```yaml
AWSTemplateFormatVersion: '2010-09-09'
Description: 'Portfolio 03 - Route 53 DNS record'

Parameters:
  HostedZoneId:
    Type: String
  DomainName:
    Type: String
    Default: journal.daoxiao.org
  CloudFrontDomainName:
    Type: String

Resources:
  DNSRecord:
    Type: AWS::Route53::RecordSet
    Properties:
      HostedZoneId: !Ref HostedZoneId
      Name: !Ref DomainName
      Type: A
      AliasTarget:
        # CloudFront専用の固定Hosted Zone ID（アカウントによらず常にこの値）
        HostedZoneId: Z2FDTNDATAQYW2
        DNSName: !Ref CloudFrontDomainName
        EvaluateTargetHealth: false

Outputs:
  URL:
    Value: !Sub 'https://${DomainName}'
```

```bash
aws cloudformation deploy \
  --template-file route53.yaml \
  --stack-name portfolio-03-route53 \
  --parameter-overrides \
    HostedZoneId=<自分のホストゾーンID> \
    CloudFrontDomainName=<cloudfrontスタックのCloudFrontDomainName>
```

### 3-11. iam-cicd.yaml — CI/CD用の限定権限を既存ユーザーに追加する（最後）

このスタックは新しいIAMユーザーを作らず、Part 6で使う既存のGitHub Actions用
ユーザーに「Lambdaコードの更新」「S3への書き込み」「CloudFrontのキャッシュ削除」
だけを許可するポリシーを追加する。すべてのリソースが揃った後、一番最後にデプロイする。

```yaml
AWSTemplateFormatVersion: '2010-09-09'
Description: 'Portfolio 03 - Scoped CI/CD policies on the existing GitHub Actions IAM user'

Parameters:
  ExistingIamUserName:
    Type: String
    Default: github-actions-portfolio-01
  CreateEntryFunctionArn:
    Type: String
  ListEntriesFunctionArn:
    Type: String
  UpdateEntryFunctionArn:
    Type: String
  DeleteEntryFunctionArn:
    Type: String
  FrontendBucketArn:
    Type: String
  CloudFrontDistributionArn:
    Type: String

Resources:
  LambdaDeployPolicy:
    Type: AWS::IAM::Policy
    Properties:
      PolicyName: portfolio-03-lambda-deploy-policy
      PolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Action:
              - lambda:UpdateFunctionCode
            Resource:
              - !Ref CreateEntryFunctionArn
              - !Ref ListEntriesFunctionArn
              - !Ref UpdateEntryFunctionArn
              - !Ref DeleteEntryFunctionArn
      Users:
        - !Ref ExistingIamUserName

  FrontendDeployPolicy:
    Type: AWS::IAM::Policy
    Properties:
      PolicyName: portfolio-03-frontend-deploy-policy
      PolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Action:
              - s3:PutObject
              - s3:DeleteObject
              - s3:GetObject
              - s3:ListBucket
            Resource:
              - !Ref FrontendBucketArn
              - !Sub '${FrontendBucketArn}/*'
          - Effect: Allow
            Action:
              - cloudfront:CreateInvalidation
            Resource:
              - !Ref CloudFrontDistributionArn
      Users:
        - !Ref ExistingIamUserName
```

> 💡 `Users: [!Ref ExistingIamUserName]`が、このテンプレートの一番重要な部分。
> 通常`AWS::IAM::Policy`は「新しく作ったユーザー」に付けることが多いが、
> ここでは`AWS::IAM::User`リソースを作らず、**既にAWSに存在するユーザー名を
> 文字列パラメータとして受け取り**、そのユーザーにポリシーを追加している。
> 新しいIAMユーザー（と、それに紐づくGitHub Secrets）を増やしたくない場合の
> 定番パターン。

```bash
aws cloudformation deploy \
  --template-file iam-cicd.yaml \
  --stack-name portfolio-03-iam-cicd \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameter-overrides \
    CreateEntryFunctionArn=<...> ListEntriesFunctionArn=<...> \
    UpdateEntryFunctionArn=<...> DeleteEntryFunctionArn=<...> \
    FrontendBucketArn=<s3スタックの値> \
    CloudFrontDistributionArn=<cloudfrontスタックの値>
```

### 3-12. なぜこのCloudFormation版は実際にはデプロイしない設定なのか

このリポジトリでは、Part 2（Terraform）で作ったインフラが既に本番で稼働中。
もしこのPart 3のテンプレート群をそのまま同じAWSアカウントにデプロイすると、
**同じ名前・同じ役割のリソースが2セット**（Cognitoプールが2つ、Lambda関数が
8個、等）できてしまい、コストの二重発生や名前衝突を招く。そのため、この
リポジトリの`infrastructure/cloudformation/`にあるテンプレートは
「参照実装として置いてあるだけで、実際にはデプロイしていない」。

自分の環境で試す場合は、Part 2（Terraform）かPart 3（CloudFormation）の
**どちらか一方だけ**を選んでデプロイすること。両方同時にデプロイしたい場合は、
`ProjectName`パラメータを変える等してリソース名を衝突させない工夫が必要になる。

CloudFormation版はここまで。Part 4またはPart 5に進んでフロントエンドを作る。

---

## Part 4 — フロントエンド：まず動かす版

このPartは「仕組みはあとで理解するとして、まず手元で動くものを作りたい」人向け。
完成しているコードをそのまま貼り付けて、実際に動かすところまでを最短で進める。
「なぜこの順番・この設計にしたか」を理解したい場合はPart 5を読む（このPartを
先に終わらせてからでも、Part 5だけを読んでも、どちらでもよい）。

### 4-0. フォルダとpackage.jsonを作る

```bash
mkdir -p aws-portfolio-03-serverless/frontend/public
mkdir -p aws-portfolio-03-serverless/frontend/src/auth
mkdir -p aws-portfolio-03-serverless/frontend/src/api
mkdir -p aws-portfolio-03-serverless/frontend/src/components
cd aws-portfolio-03-serverless/frontend
```

`package.json`:
```json
{
  "name": "aws-portfolio-03-serverless",
  "version": "1.0.0",
  "private": true,
  "dependencies": {
    "amazon-cognito-identity-js": "^6.3.12",
    "react": "^19.2.7",
    "react-dom": "^19.2.7",
    "react-scripts": "5.0.1"
  },
  "scripts": {
    "start": "react-scripts start",
    "build": "react-scripts build",
    "test": "react-scripts test",
    "eject": "react-scripts eject"
  },
  "eslintConfig": {
    "extends": [
      "react-app",
      "react-app/jest"
    ]
  },
  "browserslist": {
    "production": [
      ">0.2%",
      "not dead",
      "not op_mini all"
    ],
    "development": [
      "last 1 chrome version",
      "last 1 firefox version",
      "last 1 safari version"
    ]
  }
}
```

`public/index.html`:
```html
<!DOCTYPE html>
<html lang="ja">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <meta name="description" content="Serverless Gratitude Journal — Phase 03" />
    <title>Gratitude Journal (Serverless)</title>
  </head>
  <body>
    <noscript>You need to enable JavaScript to run this app.</noscript>
    <div id="root"></div>
  </body>
</html>
```

`src/index.css`:
```css
body {
  margin: 0;
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Roboto', 'Oxygen',
    'Ubuntu', 'Cantarell', 'Fira Sans', 'Droid Sans', 'Helvetica Neue',
    sans-serif;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
}
```

`src/index.js`:
```jsx
import React from 'react';
import ReactDOM from 'react-dom/client';
import './index.css';
import App from './App';

const root = ReactDOM.createRoot(document.getElementById('root'));
root.render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);
```

### 4-1. src/config.js

```js
// ローカル開発: terraform apply の outputs (cognito_user_pool_id / cognito_user_pool_client_id / api_endpoint)
// を .env.local に REACT_APP_ プレフィックス付きで設定する
const config = {
  region: process.env.REACT_APP_AWS_REGION || 'ap-northeast-1',
  userPoolId: process.env.REACT_APP_COGNITO_USER_POOL_ID,
  userPoolClientId: process.env.REACT_APP_COGNITO_CLIENT_ID,
  apiEndpoint: process.env.REACT_APP_API_ENDPOINT,
};

export default config;
```

### 4-2. src/auth/cognito.js

```js
import {
  CognitoUserPool,
  CognitoUser,
  AuthenticationDetails,
} from 'amazon-cognito-identity-js';
import config from '../config';

const userPool = new CognitoUserPool({
  UserPoolId: config.userPoolId,
  ClientId: config.userPoolClientId,
});

export function signUp(email, password) {
  return new Promise((resolve, reject) => {
    userPool.signUp(email, password, [], null, (err, result) => {
      if (err) reject(err);
      else resolve(result);
    });
  });
}

export function confirmSignUp(email, code) {
  const user = new CognitoUser({ Username: email, Pool: userPool });
  return new Promise((resolve, reject) => {
    user.confirmRegistration(code, true, (err, result) => {
      if (err) reject(err);
      else resolve(result);
    });
  });
}

export function signIn(email, password) {
  const user = new CognitoUser({ Username: email, Pool: userPool });
  const authDetails = new AuthenticationDetails({
    Username: email,
    Password: password,
  });
  return new Promise((resolve, reject) => {
    user.authenticateUser(authDetails, {
      onSuccess: (session) => resolve(session),
      onFailure: (err) => reject(err),
    });
  });
}

export function signOut() {
  const user = userPool.getCurrentUser();
  if (user) user.signOut();
}

export function getIdToken() {
  const user = userPool.getCurrentUser();
  if (!user) return Promise.resolve(null);

  return new Promise((resolve, reject) => {
    user.getSession((err, session) => {
      if (err) reject(err);
      else resolve(session.isValid() ? session.getIdToken().getJwtToken() : null);
    });
  });
}

export function getCurrentUser() {
  return userPool.getCurrentUser();
}
```

### 4-3. src/api/entries.js

```js
import config from '../config';
import { getIdToken } from '../auth/cognito';

async function authHeaders() {
  const token = await getIdToken();
  return {
    'Content-Type': 'application/json',
    Authorization: token,
  };
}

async function request(path, options = {}) {
  const res = await fetch(`${config.apiEndpoint}${path}`, {
    ...options,
    headers: { ...(await authHeaders()), ...options.headers },
  });
  if (!res.ok) {
    const body = await res.text();
    throw new Error(`${res.status} ${body}`);
  }
  return res.status === 204 ? null : res.json();
}

export function listEntries() {
  return request('/entries');
}

export function createEntry(content, entryType = 'gratitude') {
  return request('/entries', {
    method: 'POST',
    body: JSON.stringify({ content, entryType }),
  });
}

export function updateEntry(entryId, content) {
  return request(`/entries/${encodeURIComponent(entryId)}`, {
    method: 'PUT',
    body: JSON.stringify({ content }),
  });
}

export function deleteEntry(entryId) {
  return request(`/entries/${encodeURIComponent(entryId)}`, {
    method: 'DELETE',
  });
}
```

### 4-4. src/components/GratitudeTree.js

```jsx
export default function GratitudeTree({ streak }) {
  const level = Math.min(streak, 30);
  const leaves = Math.floor(level * 2.5);
  const generateLeaves = (count) => {
    const items = [];
    for (let i = 0; i < count; i++) {
      const angle = (i / count) * 360;
      const radius = 20 + (i % 3) * 14;
      const x = 50 + radius * Math.cos((angle * Math.PI) / 180);
      const y = 55 - radius * Math.abs(Math.sin((angle * Math.PI) / 180));
      const size = 6 + (i % 4) * 2;
      const colors = ["#a8d8a8", "#7bc47b", "#5aad5a", "#c8e6c8", "#b8ddb8", "#e8f5e8"];
      items.push(
        <ellipse key={i} cx={x} cy={y} rx={size} ry={size * 0.7}
          fill={colors[i % colors.length]} opacity={0.85}
          transform={`rotate(${angle + 20}, ${x}, ${y})`} />
      );
    }
    return items;
  };
  const trunkHeight = 20 + level * 0.8;
  return (
    <svg viewBox="0 0 100 100" width="120" height="120" style={{ filter: "drop-shadow(0 2px 8px rgba(0,0,0,0.08))", flexShrink: 0 }}>
      <ellipse cx="50" cy="95" rx="22" ry="5" fill="#d4b896" opacity="0.4" />
      <rect x="45" y={100 - trunkHeight} width="10" height={trunkHeight - 5} rx="4" fill="#c4956a" />
      {leaves > 0 && generateLeaves(leaves)}
      {streak === 0 && <circle cx="50" cy="60" r="18" fill="#e8f5e8" stroke="#a8d8a8" strokeWidth="2" strokeDasharray="4 3" />}
      {streak === 0 && <text x="50" y="65" textAnchor="middle" fontSize="16" fill="#a8d8a8">🌱</text>}
    </svg>
  );
}
```

### 4-5. src/components/AuthScreen.js

```jsx
import { useState } from 'react';
import { signUp, confirmSignUp, signIn } from '../auth/cognito';

const INPUT = {
  width: '100%', boxSizing: 'border-box', padding: '12px 14px', marginTop: 8,
  borderRadius: 12, border: '1.5px solid #d4c5e6', fontSize: 15,
  color: '#3d2b52', fontFamily: 'inherit', outline: 'none', background: 'rgba(255,255,255,0.8)',
};

const BUTTON = {
  width: '100%', marginTop: 16, padding: '13px', borderRadius: 12, border: 'none',
  background: 'linear-gradient(135deg, #a07ac4, #7a5fa0)', color: '#fff',
  fontSize: 15, fontWeight: 600, cursor: 'pointer', fontFamily: 'inherit', letterSpacing: '0.05em',
};

const LINK = {
  background: 'none', border: 'none', color: '#7a5fa0', fontSize: 13,
  cursor: 'pointer', fontFamily: 'inherit', marginTop: 14, textDecoration: 'underline',
};

export default function AuthScreen({ onAuthSuccess }) {
  const [mode, setMode] = useState('signIn'); // signIn | signUp | confirm
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [code, setCode] = useState('');
  const [error, setError] = useState('');
  const [busy, setBusy] = useState(false);

  const handleSignIn = async (e) => {
    e.preventDefault();
    setError('');
    setBusy(true);
    try {
      await signIn(email, password);
      onAuthSuccess();
    } catch (err) {
      setError(err.message || String(err));
    } finally {
      setBusy(false);
    }
  };

  const handleSignUp = async (e) => {
    e.preventDefault();
    setError('');
    setBusy(true);
    try {
      await signUp(email, password);
      setMode('confirm');
    } catch (err) {
      setError(err.message || String(err));
    } finally {
      setBusy(false);
    }
  };

  const handleConfirm = async (e) => {
    e.preventDefault();
    setError('');
    setBusy(true);
    try {
      await confirmSignUp(email, code);
      setMode('signIn');
      setCode('');
    } catch (err) {
      setError(err.message || String(err));
    } finally {
      setBusy(false);
    }
  };

  const titles = {
    signIn: 'ログイン',
    signUp: 'アカウント登録',
    confirm: '確認コードを入力',
  };

  return (
    <div style={{
      minHeight: '100vh',
      background: 'linear-gradient(160deg, #fdf4ee 0%, #f0eaf8 50%, #eaf2f8 100%)',
      fontFamily: "'Georgia', 'Noto Serif SC', 'Noto Serif JP', serif",
      display: 'flex', justifyContent: 'center', alignItems: 'flex-start', padding: '60px 16px',
    }}>
      <div style={{
        width: '100%', maxWidth: 380,
        background: 'rgba(255,255,255,0.75)', borderRadius: 20,
        border: '1px solid rgba(255,255,255,0.9)', boxShadow: '0 4px 24px rgba(90,62,107,0.08)',
        padding: 28,
      }}>
        <h1 style={{ margin: 0, fontSize: 22, fontWeight: 700, color: '#5a3e6b' }}>
          感謝日記
        </h1>
        <p style={{ margin: '6px 0 20px', fontSize: 13, color: '#9b85b0' }}>
          {titles[mode]}
        </p>

        {mode === 'signIn' && (
          <form onSubmit={handleSignIn}>
            <input style={INPUT} type="email" placeholder="メールアドレス" value={email}
              onChange={e => setEmail(e.target.value)} required />
            <input style={INPUT} type="password" placeholder="パスワード" value={password}
              onChange={e => setPassword(e.target.value)} required />
            <button style={BUTTON} type="submit" disabled={busy}>ログイン</button>
            <button type="button" style={LINK} onClick={() => { setMode('signUp'); setError(''); }}>
              アカウントを作成する
            </button>
          </form>
        )}

        {mode === 'signUp' && (
          <form onSubmit={handleSignUp}>
            <input style={INPUT} type="email" placeholder="メールアドレス" value={email}
              onChange={e => setEmail(e.target.value)} required />
            <input style={INPUT} type="password" placeholder="パスワード（8文字以上・大小英数字を含む）" value={password}
              onChange={e => setPassword(e.target.value)} required minLength={8} />
            <button style={BUTTON} type="submit" disabled={busy}>登録する</button>
            <button type="button" style={LINK} onClick={() => { setMode('signIn'); setError(''); }}>
              ログイン画面へ戻る
            </button>
          </form>
        )}

        {mode === 'confirm' && (
          <form onSubmit={handleConfirm}>
            <p style={{ fontSize: 13, color: '#9b85b0', margin: '0 0 8px' }}>
              {email} に届いた確認コードを入力してください
            </p>
            <input style={INPUT} type="text" placeholder="確認コード" value={code}
              onChange={e => setCode(e.target.value)} required />
            <button style={BUTTON} type="submit" disabled={busy}>確認する</button>
          </form>
        )}

        {error && (
          <div style={{ marginTop: 14, fontSize: 13, color: '#b04040' }}>{error}</div>
        )}
      </div>
    </div>
  );
}
```

### 4-6. src/components/JournalScreen.js

これが一番大きいファイル。感謝日記の「今日・履歴・気づき」3タブすべての
表示とCRUD操作をここに書く。

```jsx
import { useState, useEffect } from 'react';
import { listEntries, createEntry, updateEntry, deleteEntry } from '../api/entries';
import { signOut } from '../auth/cognito';
import GratitudeTree from './GratitudeTree';

const translations = {
  ja: {
    appName: "感謝日記", subtitle: "毎日の感謝を記録して、幸せを積み重ねよう",
    todayPrompt: "今日、何に感謝しますか？", placeholder: "感謝していること1つを書いてみよう...",
    save: "保存する", saved: "保存しました ✓", streak: "連続日数",
    noEntries: "まだ記録がありません。今日から始めましょう！", today: "今日",
    langNext: "EN", formatDate: (d) => `${d.getMonth() + 1}月${d.getDate()}日`,
    last7: "直近7日間", writeTab: "✍️ 今日", historyTab: "📖 履歴", reflectTab: "🌿 気づき",
    reflectTitle: "私の成長の気づき", reflectSubtitle: "日記を書いて気づいた心の変化を記録",
    reflectPlaceholder: "今、どんな気づきがありますか？変化を書いてみましょう...",
    reflectSave: "気づきを保存", reflectSaved: "保存しました ✓",
    reflectEmpty: "まだ気づきがありません。いつでも記録できます",
    dayLabel: (n) => `${n}日目`,
    signOut: "ログアウト", edit: "編集", delete: "削除", cancel: "キャンセル",
    loading: "読み込み中…",
  },
  en: {
    appName: "Gratitude Journal", subtitle: "Notice the good, grow your joy",
    todayPrompt: "What are you grateful for today?", placeholder: "Write one thing you're grateful for...",
    save: "Save", saved: "Saved ✓", streak: "Day Streak",
    noEntries: "No entries yet — start today!", today: "Today",
    langNext: "中文", formatDate: (d) => d.toLocaleDateString("en-US", { month: "short", day: "numeric" }),
    last7: "Last 7 days", writeTab: "✍️ Today", historyTab: "📖 History", reflectTab: "🌿 Growth",
    reflectTitle: "My Growth Journal", reflectSubtitle: "Record how journaling is changing you",
    reflectPlaceholder: "What shift have you noticed? Write your reflection...",
    reflectSave: "Save Reflection", reflectSaved: "Saved ✓",
    reflectEmpty: "No reflections yet — write one whenever you feel a change",
    dayLabel: (n) => `Day ${n}`,
    signOut: "Sign Out", edit: "Edit", delete: "Delete", cancel: "Cancel",
    loading: "Loading…",
  },
  zh: {
    appName: "感恩日记", subtitle: "每天记录美好，积累幸福",
    todayPrompt: "今天你感恩什么？", placeholder: "写下一件让你感恩的事...",
    save: "保存", saved: "已保存 ✓", streak: "连续天数",
    noEntries: "还没有记录，今天开始吧！", today: "今天",
    langNext: "日本語", formatDate: (d) => `${d.getMonth() + 1}月${d.getDate()}日`,
    last7: "近7天", writeTab: "✍️ 今日", historyTab: "📖 历史", reflectTab: "🌿 感悟",
    reflectTitle: "我的成长感悟", reflectSubtitle: "记录写日记后内心的变化",
    reflectPlaceholder: "此刻有什么感悟？写下你注意到的变化...",
    reflectSave: "保存感悟", reflectSaved: "已保存 ✓",
    reflectEmpty: "还没有感悟，随时记录你的变化吧",
    dayLabel: (n) => `第 ${n} 天`,
    signOut: "退出登录", edit: "编辑", delete: "删除", cancel: "取消",
    loading: "加载中…",
  },
};

const LANG_CYCLE = ["ja", "en", "zh"];
const CARD = { width: "100%", boxSizing: "border-box", padding: "0 16px" };

function getDateKey(iso) {
  return new Date(iso).toISOString().split("T")[0];
}

function isReflection(entry) {
  return entry.entryType === "reflection";
}

function calculateStreak(gratitudeEntries) {
  const daysWithEntry = new Set(gratitudeEntries.map((e) => getDateKey(e.createdAt)));
  let streak = 0;
  let d = new Date();
  for (;;) {
    const key = d.toISOString().split("T")[0];
    if (daysWithEntry.has(key)) {
      streak++;
      d.setDate(d.getDate() - 1);
    } else break;
  }
  return streak;
}

function dayNumber(atIso, firstDateKey) {
  if (!firstDateKey) return 1;
  const start = new Date(firstDateKey + "T00:00:00");
  const at = new Date(atIso);
  return Math.floor((at - start) / (1000 * 60 * 60 * 24)) + 1;
}

export default function JournalScreen({ onSignOut }) {
  const [langIdx, setLangIdx] = useState(0);
  const [entries, setEntries] = useState([]);
  const [activeTab, setActiveTab] = useState("write");
  const [newText, setNewText] = useState("");
  const [justSaved, setJustSaved] = useState(false);
  const [reflectText, setReflectText] = useState("");
  const [reflectSaved, setReflectSaved] = useState(false);
  const [editingId, setEditingId] = useState(null);
  const [editText, setEditText] = useState("");
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  const lang = LANG_CYCLE[langIdx];
  const t = translations[lang];
  const today = new Date().toISOString().split("T")[0];

  const load = async () => {
    setLoading(true);
    setError("");
    try {
      const items = await listEntries();
      setEntries(items);
    } catch (err) {
      if (String(err.message).startsWith("401")) {
        signOut();
        onSignOut();
        return;
      }
      setError(err.message || String(err));
    } finally {
      setLoading(false);
    }
  };

  // eslint-disable-next-line react-hooks/exhaustive-deps
  useEffect(() => { load(); }, []);

  const gratitudeEntries = entries.filter((e) => !isReflection(e));
  const reflectionEntries = entries.filter(isReflection);
  const streak = calculateStreak(gratitudeEntries);
  const firstDate = entries.length > 0
    ? getDateKey(entries[entries.length - 1].createdAt)
    : null;

  const handleCreate = async () => {
    if (!newText.trim()) return;
    try {
      const entry = await createEntry(newText.trim(), "gratitude");
      setEntries([entry, ...entries]);
      setNewText("");
      setJustSaved(true);
      setTimeout(() => setJustSaved(false), 1500);
    } catch (err) {
      setError(err.message || String(err));
    }
  };

  const handleSaveReflection = async () => {
    if (!reflectText.trim()) return;
    try {
      const entry = await createEntry(reflectText.trim(), "reflection");
      setEntries([entry, ...entries]);
      setReflectText("");
      setReflectSaved(true);
      setTimeout(() => setReflectSaved(false), 1500);
    } catch (err) {
      setError(err.message || String(err));
    }
  };

  const handleUpdate = async (entryId) => {
    try {
      await updateEntry(entryId, editText.trim());
      setEntries(entries.map((e) => (e.entryId === entryId ? { ...e, content: editText.trim() } : e)));
      setEditingId(null);
    } catch (err) {
      setError(err.message || String(err));
    }
  };

  const handleDelete = async (entryId) => {
    try {
      await deleteEntry(entryId);
      setEntries(entries.filter((e) => e.entryId !== entryId));
    } catch (err) {
      setError(err.message || String(err));
    }
  };

  const handleSignOut = () => {
    signOut();
    onSignOut();
  };

  const cycleLang = () => setLangIdx((langIdx + 1) % LANG_CYCLE.length);

  const TABS = ["write", "history", "reflect"];

  return (
    <div style={{
      minHeight: "100vh",
      background: "linear-gradient(160deg, #fdf4ee 0%, #f0eaf8 50%, #eaf2f8 100%)",
      fontFamily: "'Georgia', 'Noto Serif SC', 'Noto Serif JP', serif",
      display: "flex", flexDirection: "column", alignItems: "center",
      padding: "0 0 40px",
    }}>
      <div style={{ width: "100%", maxWidth: 430, display: "flex", flexDirection: "column" }}>

        <div style={{ ...CARD, padding: "28px 16px 0", display: "flex", justifyContent: "space-between", alignItems: "flex-start" }}>
          <div style={{ flex: 1, minWidth: 0 }}>
            <h1 style={{ margin: 0, fontSize: 24, fontWeight: 700, color: "#5a3e6b", letterSpacing: "0.06em", lineHeight: 1.2 }}>
              {t.appName}
            </h1>
            <p style={{ margin: "4px 0 0", fontSize: 13, color: "#9b85b0", fontStyle: "italic" }}>{t.subtitle}</p>
          </div>
          <div style={{ display: "flex", gap: 8, flexShrink: 0, marginLeft: 12 }}>
            <button onClick={cycleLang} title={t.langNext} aria-label={t.langNext} style={{
              background: "rgba(255,255,255,0.7)", border: "1.5px solid #d4c5e6",
              borderRadius: "50%", width: 32, height: 32, fontSize: 15, color: "#7a5fa0",
              cursor: "pointer", fontFamily: "inherit", display: "flex", alignItems: "center", justifyContent: "center", padding: 0,
            }}>🌐</button>
            <button onClick={handleSignOut} title={t.signOut} aria-label={t.signOut} style={{
              background: "rgba(255,255,255,0.7)", border: "1.5px solid #d4c5e6",
              borderRadius: "50%", width: 32, height: 32, fontSize: 15, color: "#7a5fa0",
              cursor: "pointer", fontFamily: "inherit", display: "flex", alignItems: "center", justifyContent: "center", padding: 0,
            }}>⏻</button>
          </div>
        </div>

        <div style={{ ...CARD, marginTop: 16 }}>
          <div style={{
            background: "rgba(255,255,255,0.65)", borderRadius: 20,
            border: "1px solid rgba(255,255,255,0.8)", boxShadow: "0 4px 24px rgba(90,62,107,0.08)",
            padding: "20px", display: "flex", alignItems: "center", gap: 12,
          }}>
            <GratitudeTree streak={streak} />
            <div style={{ flex: 1, minWidth: 0 }}>
              <div style={{ fontSize: 42, fontWeight: 800, color: "#5a3e6b", lineHeight: 1 }}>{streak}</div>
              <div style={{ fontSize: 14, color: "#9b85b0", marginTop: 4 }}>{t.streak}</div>
              <div style={{ marginTop: 10, display: "flex", gap: 3, flexWrap: "nowrap" }}>
                {[...Array(7)].map((_, i) => {
                  const d = new Date();
                  d.setDate(d.getDate() - (6 - i));
                  const key = d.toISOString().split("T")[0];
                  const has = gratitudeEntries.some((e) => getDateKey(e.createdAt) === key);
                  return (
                    <div key={i} style={{
                      width: 24, height: 24, borderRadius: 6, flexShrink: 0,
                      background: has ? "#7bc47b" : "rgba(180,160,200,0.2)",
                      border: key === today ? "2px solid #7a5fa0" : "none",
                      display: "flex", alignItems: "center", justifyContent: "center",
                      fontSize: 9, color: has ? "#fff" : "transparent",
                    }}>{has ? "✓" : "·"}</div>
                  );
                })}
              </div>
              <div style={{ fontSize: 11, color: "#c0acd4", marginTop: 4 }}>{t.last7}</div>
            </div>
          </div>
        </div>

        <div style={{ ...CARD, marginTop: 16, display: "flex", gap: 6 }}>
          {TABS.map((tab) => (
            <button key={tab} onClick={() => setActiveTab(tab)} style={{
              flex: 1, padding: "10px 4px", borderRadius: 12, border: "none",
              background: activeTab === tab ? "#7a5fa0" : "rgba(255,255,255,0.6)",
              color: activeTab === tab ? "#fff" : "#9b85b0",
              fontSize: 13, fontFamily: "inherit", cursor: "pointer",
              fontWeight: activeTab === tab ? 600 : 400, transition: "all 0.2s",
            }}>
              {tab === "write" ? t.writeTab : tab === "history" ? t.historyTab : t.reflectTab}
            </button>
          ))}
        </div>

        {error && (
          <div style={{ ...CARD, marginTop: 12, fontSize: 13, color: "#b04040" }}>{error}</div>
        )}

        {activeTab === "write" && (
          <div style={{ ...CARD, marginTop: 12 }}>
            <div style={{
              background: "rgba(255,255,255,0.75)", borderRadius: 20,
              border: "1px solid rgba(255,255,255,0.9)", boxShadow: "0 2px 16px rgba(90,62,107,0.06)", padding: "20px",
            }}>
              <div style={{ fontSize: 13, color: "#9b85b0", marginBottom: 10 }}>
                {t.formatDate(new Date())} · {t.todayPrompt}
              </div>
              <textarea value={newText}
                onChange={(e) => setNewText(e.target.value)}
                placeholder={t.placeholder}
                style={{
                  width: "100%", minHeight: 160, border: "none", outline: "none",
                  background: "transparent", resize: "none", fontSize: 16,
                  color: "#3d2b52", lineHeight: 1.8, fontFamily: "inherit", boxSizing: "border-box",
                }} />
              <button onClick={handleCreate} disabled={!newText.trim()} style={{
                width: "100%", marginTop: 12, padding: "13px", borderRadius: 12, border: "none",
                background: justSaved ? "linear-gradient(135deg, #7bc47b, #5aad5a)"
                  : newText.trim() ? "linear-gradient(135deg, #a07ac4, #7a5fa0)" : "rgba(180,160,200,0.3)",
                color: justSaved || newText.trim() ? "#fff" : "#c0acd4",
                fontSize: 15, fontWeight: 600,
                cursor: !newText.trim() ? "default" : "pointer",
                fontFamily: "inherit", transition: "all 0.2s", letterSpacing: "0.05em",
              }}>{justSaved ? t.saved : t.save}</button>
            </div>
          </div>
        )}

        {activeTab === "history" && (
          <div style={{ ...CARD, marginTop: 12 }}>
            {loading && (
              <div style={{ textAlign: "center", color: "#c0acd4", padding: "40px 0", fontSize: 15 }}>
                {t.loading}
              </div>
            )}
            {!loading && gratitudeEntries.length === 0 && (
              <div style={{ textAlign: "center", color: "#c0acd4", padding: "40px 0", fontSize: 15 }}>
                {t.noEntries}
              </div>
            )}
            {gratitudeEntries.map((entry) => (
              <div key={entry.entryId} style={{
                background: "rgba(255,255,255,0.6)", borderRadius: 16,
                border: "1px solid rgba(255,255,255,0.9)", padding: "14px 18px", marginBottom: 10,
              }}>
                <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 6 }}>
                  <span style={{ fontSize: 12, color: "#b0a0c8" }}>{t.formatDate(new Date(entry.createdAt))}</span>
                  <div style={{ display: "flex", gap: 8 }}>
                    <button onClick={() => { setEditingId(entry.entryId); setEditText(entry.content); }} style={{
                      background: "none", border: "none", cursor: "pointer", fontSize: 13, color: "#b0a0c8", padding: 0,
                    }}>{t.edit}</button>
                    <button onClick={() => handleDelete(entry.entryId)} style={{
                      background: "none", border: "none", cursor: "pointer", fontSize: 13, color: "#d4a0a0", padding: 0,
                    }}>{t.delete}</button>
                  </div>
                </div>
                {editingId === entry.entryId ? (
                  <div>
                    <textarea value={editText} onChange={(e) => setEditText(e.target.value)} style={{
                      width: "100%", minHeight: 80, border: "1px solid #d4c5e6", borderRadius: 8,
                      padding: "8px", fontSize: 14, color: "#3d2b52", lineHeight: 1.7,
                      fontFamily: "inherit", resize: "none", boxSizing: "border-box", outline: "none",
                    }} />
                    <div style={{ display: "flex", gap: 8, marginTop: 8 }}>
                      <button onClick={() => handleUpdate(entry.entryId)} style={{
                        flex: 1, padding: "8px", borderRadius: 8, border: "none",
                        background: "#7a5fa0", color: "#fff", fontSize: 13,
                        fontFamily: "inherit", cursor: "pointer",
                      }}>✓</button>
                      <button onClick={() => setEditingId(null)} style={{
                        flex: 1, padding: "8px", borderRadius: 8, border: "1px solid #d4c5e6",
                        background: "transparent", color: "#9b85b0", fontSize: 13,
                        fontFamily: "inherit", cursor: "pointer",
                      }}>{t.cancel}</button>
                    </div>
                  </div>
                ) : (
                  <div style={{ fontSize: 14, color: "#3d2b52", lineHeight: 1.7, whiteSpace: "pre-wrap" }}>
                    {entry.content}
                  </div>
                )}
              </div>
            ))}
          </div>
        )}

        {activeTab === "reflect" && (
          <div style={{ ...CARD, marginTop: 12 }}>
            <div style={{ marginBottom: 14, paddingLeft: 4 }}>
              <div style={{ fontSize: 16, fontWeight: 700, color: "#5a3e6b" }}>{t.reflectTitle}</div>
              <div style={{ fontSize: 12, color: "#b0a0c8", marginTop: 3 }}>{t.reflectSubtitle}</div>
            </div>
            <div style={{
              background: "rgba(255,255,255,0.75)", borderRadius: 20,
              border: "1px solid rgba(255,255,255,0.9)", boxShadow: "0 2px 16px rgba(90,62,107,0.06)",
              padding: "16px 20px", marginBottom: 16,
            }}>
              {firstDate && (
                <div style={{
                  display: "inline-block", fontSize: 11, color: "#a07ac4",
                  background: "rgba(160,122,196,0.12)", borderRadius: 10,
                  padding: "2px 10px", marginBottom: 10,
                }}>
                  {t.dayLabel(dayNumber(new Date().toISOString(), firstDate))}
                </div>
              )}
              <textarea
                value={reflectText}
                onChange={(e) => setReflectText(e.target.value)}
                placeholder={t.reflectPlaceholder}
                style={{
                  width: "100%", minHeight: 120, border: "none", outline: "none",
                  background: "transparent", resize: "none", fontSize: 15,
                  color: "#3d2b52", lineHeight: 1.8, fontFamily: "inherit", boxSizing: "border-box",
                }} />
              <button onClick={handleSaveReflection} disabled={!reflectText.trim()} style={{
                width: "100%", marginTop: 10, padding: "12px", borderRadius: 12, border: "none",
                background: reflectSaved ? "linear-gradient(135deg, #7bc47b, #5aad5a)"
                  : reflectText.trim() ? "linear-gradient(135deg, #a07ac4, #7a5fa0)" : "rgba(180,160,200,0.3)",
                color: reflectText.trim() ? "#fff" : "#c0acd4",
                fontSize: 14, fontWeight: 600,
                cursor: !reflectText.trim() ? "default" : "pointer",
                fontFamily: "inherit", transition: "all 0.2s",
              }}>{reflectSaved ? t.reflectSaved : t.reflectSave}</button>
            </div>
            {reflectionEntries.length === 0 && (
              <div style={{ textAlign: "center", color: "#c0acd4", padding: "30px 0", fontSize: 14 }}>
                {t.reflectEmpty}
              </div>
            )}
            {reflectionEntries.map((entry, idx) => (
              <div key={entry.entryId} style={{ display: "flex", gap: 12, marginBottom: 16 }}>
                <div style={{ display: "flex", flexDirection: "column", alignItems: "center", flexShrink: 0 }}>
                  <div style={{
                    width: 12, height: 12, borderRadius: "50%", marginTop: 4,
                    background: idx === 0 ? "#7a5fa0" : "#c8b8e0",
                    boxShadow: idx === 0 ? "0 0 0 3px rgba(122,95,160,0.2)" : "none",
                  }} />
                  {idx < reflectionEntries.length - 1 && (
                    <div style={{ width: 2, flex: 1, background: "rgba(180,160,200,0.25)", marginTop: 4 }} />
                  )}
                </div>
                <div style={{
                  flex: 1, background: "rgba(255,255,255,0.65)", borderRadius: 16,
                  border: "1px solid rgba(255,255,255,0.9)", padding: "12px 16px",
                }}>
                  <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 8 }}>
                    <div style={{ display: "flex", gap: 8, alignItems: "center" }}>
                      <span style={{
                        fontSize: 11, color: "#a07ac4",
                        background: "rgba(160,122,196,0.12)", borderRadius: 10, padding: "2px 10px",
                      }}>{t.dayLabel(dayNumber(entry.createdAt, firstDate))}</span>
                      <span style={{ fontSize: 11, color: "#c0acd4" }}>
                        {t.formatDate(new Date(entry.createdAt))}
                      </span>
                    </div>
                    <div style={{ display: "flex", gap: 8 }}>
                      <button onClick={() => { setEditingId(entry.entryId); setEditText(entry.content); }} style={{
                        background: "none", border: "none", cursor: "pointer", fontSize: 13, color: "#b0a0c8", padding: 0,
                      }}>✏️</button>
                      <button onClick={() => handleDelete(entry.entryId)} style={{
                        background: "none", border: "none", cursor: "pointer", fontSize: 13, color: "#d4a0a0", padding: 0,
                      }}>🗑️</button>
                    </div>
                  </div>
                  {editingId === entry.entryId ? (
                    <div>
                      <textarea value={editText} onChange={(e) => setEditText(e.target.value)} style={{
                        width: "100%", minHeight: 80, border: "1px solid #d4c5e6", borderRadius: 8,
                        padding: "8px", fontSize: 14, color: "#3d2b52", lineHeight: 1.7,
                        fontFamily: "inherit", resize: "none", boxSizing: "border-box", outline: "none",
                      }} />
                      <div style={{ display: "flex", gap: 8, marginTop: 8 }}>
                        <button onClick={() => handleUpdate(entry.entryId)} style={{
                          flex: 1, padding: "8px", borderRadius: 8, border: "none",
                          background: "#7a5fa0", color: "#fff", fontSize: 13,
                          fontFamily: "inherit", cursor: "pointer",
                        }}>✓</button>
                        <button onClick={() => setEditingId(null)} style={{
                          flex: 1, padding: "8px", borderRadius: 8, border: "1px solid #d4c5e6",
                          background: "transparent", color: "#9b85b0", fontSize: 13,
                          fontFamily: "inherit", cursor: "pointer",
                        }}>{t.cancel}</button>
                      </div>
                    </div>
                  ) : (
                    <div style={{ fontSize: 14, color: "#3d2b52", lineHeight: 1.7, whiteSpace: "pre-wrap" }}>
                      {entry.content}
                    </div>
                  )}
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
```

### 4-7. src/App.js

```jsx
import { useState } from 'react';
import { getCurrentUser } from './auth/cognito';
import AuthScreen from './components/AuthScreen';
import JournalScreen from './components/JournalScreen';

export default function App() {
  const [authed, setAuthed] = useState(!!getCurrentUser());

  if (!authed) {
    return <AuthScreen onAuthSuccess={() => setAuthed(true)} />;
  }

  return <JournalScreen onSignOut={() => setAuthed(false)} />;
}
```

### 4-8. .env.example（テンプレート）

```bash
REACT_APP_AWS_REGION=ap-northeast-1
REACT_APP_COGNITO_USER_POOL_ID=
REACT_APP_COGNITO_CLIENT_ID=
REACT_APP_API_ENDPOINT=
```

### 4-9. 実際に動かす

```bash
npm install

cp .env.example .env.local
# .env.local を開いて、Part 2またはPart 3で得た値を埋める:
#   REACT_APP_COGNITO_USER_POOL_ID=（terraform output cognito_user_pool_id）
#   REACT_APP_COGNITO_CLIENT_ID=（terraform output cognito_user_pool_client_id）
#   REACT_APP_API_ENDPOINT=（terraform output api_endpoint、末尾のスラッシュは除く）

npm start
```

ブラウザで http://localhost:3000 が開き、ログイン画面が表示されれば成功。
「アカウントを作成する」→ メール・パスワードを入力 →
メールに届く確認コードを入力 → ログイン → 日記を書いて保存できることを確認する。

問題なく動いたら、本番用にビルドしてデプロイする:
```bash
npm run build
aws s3 sync build/ s3://<frontend_bucket_name> --delete
aws cloudfront create-invalidation --distribution-id <cloudfront_distribution_id> --paths "/*"
```

これでPhase 3は完成。Part 6（CI/CD自動化）・Part 7（確認チェックリスト）に
進んでもよいし、「なぜこの順番でコードを書いたか」が気になる場合はPart 5へ。

---

## Part 5 — フロントエンド：段階的に理解する版

Part 4はコードを完成形のまま貼った。このPartでは、**なぜこの6つのファイルを
この順番で作ったのか**を、「もしこのファイルが無かったら何が困るか」という
視点で1つずつ追っていく。コード自体はPart 4と同じものなので、ここでは
再掲せず「何が新しく必要になったか」だけを説明する。

### 5-1. なぜ最初に config.js を作るのか

一番最初に決めるべきことは、「このアプリはどのCognitoユーザープールと
どのAPIエンドポイントに繋がるのか」という接続先の情報。これが無いと
何も始まらない。しかし接続先の値（Cognito Pool ID、API URLなど）は
**環境ごとに変わる**（自分の環境と本番環境で値が違う）ため、コードに
直接書き込む（ハードコードする）のではなく、環境変数として外部から
注入できるようにしておく。これが`config.js`が最初に必要な理由であり、
`process.env.REACT_APP_*`という形にしている理由でもある
（Create React Appの仕様で、`REACT_APP_`から始まる環境変数だけが
ビルド時にJSに埋め込まれる）。

### 5-2. なぜ次に auth/cognito.js を作るのか（UIより先に）

「ログイン画面を作る」よりも先に「ログインの仕組み」を作る。理由は、
画面（UI）は「ログインの仕組みを呼び出すだけの見た目」でしかなく、
仕組みが無い状態でUIだけ作っても動作確認ができないから。

`auth/cognito.js`が提供する5つの関数（`signUp`・`confirmSignUp`・
`signIn`・`signOut`・`getIdToken`）は、それぞれCognitoの1つの操作に
対応している。もしこれが無かったら:
- サインアップボタンを押しても何も起きない（Cognitoと話す方法がない）
- ログインしても「ログインした」という情報をどこにも保持できない

ここで`amazon-cognito-identity-js`というライブラリを使い、AWS Amplifyは
**あえて使わない**。理由は、Amplifyは便利な半面「裏で何が起きているか」が
見えにくくなる。今回は学習目的も兼ねているため、JWTトークンを取得する
瞬間（`getIdToken`関数）が自分の目で追えるライブラリを選んだ。

### 5-3. なぜ次に api/entries.js を作るのか（画面より先に）

ログインの仕組みができたら、次は「ログインした状態でAPIを呼ぶ仕組み」を
作る。これも画面より先に作る理由は5-2と同じ:「ボタンを押したら何が
起きるか」を、まずボタン無しで確定させておきたいから。

`api/entries.js`でやっていることは実質1つだけ:
**すべてのAPIリクエストのAuthorizationヘッダーに、Cognitoから取得した
IDトークンを付ける**（`authHeaders`関数）。これが無いと、API Gatewayの
JWT Authorizerは「トークンが無い」として全リクエストを401で拒否する。

もう1つの重要な仕掛けが、401が返ってきたときのエラーメッセージの作り方
（`throw new Error(`${res.status} ${body}`)`）。ステータスコードを
メッセージの先頭に埋め込むことで、呼び出し側が
`err.message.startsWith('401')`という単純な文字列チェックだけで
「セッション切れ」を判定できるようにしている。これは次のPart 5-5で使う。

### 5-4. なぜ次に AuthScreen.js を作るのか

仕組み（5-2）ができて初めて、画面を作る意味が生まれる。AuthScreenは
`signIn`/`signUp`/`confirmSignUp`という3つの関数をボタンに繋いでいる
だけのシンプルな画面。ここで意識したのは**状態遷移**:

```
signIn（ログイン画面）
  ↓ 「アカウントを作成する」
signUp（登録画面）
  ↓ 登録成功
confirm（確認コード入力画面）
  ↓ 確認成功
signIn（ログイン画面に戻る）
```

この3状態を`useState('signIn')`という1つの変数（`mode`）で管理している。
「今どの画面を出すか」を複数のbooleanフラグ（`isSignUp`, `isConfirm`...）
で管理すると、矛盾した組み合わせ（両方true等）が起きうるバグの温床になる。
1つの変数に3つの値のどれかが入る、という設計の方が事故が起きにくい。

### 5-5. なぜ次に JournalScreen.js を作るのか（一番最後・一番大きい）

すべての土台（接続先・認証・API呼び出し・ログイン画面）が揃って初めて、
本体である日記のCRUD画面に着手できる。このファイルが一番大きいのは、
「今日」「履歴」「気づき」という3つのタブの表示とロジックを1ファイルに
まとめているため。あえて3ファイルに分割していない理由は、3つのタブが
同じ`entries`という状態（state）を共有しており、分割すると逆に
状態の受け渡しが煩雑になるため（このアプリの規模ではContextや
状態管理ライブラリを導入するほどの複雑さではない）。

このファイルを書く際、実際に以下の順番で機能を追加していくと、
段階を追って理解しやすい:

1. **まずlistEntriesだけ**: マウント時に`load()`を呼んで`entries`に
   セットするだけの、読み取り専用画面を作る
2. **401ハンドリングを追加**: 5-3で仕込んだ「401ならメッセージが
   `401`で始まる」という約束を使い、`load()`のcatchで
   `signOut()` + `onSignOut()`を呼んで強制的にログイン画面へ戻す
   処理を追加する。これが無いと、セッションが切れた後もエラー画面が
   出続けるだけで、ユーザーが自力でログイン画面に戻る手段がなくなる
3. **createEntryを追加**: テキストエリア＋保存ボタンを追加し、
   保存できたら`entries`の先頭に新しいエントリを足す
   （`setEntries([entry, ...entries])`）。ここで一覧を再取得（再度
   `listEntries()`を呼ぶ）せずに、レスポンスで返ってきた`entry`を
   直接配列に足しているのは、無駄なAPI呼び出しを避けるため
4. **update/deleteを追加**: 編集中のIDを`editingId`で管理し、
   「表示中」か「編集フォーム表示中」かをその1つの変数で切り替える。
   ここも5-4と同じく、複数のbooleanではなく1つの値で状態を持つ設計
5. **entryType（gratitude/reflection）によるタブ分割を追加**:
   バックエンドの`entries`テーブルは1種類だが、フロントエンドが
   `entries.filter(e => e.entryType === "reflection")`のように
   クライアント側で仕分けている。なぜAPIを2つに分けないかは
   `docs/Frontend-Design.md`の「データモデル」の節を参照
6. **連続日数（streak）・日数バッジ（day number）を追加**:
   最後に、見た目の演出部分（`GratitudeTree`と連動する連続日数、
   気づきタブの「N日目」表示）を追加する。この2つのロジックは
   `docs/Frontend-Design.md`の「連続日数・日数バッジのロジック」の節に
   詳しい説明がある（特に、なぜ「感謝の最古エントリ」ではなく
   「全体の最古エントリ」を基準にしているか、という実際にあった
   バグ修正の話）

### 5-6. なぜ最後に App.js なのか

`App.js`はこのアプリで一番小さいファイルだが、書く順番は一番最後になる。
理由は、「ログインしていなければAuthScreen、していればJournalScreen」を
切り替えるという*この1行の判断*のために、AuthScreenとJournalScreenの
**両方が既に存在していないと書きようがない**から。

```jsx
if (!authed) {
  return <AuthScreen onAuthSuccess={() => setAuthed(true)} />;
}
return <JournalScreen onSignOut={() => setAuthed(false)} />;
```

`getCurrentUser()`（5-2で作った関数）でページ読み込み時にログイン済みか
どうかを確認しているが、これは「ローカルに保存されたセッション情報が
あるかどうか」を見ているだけで、トークンが本当にまだ有効かまでは
検証していない。無効だった場合は、5-5で仕込んだ401ハンドリングが
JournalScreenの初回読み込み時に発動し、結果的にログイン画面へ戻る。
つまり「本当にログイン済みか」の最終判定は、実は最初のAPI呼び出しが
兼ねている、という設計になっている。

### 5-7. まとめ: この順番で作った理由

```
config.js          → 「どこに繋ぐか」を決めないと何も始まらない
auth/cognito.js     → 「ログインの仕組み」がないと画面を作る意味がない
api/entries.js      → 「認証付きAPI呼び出し」の共通処理を1箇所にまとめる
AuthScreen.js        → ここで初めて「仕組み」を画面に繋ぐ
JournalScreen.js     → 本体。土台が全部揃って初めて着手できる
App.js               → 2つの画面が両方存在して初めて「切り替え」を書ける
```

**土台（設定・認証・API通信）を先に、画面（UI）を後に**という順番は、
このアプリに限らずログイン付きWebアプリを作るときの一般的な考え方。
先に画面から作ってしまうと、「ボタンを押したら何が起きるべきか」が
決まらないまま見た目だけ進めることになり、後から仕組みを繋ぎ込む際に
画面側の設計をやり直すことになりやすい。

---

## Part 6 — GitHub Actionsで自動デプロイを設定する

ここまでで手動デプロイ（`terraform apply`や`npm run build && aws s3 sync`を
自分で実行する）はできる状態になっている。Part 6では、「コードをpushしたら
自動でデプロイされる」ようにする。

### 6-1. 全体方針

このプロジェクトでは、**インフラ（Cognito・DynamoDB・API Gateway・S3/
CloudFrontの作成）は自動化しない**。自動化するのは「できあがったインフラに
対して、アプリケーションコードを更新する」部分だけ。

理由: CI（GitHub Actions）が使うIAMユーザーに「インフラを作る権限」まで
持たせると、GitHub Actionsの設定ミスや悪意あるPull Requestが原因で
AWSアカウントの構成そのものが変更されるリスクがある。「Lambdaのコードを
更新する」「S3の中身を差し替える」だけに権限を絞っておけば、被害の範囲を
限定できる。

そのため、ワークフローは2つに分ける:
- `deploy-03-serverless.yml` — `backend/lambda/**`が変更されたらLambdaの
  コードだけ更新する
- `deploy-03-frontend.yml` — `frontend/**`が変更されたらReactをビルドして
  S3+CloudFrontに反映する

### 6-2. CI専用のIAM権限を絞って用意する

まず、GitHub Actionsが使うIAMユーザーを用意する（初回のみ）。
Part 2または3で既にIAMユーザーを作っていなければ、以下で新規作成する:

```bash
aws iam create-user --user-name github-actions-portfolio-03
aws iam create-access-key --user-name github-actions-portfolio-03
# 表示される AccessKeyId と SecretAccessKey を保存する
```

このユーザーに、Lambdaコード更新用の権限だけを追加する
（Terraform版なら`iam.tf`の`aws_iam_user_policy.github_actions_lambda_deploy`、
CloudFormation版なら`iam-cicd.yaml`が、まさにこの権限を作る役目）。
Part 2または3を最後まで終えていれば、この権限は既に付与済みのはず。

### 6-3. Lambdaデプロイ用ワークフロー

`.github/workflows/deploy-03-serverless.yml`:
```yaml
name: Portfolio 03 - Lambda Deploy

on:
  push:
    branches: [main]
    paths:
      - 'aws-portfolio-03-serverless/backend/lambda/**'
  pull_request:
    branches: [main]
    paths:
      - 'aws-portfolio-03-serverless/backend/lambda/**'
  workflow_dispatch:

defaults:
  run:
    working-directory: aws-portfolio-03-serverless

jobs:
  deploy:
    name: Update Lambda function code
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Zip Lambda functions
        run: |
          for fn in create_entry list_entries update_entry delete_entry; do
            cd "backend/lambda/$fn"
            zip -r "../../../$fn.zip" .
            cd -
          done

      - name: Configure AWS credentials
        if: github.event_name == 'push' || github.event_name == 'workflow_dispatch'
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ap-northeast-1

      - name: Update function code
        if: github.event_name == 'push' || github.event_name == 'workflow_dispatch'
        run: |
          aws lambda update-function-code \
            --function-name aws-portfolio-03-serverless-create-entry \
            --zip-file fileb://create_entry.zip
          aws lambda update-function-code \
            --function-name aws-portfolio-03-serverless-list-entries \
            --zip-file fileb://list_entries.zip
          aws lambda update-function-code \
            --function-name aws-portfolio-03-serverless-update-entry \
            --zip-file fileb://update_entry.zip
          aws lambda update-function-code \
            --function-name aws-portfolio-03-serverless-delete-entry \
            --zip-file fileb://delete_entry.zip
```

### 6-4. フロントエンドデプロイ用ワークフロー

`.github/workflows/deploy-03-frontend.yml`:
```yaml
name: Portfolio 03 - Frontend Deploy

on:
  push:
    branches: [main]
    paths:
      - 'aws-portfolio-03-serverless/frontend/**'
  pull_request:
    branches: [main]
    paths:
      - 'aws-portfolio-03-serverless/frontend/**'
  workflow_dispatch:

defaults:
  run:
    working-directory: aws-portfolio-03-serverless/frontend

jobs:
  build:
    name: Build
    runs-on: ubuntu-latest
    env:
      REACT_APP_AWS_REGION: ap-northeast-1
      REACT_APP_API_ENDPOINT: ${{ vars.PHASE3_API_ENDPOINT }}
      REACT_APP_COGNITO_USER_POOL_ID: ${{ vars.PHASE3_COGNITO_USER_POOL_ID }}
      REACT_APP_COGNITO_CLIENT_ID: ${{ vars.PHASE3_COGNITO_CLIENT_ID }}
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '22'
          cache: 'npm'
          cache-dependency-path: 'aws-portfolio-03-serverless/frontend/package-lock.json'
      - run: npm ci
      - run: npm run build

  deploy:
    name: Deploy to AWS
    runs-on: ubuntu-latest
    needs: build
    if: github.event_name == 'push' || github.event_name == 'workflow_dispatch'
    env:
      REACT_APP_AWS_REGION: ap-northeast-1
      REACT_APP_API_ENDPOINT: ${{ vars.PHASE3_API_ENDPOINT }}
      REACT_APP_COGNITO_USER_POOL_ID: ${{ vars.PHASE3_COGNITO_USER_POOL_ID }}
      REACT_APP_COGNITO_CLIENT_ID: ${{ vars.PHASE3_COGNITO_CLIENT_ID }}
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '22'
          cache: 'npm'
          cache-dependency-path: 'aws-portfolio-03-serverless/frontend/package-lock.json'
      - run: npm ci
      - run: npm run build
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ap-northeast-1
      - name: Deploy to S3
        run: aws s3 sync build/ s3://${{ vars.PHASE3_S3_BUCKET_NAME }} --delete
      - name: Invalidate CloudFront cache
        run: |
          aws cloudfront create-invalidation \
            --distribution-id ${{ vars.PHASE3_CLOUDFRONT_DIST_ID }} \
            --paths "/*"
```

### 6-5. GitHubリポジトリにSecrets/Variablesを登録する

GitHub → 対象リポジトリ → **Settings** → **Secrets and variables** →
**Actions** を開く。この画面には上部に **「Secrets」タブ**と
**「Variables」タブ**の2つがあり、**完全に別の名前空間**になっている点に
特に注意する。

> ⚠️ **実際にここでハマった経験談**: `${{ vars.PHASE3_S3_BUCKET_NAME }}`と
> ワークフローに書いてあるのに、値をSecretsタブに登録してしまうと、
> `vars.*`からは参照できず**空文字列**として扱われる。結果、
> `aws s3 sync build/ s3:// --delete`のようにバケット名が空のコマンドに
> なり、`Invalid bucket name ""`という分かりにくいエラーで失敗する。
> 「Secretsに登録したのに動かない」場合は、まずタブを間違えていないか
> 疑うこと。

**「Secrets」タブ**に登録する（機密情報・AWS認証情報）:

| Secret名 | 値 |
|---|---|
| `AWS_ACCESS_KEY_ID` | 6-2で作ったIAMユーザーのアクセスキーID |
| `AWS_SECRET_ACCESS_KEY` | 同シークレットアクセスキー |

**「Variables」タブ**に登録する（機密ではない設定値。理由: どのみち
ビルド後のJSファイルに埋め込まれ、ブラウザの開発者ツールから誰でも
見える値のため、Secretsとして隠す意味がない）:

| Variable名 | 値 |
|---|---|
| `PHASE3_API_ENDPOINT` | `terraform output api_endpoint`の値 |
| `PHASE3_COGNITO_USER_POOL_ID` | `terraform output cognito_user_pool_id`の値 |
| `PHASE3_COGNITO_CLIENT_ID` | `terraform output cognito_user_pool_client_id`の値 |
| `PHASE3_S3_BUCKET_NAME` | `terraform output frontend_bucket_name`の値 |
| `PHASE3_CLOUDFRONT_DIST_ID` | `terraform output cloudfront_distribution_id`の値 |

### 6-6. 動作確認

```bash
git add .
git commit -m "test: trigger CI"
git push origin main
```

GitHubリポジトリの「Actions」タブを開き、`Portfolio 03 - Lambda Deploy`と
`Portfolio 03 - Frontend Deploy`が実行され、両方成功（緑のチェックマーク）に
なることを確認する。

> 💡 pushした変更が`backend/lambda/**`だけならLambda Deployのみ、
> `frontend/**`だけならFrontend Deployのみが起動する（`paths`フィルターの
> おかげ）。両方を同時に変更してpushすれば、両方が並行して起動する。

---

## Part 7 — 完成確認チェックリスト

実際に手を動かして、以下がすべてYESになることを確認する。

### インフラ
- [ ] `terraform plan`（またはCloudFormationの`describe-stacks`）で
      すべてのリソースが意図通り作成されている
- [ ] `curl -i https://<api_endpoint>/entries` が **401** を返す
      （認証なしアクセスが拒否される）

### バックエンド（Lambda直接テスト）
- [ ] `aws lambda invoke`でcreate_entryを呼び、DynamoDBに1件書き込まれる
- [ ] 同様にlist/update/deleteもそれぞれ意図通り動く
- [ ] テストで作ったダミーデータは削除して片付けておく
      （`aws dynamodb scan --table-name <table> --select COUNT`で件数確認）

### フロントエンド（実際のブラウザで）
- [ ] `https://<自分のドメインまたはCloudFrontドメイン>/` を開くと
      ログイン画面が表示される
- [ ] 「アカウントを作成する」→ メール・パスワード入力 → 登録できる
- [ ] メールに届いた確認コードを入力 → 確認が通る
- [ ] ログインできる（ログイン後、日記画面が表示される）
- [ ] 「今日」タブで日記を保存できる → 連続日数（streak）が1になる
- [ ] 「履歴」タブに保存した日記が表示される → 編集できる → 削除できる
- [ ] 「気づき」タブでも同様にCRUDができる
- [ ] 言語切り替えボタン（🌐）で日本語→英語→中国語→日本語と巡回する
- [ ] ログアウトボタン（⏻）でログイン画面に戻る

### CI/CD
- [ ] `backend/lambda/`配下を編集してpush → Lambda Deployだけ起動し成功する
- [ ] `frontend/`配下を編集してpush → Frontend Deployだけ起動し成功する
- [ ] デプロイ後、実際にブラウザで変更が反映されていることを確認する
      （CloudFrontのキャッシュ無効化が効いているか）

すべてチェックできたら、Phase 3は完成。

---

## Part 8 — 後片付け（リソースの削除）

学習が終わり、費用が気になる場合や作り直したい場合は、以下でリソースを削除する。
（現状のコストは`docs/Cost-Estimation.md`の通りほぼ$0.00/月なので、急いで
削除する必要は無いが、練習として一度壊してみるのもよい）

### Terraform版の削除

```bash
cd aws-portfolio-03-serverless/infrastructure/terraform
terraform destroy
```

S3バケットは`force_destroy = true`にしているため、中身のファイルごと
自動的に削除される。

### CloudFormation版の削除

**作った時と逆の順序**で削除する（依存関係があるため、順序を守らないと
「他のスタックから参照されている」エラーで削除に失敗する）。

```bash
cd aws-portfolio-03-serverless/infrastructure/cloudformation

aws cloudformation delete-stack --stack-name portfolio-03-iam-cicd
aws cloudformation delete-stack --stack-name portfolio-03-route53
aws cloudformation delete-stack --stack-name portfolio-03-cloudfront
aws cloudformation delete-stack --stack-name portfolio-03-acm --region us-east-1
aws cloudformation delete-stack --stack-name portfolio-03-s3
aws cloudformation delete-stack --stack-name portfolio-03-api
aws cloudformation delete-stack --stack-name portfolio-03-lambda
aws cloudformation delete-stack --stack-name portfolio-03-cognito
aws cloudformation delete-stack --stack-name portfolio-03-dynamodb
```

> 💡 S3バケットは中身が空でないと削除できないため、
> `aws s3 rm s3://<bucket-name> --recursive`で中身を空にしてから
> `delete-stack`を実行する必要がある場合がある。

削除後、`aws cloudformation describe-stacks`や AWSコンソールで
すべてのスタックが消えていることを確認する。

---

## おわりに

このチュートリアルに沿って進めれば、AIの助けを借りずにPhase 3を
ゼロから再現できるはず。もし途中で詰まった場合、実際にこのプロジェクトで
遭遇した問題と解決策は`docs/Architecture.md`・`docs/Frontend-Design.md`・
`infrastructure/terraform/README.md`にも記録してあるので、あわせて参照する。

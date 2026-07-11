# Phase 03 — Terraform

Builds the full serverless stack (Cognito, DynamoDB, Lambda, API Gateway) plus the
frontend hosting (S3 + CloudFront + ACM + Route 53) for `journal.daoxiao.org`.

## Configuration

| File | Resources Created |
|------|------------------|
| `providers.tf` | AWS provider (ap-northeast-1) + `us_east_1` alias (required for CloudFront's ACM cert) |
| `variables.tf` | Input variables (region, project name, existing IAM user name, domain, hosted zone ID) |
| `cognito.tf` | Cognito User Pool + App Client (no client secret — public SPA) |
| `dynamodb.tf` | `entries` table, on-demand billing, PK=`userId` / SK=`entryId` |
| `lambda.tf` | Execution IAM role + policy, 4 Lambda functions (Python 3.12), code zipped via the `archive` provider |
| `api_gateway.tf` | HTTP API, JWT Authorizer (Cognito-backed), 4 routes/integrations, Lambda invoke permissions |
| `iam.tf` | Adds two scoped inline policies to the existing `github-actions-portfolio-01` user: Lambda code deploy, and frontend S3 sync + CloudFront invalidation |
| `s3_frontend.tf` | Private S3 bucket for the React build (own bucket, independent of Phase 1) |
| `cloudfront.tf` | OAC + CloudFront distribution serving `journal.daoxiao.org` |
| `acm.tf` | ACM certificate (us-east-1) + DNS validation |
| `route53.tf` | A record (alias) in the existing `daoxiao.org` hosted zone |
| `outputs.tf` | API endpoint, Cognito IDs, DynamoDB table name, frontend bucket/distribution IDs, site URL |

## Deploy

```bash
cd aws-portfolio-03-serverless/infrastructure/terraform

# 1. Initialize
terraform init

# 2. Preview changes
terraform plan

# 3. Deploy
terraform apply
```

Then build and publish the frontend once manually (subsequent deploys are
automated by `deploy-03-frontend.yml` on every push to `frontend/**` — see
the [Phase 03 root README](../../README.md)):

```bash
cd ../../frontend
npm install
cp .env.example .env.local   # fill in with the outputs below
npm run build
aws s3 sync build/ s3://<frontend_bucket_name> --delete
aws cloudfront create-invalidation --distribution-id <cloudfront_distribution_id> --paths "/*"
```

## Outputs

```bash
terraform output
```

| Output | Purpose |
|--------|---------|
| `api_endpoint` | HTTP API base URL — set as `REACT_APP_API_ENDPOINT` |
| `cognito_user_pool_id` | Set as `REACT_APP_COGNITO_USER_POOL_ID` |
| `cognito_user_pool_client_id` | Set as `REACT_APP_COGNITO_CLIENT_ID` |
| `dynamodb_table_name` | Reference only — already wired into Lambda via env var |
| `frontend_bucket_name` | `aws s3 sync` target |
| `cloudfront_distribution_id` | `aws cloudfront create-invalidation` target |
| `site_url` | `https://journal.daoxiao.org/` |

## Notes (real gotchas hit while deploying this phase)

- **`aws-cli-user` needed 4 new IAM policies before `terraform apply` would succeed.**
  This account's local deploy user only had the Phase 1/2 policies (Route53/CloudFront/
  ACM/IAM/S3/CloudFormation FullAccess). The first `apply` attempt failed partway through
  (only the Lambda execution role got created) with `AccessDeniedException` on
  `apigateway:POST`, `cognito-idp:CreateUserPool`, and `dynamodb:CreateTable`. Fixed by
  attaching `AmazonAPIGatewayAdministrator`, `AmazonCognitoPowerUser`,
  `AmazonDynamoDBFullAccess`, and `AWSLambda_FullAccess` to `aws-cli-user`. If a future
  phase introduces another new AWS service, expect the same pattern.
- **ACM certificates for CloudFront must be requested in `us-east-1`**, regardless of
  which region the rest of the stack runs in — hence the `aws.us_east_1` provider alias.
- **DynamoDB on-demand mode has no free tier for request costs** (only the 25 GB storage
  allowance is always-free). This didn't matter at portfolio-scale traffic, but it's not
  the same free tier as the frequently-cited "25 WCU/25 RCU always free," which only
  applies to *provisioned* capacity mode.
- **CI/CD (`deploy-03-serverless.yml`) only redeploys Lambda code.** Infra changes
  (Cognito/API Gateway/DynamoDB/S3/CloudFront/Route53/ACM) are applied manually via
  `terraform apply`, matching Phase 2's approach — the CI IAM user intentionally doesn't
  have IAM role / Cognito / CloudFront creation permissions.

## Destroy

```bash
terraform destroy
```

`force_destroy = true` on the S3 bucket — contents are deleted automatically before the
bucket is removed. Cognito/DynamoDB/Lambda/API Gateway/CloudFront/ACM/Route53 resources
are all scoped to this phase only; destroying this state has no effect on Phase 1 or 2.

---

# Phase 03 — Terraform（日本語）

サーバーレススタック（Cognito・DynamoDB・Lambda・API Gateway）とフロントエンド配信基盤
（S3 + CloudFront + ACM + Route 53、`journal.daoxiao.org`）の両方をこのTerraformで構築する。

## 構成

| ファイル | 作成されるリソース |
|---------|-----------------|
| `providers.tf` | AWSプロバイダー（ap-northeast-1）+ `us_east_1`エイリアス（CloudFrontのACM証明書に必須） |
| `variables.tf` | 入力変数（リージョン・プロジェクト名・既存IAMユーザー名・ドメイン・ホストゾーンID） |
| `cognito.tf` | Cognito User Pool + App Client（クライアントシークレットなし・公開SPA向け） |
| `dynamodb.tf` | `entries`テーブル、オンデマンド課金、PK=`userId` / SK=`entryId` |
| `lambda.tf` | 実行用IAMロール + ポリシー、Lambda関数4本（Python 3.12）、`archive`プロバイダでコードをzip化 |
| `api_gateway.tf` | HTTP API、JWT Authorizer（Cognito連携）、ルート/統合4本、Lambda呼び出し許可 |
| `iam.tf` | 既存の`github-actions-portfolio-01`ユーザーに、Lambdaコードデプロイ用とフロントエンドS3同期+CloudFront無効化用の2つの限定インラインポリシーを追加 |
| `s3_frontend.tf` | Reactビルド用のプライベートS3バケット（Phase 1とは独立した専用バケット） |
| `cloudfront.tf` | OAC + `journal.daoxiao.org`を配信するCloudFrontディストリビューション |
| `acm.tf` | ACM証明書（us-east-1）+ DNS検証 |
| `route53.tf` | 既存の`daoxiao.org`ホストゾーンへのAレコード（エイリアス） |
| `outputs.tf` | APIエンドポイント・Cognito ID・DynamoDBテーブル名・フロントエンドのバケット/ディストリビューションID・公開URL |

## デプロイ手順

```bash
cd aws-portfolio-03-serverless/infrastructure/terraform

# 1. 初期化
terraform init

# 2. 実行計画の確認
terraform plan

# 3. デプロイ
terraform apply
```

続いて初回のみフロントエンドを手動でビルド・公開する（以降の変更は
`frontend/**`へのpush時に`deploy-03-frontend.yml`が自動デプロイする。
詳細は[Phase 03ルートREADME](../../README.md)参照）:

```bash
cd ../../frontend
npm install
cp .env.example .env.local   # 下記outputsの値を書き込む
npm run build
aws s3 sync build/ s3://<frontend_bucket_name> --delete
aws cloudfront create-invalidation --distribution-id <cloudfront_distribution_id> --paths "/*"
```

## 出力値の確認

```bash
terraform output
```

| Output | 用途 |
|--------|------|
| `api_endpoint` | HTTP APIのベースURL — `REACT_APP_API_ENDPOINT`に設定 |
| `cognito_user_pool_id` | `REACT_APP_COGNITO_USER_POOL_ID`に設定 |
| `cognito_user_pool_client_id` | `REACT_APP_COGNITO_CLIENT_ID`に設定 |
| `dynamodb_table_name` | 参照用（Lambdaには環境変数経由で既に注入済み） |
| `frontend_bucket_name` | `aws s3 sync`の同期先 |
| `cloudfront_distribution_id` | `aws cloudfront create-invalidation`の対象 |
| `site_url` | `https://journal.daoxiao.org/` |

## 注意事項（このPhaseのデプロイで実際に遭遇した点）

- **`aws-cli-user`に4つのIAMポリシーを追加するまで`terraform apply`が失敗した。**
  このアカウントのローカルデプロイ用ユーザーには、Phase 1/2で使ったポリシー
  （Route53/CloudFront/ACM/IAM/S3/CloudFormationのFullAccess）しか付与されておらず、
  初回の`apply`は`apigateway:POST`・`cognito-idp:CreateUserPool`・`dynamodb:CreateTable`
  で`AccessDeniedException`となり、Lambda実行ロールだけが作成された中途半端な状態で
  停止した。`AmazonAPIGatewayAdministrator`・`AmazonCognitoPowerUser`・
  `AmazonDynamoDBFullAccess`・`AWSLambda_FullAccess`をaws-cli-userにattachして解決。
  今後新しいAWSサービスを使うPhaseを追加する際も、同様の対応が必要になる可能性が高い。
- **CloudFront用のACM証明書はリージョンに関わらず`us-east-1`でのみ発行可能**という
  AWSのグローバル制約があるため、`aws.us_east_1`プロバイダエイリアスを使用している。
- **DynamoDBオンデマンドモードにはリクエスト課金の無料枠が無い**（常時無料なのは
  ストレージ25GB分のみ）。ポートフォリオ規模のトラフィックでは問題にならなかったが、
  よく引用される「25 WCU/25 RCU常時無料」はProvisionedモード限定であり、
  オンデマンドモードには適用されない点に注意。
- **CI/CD（`deploy-03-serverless.yml`）はLambdaコードの再デプロイのみを行う。**
  インフラ変更（Cognito/API Gateway/DynamoDB/S3/CloudFront/Route53/ACM）はPhase 2と
  同様にローカルから`terraform apply`で手動デプロイする方針。CI用IAMユーザーには
  意図的にIAMロール・Cognito・CloudFrontの作成権限を持たせていない。

## 削除

```bash
terraform destroy
```

S3バケットは`force_destroy = true`のため、バケット内のファイルも自動削除される。
Cognito/DynamoDB/Lambda/API Gateway/CloudFront/ACM/Route53はすべてこのPhase専用の
リソースであり、このstateをdestroyしてもPhase 1・Phase 2には影響しない。

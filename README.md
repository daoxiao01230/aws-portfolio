# Portfolio 01 — Static Site Hosting

React app deployed to AWS with S3 + CloudFront, automated via GitHub Actions CI/CD, with infrastructure defined as code using both Terraform and CloudFormation.

## Architecture

```
GitHub (push to main)
        │
GitHub Actions
  ┌─────┴─────┐
[build]    [deploy] ← runs only on main push
  │            │
npm ci      npm ci
npm build   npm build
            aws s3 sync --delete
            cloudfront invalidation
        │
    S3 Bucket (private)
        │
 CloudFront (OAC)
        │
   HTTPS endpoint
```

## AWS Services Used

| Service | Purpose |
|---------|---------|
| S3 | Store static build files (private bucket) |
| CloudFront | CDN + HTTPS + OAC |
| GitHub Actions | CI/CD — build check on PR, auto deploy on main |
| CloudFormation | Infrastructure as Code (option A) |
| Terraform | Infrastructure as Code (option B) |

## Deploy Infrastructure

### Option A: Terraform

```bash
cd terraform
terraform init
terraform apply -var="bucket_name=your-bucket-name"
```

Outputs: `website_url`, `cloudfront_distribution_id`, `s3_bucket_name`

### Option B: CloudFormation

```bash
aws cloudformation deploy \
  --template-file cloudformation/template.yaml \
  --stack-name portfolio-01-static-site \
  --parameter-overrides BucketName=your-bucket-name
```

## Setup GitHub Actions CI/CD

Add these secrets in GitHub → Settings → Secrets and variables → Actions:

| Secret | Value |
|--------|-------|
| `AWS_ACCESS_KEY_ID` | IAM user access key |
| `AWS_SECRET_ACCESS_KEY` | IAM user secret key |
| `AWS_REGION` | e.g. `us-east-1` |
| `S3_BUCKET_NAME` | From Terraform/CFN output |
| `CLOUDFRONT_DISTRIBUTION_ID` | From Terraform/CFN output |

**CI/CD behavior:**
- `push` to `main` → build + deploy + CloudFront invalidation
- Pull Request → build check only (no deploy)
- Manual run → GitHub Actions tab → Run workflow

## Local Development

```bash
npm install
npm start
```

## Key Decisions

- S3 bucket is **private** — CloudFront accesses it via Origin Access Control (OAC), not public ACL
- 403/404 errors redirect to `index.html` to support client-side routing
- CI/CD uses 2 separate jobs: `build` (runs on all events) and `deploy` (main only)
- Both Terraform and CloudFormation produce identical infrastructure

---

# Portfolio 01 — 静的サイトホスティング

ReactアプリをAWSにデプロイする。S3 + CloudFrontで静的コンテンツを配信し、GitHub Actions CI/CDで自動デプロイ、インフラはTerraformとCloudFormationの2種類でコード化している。

## アーキテクチャ

```
GitHub（mainへpush）
        │
GitHub Actions
  ┌─────┴─────┐
[build]    [deploy] ← mainへのpushのみ実行
  │            │
npm ci      npm ci
npm build   npm build
            aws s3 sync --delete
            CloudFront Invalidation
        │
    S3バケット（プライベート）
        │
 CloudFront（OAC経由）
        │
   HTTPSエンドポイント
```

## 使用AWSサービス

| サービス | 用途 |
|---------|------|
| S3 | 静的ファイル（HTML/CSS/JS）の保存（プライベートバケット） |
| CloudFront | CDN + HTTPS + OAC認証 |
| GitHub Actions | CI/CD — PRでビルド確認、mainで自動デプロイ |
| CloudFormation | Infrastructure as Code（選択肢A） |
| Terraform | Infrastructure as Code（選択肢B） |

## インフラのデプロイ

### 選択肢A: Terraform

```bash
cd terraform
terraform init
terraform apply -var="bucket_name=バケット名"
```

実行後の出力: `website_url`、`cloudfront_distribution_id`、`s3_bucket_name`

### 選択肢B: CloudFormation

```bash
aws cloudformation deploy \
  --template-file cloudformation/template.yaml \
  --stack-name portfolio-01-static-site \
  --parameter-overrides BucketName=バケット名
```

## GitHub Actions CI/CDのセットアップ

GitHub → Settings → Secrets and variables → Actions で以下のSecretsを設定する:

| Secret名 | 設定値 |
|----------|--------|
| `AWS_ACCESS_KEY_ID` | IAMユーザーのアクセスキーID |
| `AWS_SECRET_ACCESS_KEY` | IAMユーザーのシークレットアクセスキー |
| `AWS_REGION` | リージョン（例: `us-east-1`） |
| `S3_BUCKET_NAME` | Terraform/CFNの出力値 |
| `CLOUDFRONT_DISTRIBUTION_ID` | Terraform/CFNの出力値 |

**CI/CDの動作:**
- `main`へpush → ビルド + S3デプロイ + CloudFront Invalidation
- Pull Request → ビルド確認のみ（デプロイしない）
- 手動実行 → ActionsタブのRun workflowボタンから実行

## ローカル開発

```bash
npm install
npm start
```

## 設計上の判断

- S3バケットは**プライベート** — CloudFrontはOAC（Origin Access Control）経由でのみアクセス。直接公開しない。
- 403/404エラーは`index.html`にリダイレクト — ReactRouterのクライアントサイドルーティングを機能させるため。
- CI/CDは2ジョブ構成: `build`（全イベントで実行）と`deploy`（mainのみ）に分離。
- TerraformとCloudFormationは同一のインフラを構築する。用途に応じてどちらかを選択。

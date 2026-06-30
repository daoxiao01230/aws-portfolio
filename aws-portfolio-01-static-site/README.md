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
| IAM | Dedicated user for GitHub Actions (least privilege) |
| GitHub Actions | CI/CD — build check on PR, auto deploy on main |
| Terraform | Infrastructure as Code (option A) |
| CloudFormation | Infrastructure as Code (option B) |

## Full Setup Flow

```
1. Deploy infrastructure (Terraform or CloudFormation)
   └─ Terraform: IAM user is created automatically
   └─ CloudFormation: deploy iam.yaml separately (Step 2)
2. Retrieve GitHub Actions credentials from Terraform output or CFN output
3. Register GitHub Secrets (4 values)
4. Push to main → automatic deploy
```

## Step 1: Deploy Infrastructure

### Option A: Terraform (recommended)

Terraform creates all resources including the IAM user for GitHub Actions.

```bash
cd infrastructure/terraform
terraform init
terraform apply -var="bucket_name=your-bucket-name"
```

Outputs: `website_url`, `cloudfront_distribution_id`, `s3_bucket_name`, `github_actions_access_key_id`, `github_actions_secret_access_key`

### Option B: CloudFormation

Deploy stacks in order: s3.yaml → cloudfront.yaml → iam.yaml

```bash
# 1. S3 bucket
aws cloudformation deploy \
  --template-file infrastructure/cloudformation/s3.yaml \
  --stack-name portfolio-01-s3 \
  --parameter-overrides BucketName=your-bucket-name

# 2. CloudFront (use outputs from step 1)
aws cloudformation deploy \
  --template-file infrastructure/cloudformation/cloudfront.yaml \
  --stack-name portfolio-01-cloudfront \
  --parameter-overrides \
    BucketName=your-bucket-name \
    BucketArn=arn:aws:s3:::your-bucket-name \
    BucketRegionalDomainName=your-bucket.s3.region.amazonaws.com
```

## Step 2: Create IAM User

### Option A: Terraform

IAM user is already created by `terraform apply` in Step 1. Retrieve credentials:

```bash
# Run from infrastructure/terraform/
terraform output github_actions_access_key_id
terraform output -raw github_actions_secret_access_key
```

> Copy these values directly from your terminal into GitHub Secrets — do not relay through other tools.

### Option B: CloudFormation

```bash
# Use outputs from cloudfront.yaml
aws cloudformation deploy \
  --template-file infrastructure/cloudformation/iam.yaml \
  --stack-name portfolio-01-iam \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameter-overrides \
    BucketName=your-bucket-name \
    CloudFrontDistributionId=your-distribution-id
```

After deploy: CloudFormation → Stacks → portfolio-01-iam → **Outputs tab** → copy `AccessKeyId` and `SecretAccessKey`

## Step 3: Setup GitHub Actions CI/CD

Add these secrets in GitHub → Settings → Secrets and variables → Actions:

| Secret | Value |
|--------|-------|
| `AWS_ACCESS_KEY_ID` | IAM user access key |
| `AWS_SECRET_ACCESS_KEY` | IAM user secret key |
| `S3_BUCKET_NAME` | From Terraform/CFN output |
| `CLOUDFRONT_DISTRIBUTION_ID` | From Terraform/CFN output |

> `AWS_REGION` is hardcoded as `ap-northeast-1` in the workflow — no secret needed.

**CI/CD behavior:**
- `push` to `main` → build + deploy + CloudFront invalidation
- Pull Request → build check only (no deploy)
- Manual run → GitHub Actions tab → Run workflow

## Local Development

```bash
cd react
npm install
npm start
```

## Destroy All Resources

### Option A: Terraform

```bash
# Git Bash / WSL
bash scripts/destroy-terraform.sh

# PowerShell
.\scripts\destroy-terraform.ps1
```

`force_destroy = true` is set on the S3 bucket, so files are automatically deleted before the bucket is removed.

### Option B: CloudFormation

```bash
# Git Bash / WSL
bash scripts/destroy-cloudformation.sh <bucket-name>

# Example:
bash scripts/destroy-cloudformation.sh portfolio-01-gratitude-2026-v2

# PowerShell
.\scripts\destroy-cloudformation.ps1 -BucketName portfolio-01-gratitude-2026-v2
```

Deletes stacks in order: `portfolio-01-iam` → `portfolio-01-cloudfront` → `portfolio-01-s3`

## Key Decisions

- S3 bucket is **private** — CloudFront accesses it via Origin Access Control (OAC), not public ACL
- 403/404 errors redirect to `index.html` to support client-side routing
- CI/CD uses 2 separate jobs: `build` (runs on all events) and `deploy` (main only)
- IAM user has least-privilege permissions — S3 write + CloudFront invalidation only, scoped to this project's resources
- Both Terraform and CloudFormation produce identical infrastructure
- `force_destroy = true` on S3 (Terraform only) — allows one-command teardown

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
| IAM | GitHub Actions専用ユーザー（最小権限） |
| GitHub Actions | CI/CD — PRでビルド確認、mainで自動デプロイ |
| Terraform | Infrastructure as Code（選択肢A） |
| CloudFormation | Infrastructure as Code（選択肢B） |

## セットアップ全体の流れ

```
1. インフラをデプロイ（TerraformまたはCloudFormation）
   └─ Terraform: IAMユーザーも自動作成される
   └─ CloudFormation: iam.yamlを別途デプロイ（Step 2）
2. GitHub Actions用の認証情報を取得
3. GitHub Secretsに4つの値を登録
4. mainへpush → 自動デプロイ
```

## Step 1: インフラのデプロイ

### 選択肢A: Terraform（推奨）

TerraformはGitHub Actions用IAMユーザーを含む全リソースを作成する。

```bash
cd infrastructure/terraform
terraform init
terraform apply -var="bucket_name=バケット名"
```

実行後の出力: `website_url`、`cloudfront_distribution_id`、`s3_bucket_name`、`github_actions_access_key_id`、`github_actions_secret_access_key`

### 選択肢B: CloudFormation

スタックのデプロイ順序: s3.yaml → cloudfront.yaml → iam.yaml

```bash
# 1. S3バケット
aws cloudformation deploy \
  --template-file infrastructure/cloudformation/s3.yaml \
  --stack-name portfolio-01-s3 \
  --parameter-overrides BucketName=バケット名

# 2. CloudFront（step 1の出力値を使用）
aws cloudformation deploy \
  --template-file infrastructure/cloudformation/cloudfront.yaml \
  --stack-name portfolio-01-cloudfront \
  --parameter-overrides \
    BucketName=バケット名 \
    BucketArn=arn:aws:s3:::バケット名 \
    BucketRegionalDomainName=バケット名.s3.リージョン.amazonaws.com
```

## Step 2: IAMユーザーの認証情報を取得

### 選択肢A: Terraform

Step 1の`terraform apply`でIAMユーザーは既に作成済み。認証情報を取得する：

```bash
# infrastructure/terraform/ で実行
terraform output github_actions_access_key_id
terraform output -raw github_actions_secret_access_key
```

> ターミナルの出力を直接 GitHub Secrets に貼り付ける。他のツール経由で転記しない。

### 選択肢B: CloudFormation

```bash
# cloudfront.yamlの出力値を使用
aws cloudformation deploy \
  --template-file infrastructure/cloudformation/iam.yaml \
  --stack-name portfolio-01-iam \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameter-overrides \
    BucketName=バケット名 \
    CloudFrontDistributionId=DistributionID
```

デプロイ後: CloudFormation → スタック → portfolio-01-iam → **Outputsタブ** → `AccessKeyId`と`SecretAccessKey`をコピー

## Step 3: GitHub Secrets の登録

GitHub → Settings → Secrets and variables → Actions で以下の4つを登録:

| Secret名 | 設定値 |
|----------|--------|
| `AWS_ACCESS_KEY_ID` | IAMユーザーのアクセスキーID |
| `AWS_SECRET_ACCESS_KEY` | IAMユーザーのシークレットアクセスキー |
| `S3_BUCKET_NAME` | Terraform/CFNの出力値 |
| `CLOUDFRONT_DISTRIBUTION_ID` | Terraform/CFNの出力値 |

> `AWS_REGION` はワークフロー内に `ap-northeast-1` としてハードコード済み。Secretsへの登録不要。

**CI/CDの動作:**
- `main`へpush → ビルド + S3デプロイ + CloudFront Invalidation
- Pull Request → ビルド確認のみ（デプロイしない）
- 手動実行 → ActionsタブのRun workflowボタンから実行

## ローカル開発

```bash
cd react
npm install
npm start
```

## 全リソースの削除

### 選択肢A: Terraform

```bash
# Git Bash / WSL
bash scripts/destroy-terraform.sh

# PowerShell
.\scripts\destroy-terraform.ps1
```

S3バケットに`force_destroy = true`が設定されているため、中身のファイルを自動削除してからバケットを削除する。

### 選択肢B: CloudFormation

```bash
# Git Bash / WSL
bash scripts/destroy-cloudformation.sh <バケット名>

# 例:
bash scripts/destroy-cloudformation.sh portfolio-01-gratitude-2026-v2

# PowerShell
.\scripts\destroy-cloudformation.ps1 -BucketName portfolio-01-gratitude-2026-v2
```

スタックを正しい順序で削除: `portfolio-01-iam` → `portfolio-01-cloudfront` → `portfolio-01-s3`

## 設計上の判断

- S3バケットは**プライベート** — CloudFrontはOAC（Origin Access Control）経由でのみアクセス。直接公開しない。
- 403/404エラーは`index.html`にリダイレクト — ReactRouterのクライアントサイドルーティングを機能させるため。
- CI/CDは2ジョブ構成: `build`（全イベントで実行）と`deploy`（mainのみ）に分離。
- IAMユーザーは最小権限 — このプロジェクトのS3書き込みとCloudFront Invalidationのみ許可。
- TerraformとCloudFormationは同一のインフラを構築する。用途に応じてどちらかを選択。
- S3に`force_destroy = true`（Terraformのみ）— 一コマンドで全削除できるようにするため。
